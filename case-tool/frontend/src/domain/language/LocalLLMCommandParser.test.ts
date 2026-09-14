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
        message: 'La IA local no pudo interpretar el comando.',
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
});
