import { describe, expect, it, vi } from 'vitest';
import { CommandExecutor } from '../commands/CommandExecutor';
import { createProject } from '../model/factories';
import type { ProjectModel } from '../model/types';
import {
  LocalLLMCommandParser,
  type LocalLLMProvider,
} from './LocalLLMCommandParser';

function sequentialIds(): () => string {
  let value = 0;
  return () => `local-${++value}`;
}

function projectFixture(): ProjectModel {
  return {
    ...createProject('Veterinaria', () => 'project-demo'),
    classes: [
      {
        id: 'class-cliente',
        name: 'Cliente',
        position: { x: 20, y: 40 },
        attributes: [],
      },
    ],
  };
}

function providerReturning(response: string): LocalLLMProvider {
  return { generate: vi.fn().mockResolvedValue(response) };
}

describe('LocalLLMCommandParser', () => {
  it('creates a class from strict structured JSON and assigns IDs locally', async () => {
    const provider = providerReturning(JSON.stringify({
      actions: [{
        type: 'ADD_CLASS',
        payload: { name: 'Factura', id: 'untrusted-model-id' },
      }],
    }));
    const parser = new LocalLLMCommandParser(provider, sequentialIds());

    await expect(parser.parse('Necesito una clase Factura', projectFixture())).resolves.toEqual({
      ok: true,
      command: {
        id: 'local-1',
        type: 'ADD_CLASS',
        payload: {
          id: 'local-2',
          name: 'Factura',
          position: { x: 400, y: 100 },
        },
      },
    });
    expect(provider.generate).toHaveBeenCalledWith(expect.stringContaining('Veterinaria'));
    expect(provider.generate).toHaveBeenCalledWith(expect.stringContaining('Necesito una clase Factura'));
  });

  it('resolves class names, normalizes types and preserves valid attribute options', async () => {
    const parser = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [{
        type: 'ADD_ATTRIBUTE',
        targetName: 'cliente',
        payload: {
          name: 'saldo',
          dataType: 'decimal',
          nullable: false,
          unique: true,
          defaultValue: 0,
        },
      }],
    })), sequentialIds());

    const result = await parser.parse('Agrega el saldo del cliente', projectFixture());

    expect(result).toEqual({
      ok: true,
      command: {
        id: 'local-1',
        type: 'ADD_ATTRIBUTE',
        targetId: 'class-cliente',
        payload: {
          id: 'local-2',
          name: 'saldo',
          dataType: 'Decimal',
          nullable: false,
          unique: true,
          defaultValue: 0,
        },
      },
    });
  });

  it('produces a delete command accepted by the canonical executor', async () => {
    const project = projectFixture();
    const parser = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [{ type: 'DELETE_CLASS', targetName: 'Cliente', payload: {} }],
    })), sequentialIds());

    const result = await parser.parse('Quita Cliente', project);
    if (!result.ok) throw new Error(result.error.message);

    const updated = new CommandExecutor(() => 'unused').execute(project, result.command);
    expect(updated.classes).toHaveLength(0);
    expect(updated.revision).toBe(1);
  });

  it('does not call the model for empty input', async () => {
    const provider = providerReturning('{}');
    const parser = new LocalLLMCommandParser(provider);

    await expect(parser.parse('  ', projectFixture())).resolves.toMatchObject({
      ok: false,
      error: { code: 'EMPTY_INPUT' },
    });
    expect(provider.generate).not.toHaveBeenCalled();
  });

  it.each([
    ['not JSON', 'INVALID_MODEL_RESPONSE'],
    ['{"actions":[]}', 'INVALID_MODEL_RESPONSE'],
    ['{"actions":[{},{}]}', 'INVALID_MODEL_RESPONSE'],
    ['{"actions":[{"type":"DROP_DATABASE","payload":{}}]}', 'UNSUPPORTED_COMMAND'],
    ['```json\n{"actions":[]}\n```', 'INVALID_MODEL_RESPONSE'],
  ])('rejects an untrusted model response: %s', async (response, code) => {
    const parser = new LocalLLMCommandParser(providerReturning(response));

    await expect(parser.parse('Haz algo', projectFixture())).resolves.toMatchObject({
      ok: false,
      error: { code },
    });
  });

  it('reports provider failures without leaking implementation details', async () => {
    const provider: LocalLLMProvider = {
      generate: vi.fn().mockRejectedValue(new Error('native runtime crashed at secret/path')),
    };
    const parser = new LocalLLMCommandParser(provider);

    await expect(parser.parse('crea clase Factura', projectFixture())).resolves.toEqual({
      ok: false,
      error: {
        code: 'MODEL_FAILURE',
        message: 'La IA no pudo interpretar el comando.',
      },
    });
  });

  it('rejects unresolved targets and malformed attribute modifiers', async () => {
    const missingClass = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [{ type: 'DELETE_CLASS', targetName: 'Fantasma', payload: {} }],
    })));
    await expect(missingClass.parse('borra Fantasma', projectFixture())).resolves.toMatchObject({
      ok: false,
      error: { code: 'CLASS_NOT_FOUND' },
    });

    const malformed = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [{
        type: 'ADD_ATTRIBUTE',
        targetName: 'Cliente',
        payload: { name: 'activo', dataType: 'Boolean', nullable: 'no' },
      }],
    })));
    await expect(malformed.parse('agrega activo', projectFixture())).resolves.toMatchObject({
      ok: false,
      error: { code: 'INVALID_MODEL_RESPONSE' },
    });
  });

  it('resolves relation endpoints and multiplicities without accepting model IDs', async () => {
    const project = projectFixture();
    project.classes.push({ id: 'class-pedido', name: 'Pedido', position: { x: 300, y: 40 }, attributes: [] });
    const parser = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [{
        type: 'ADD_RELATIONSHIP', sourceName: 'cliente', targetName: 'Pedido',
        payload: { id: 'malicious-id', type: 'ASSOCIATION', sourceMultiplicity: '1', targetMultiplicity: '0..*' },
      }],
    })), sequentialIds());

    await expect(parser.parse('Relaciona Cliente con Pedido', project)).resolves.toMatchObject({
      ok: true, command: { type: 'ADD_RELATIONSHIP', payload: {
        id: 'local-2', sourceClassId: 'class-cliente', targetClassId: 'class-pedido',
        sourceMultiplicity: '1', targetMultiplicity: '0..*',
      } },
    });
  });

  it('updates a named attribute and rejects ambiguous relationships', async () => {
    const project = projectFixture();
    project.classes[0]!.attributes.push({ id: 'attr-saldo', name: 'saldo', dataType: 'Integer', nullable: true, unique: false, primaryKey: false });
    const parser = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [{ type: 'UPDATE_ATTRIBUTE', targetName: 'Cliente', attributeName: 'saldo', payload: { dataType: 'Decimal' } }],
    })), sequentialIds());
    await expect(parser.parse('Cambia saldo a Decimal', project)).resolves.toMatchObject({
      ok: true, command: { type: 'UPDATE_ATTRIBUTE', targetId: 'attr-saldo', payload: { dataType: 'Decimal' } },
    });

    project.classes.push({ id: 'class-pedido', name: 'Pedido', position: { x: 300, y: 40 }, attributes: [] });
    project.relationships.push(
      { id: 'rel-1', type: 'ASSOCIATION', sourceClassId: 'class-cliente', targetClassId: 'class-pedido', sourceMultiplicity: '1', targetMultiplicity: '0..*' },
      { id: 'rel-2', type: 'ASSOCIATION', sourceClassId: 'class-cliente', targetClassId: 'class-pedido', sourceMultiplicity: '1', targetMultiplicity: '0..1' },
    );
    const ambiguous = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [{ type: 'DELETE_RELATIONSHIP', sourceName: 'Cliente', targetName: 'Pedido', payload: {} }],
    })));
    await expect(ambiguous.parse('Quita la relación', project)).resolves.toMatchObject({
      ok: false, error: { code: 'INVALID_MODEL_RESPONSE' },
    });
  });

  it('returns one explained suggestion and a safe clarification for ambiguous requests', async () => {
    const suggestion = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [{ type: 'RENAME_CLASS', targetName: 'Cliente', payload: { name: 'Persona' } }],
      explanation: 'Un nombre más general para reutilizar la clase.',
      assumptions: ['Cliente también representa proveedores.'],
    })));
    await expect(suggestion.parse('Sugiere un mejor nombre para Cliente', projectFixture())).resolves.toMatchObject({
      ok: true,
      explanation: 'Un nombre más general para reutilizar la clase.',
      assumptions: ['Cliente también representa proveedores.'],
      command: { type: 'RENAME_CLASS', targetId: 'class-cliente' },
    });

    const ambiguous = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [], clarification: '¿A qué clase agrego el atributo?',
    })));
    await expect(ambiguous.parse('Agrega el atributo', projectFixture())).resolves.toMatchObject({
      ok: false,
      error: { message: '¿A qué clase agrego el atributo?' },
    });
  });

  it('resolves changed relationship endpoints against known class names', async () => {
    const project = projectFixture();
    project.classes.push(
      { id: 'class-pedido', name: 'Pedido', position: { x: 300, y: 40 }, attributes: [] },
      { id: 'class-factura', name: 'Factura', position: { x: 600, y: 40 }, attributes: [] },
    );
    project.relationships.push({ id: 'rel-1', type: 'ASSOCIATION', sourceClassId: 'class-cliente',
      targetClassId: 'class-pedido', sourceMultiplicity: '1', targetMultiplicity: '0..*' });
    const parser = new LocalLLMCommandParser(providerReturning(JSON.stringify({
      actions: [{ type: 'UPDATE_RELATIONSHIP', sourceName: 'Cliente', targetName: 'Pedido',
        payload: { newTargetName: 'Factura' } }],
    })));
    await expect(parser.parse('Cambia destino a Factura', project)).resolves.toMatchObject({
      ok: true, command: { type: 'UPDATE_RELATIONSHIP', targetId: 'rel-1', payload: { targetClassId: 'class-factura' } },
    });
  });
});
