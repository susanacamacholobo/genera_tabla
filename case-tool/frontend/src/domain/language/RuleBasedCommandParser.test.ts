import { describe, expect, it } from 'vitest';
import { CommandExecutor } from '../commands/CommandExecutor';
import { createProject } from '../model/factories';
import type { ProjectModel } from '../model/types';
import { RuleBasedCommandParser } from './RuleBasedCommandParser';

function sequentialIds(): () => string {
  let value = 0;
  return () => `generated-${++value}`;
}

function projectFixture(): ProjectModel {
  return {
    ...createProject('Demo', () => 'project-demo'),
    classes: [
      { id: 'class-cliente', name: 'Cliente', position: { x: 20, y: 40 }, attributes: [] },
    ],
  };
}

describe('RuleBasedCommandParser', () => {
  it('creates a class command with a predictable free position', () => {
    const parser = new RuleBasedCommandParser(sequentialIds());

    expect(parser.parse('  Crea una clase Factura.  ', projectFixture())).toEqual({
      ok: true,
      command: {
        id: 'generated-1',
        type: 'ADD_CLASS',
        payload: {
          id: 'generated-2',
          name: 'Factura',
          position: { x: 400, y: 100 },
        },
      },
    });
  });

  it('adds an attribute resolving class and built-in type without case sensitivity', () => {
    const parser = new RuleBasedCommandParser(sequentialIds());

    expect(parser.parse('agrega nombre string a la clase cliente', projectFixture())).toEqual({
      ok: true,
      command: {
        id: 'generated-1',
        type: 'ADD_ATTRIBUTE',
        targetId: 'class-cliente',
        payload: {
          id: 'generated-2',
          name: 'nombre',
          dataType: 'String',
        },
      },
    });
  });

  it('supports quoted attribute and class names', () => {
    const project = projectFixture();
    project.classes[0] = { ...project.classes[0]!, name: 'Orden de compra' };
    const parser = new RuleBasedCommandParser(sequentialIds());

    const result = parser.parse(
      'añade "fecha entrega" Date a "Orden de compra"',
      project,
    );

    expect(result.ok && result.command).toMatchObject({
      type: 'ADD_ATTRIBUTE',
      targetId: 'class-cliente',
      payload: { name: 'fecha entrega', dataType: 'Date' },
    });
  });

  it('deletes a class by name', () => {
    const parser = new RuleBasedCommandParser(sequentialIds());

    expect(parser.parse('elimina la clase Cliente', projectFixture())).toEqual({
      ok: true,
      command: {
        id: 'generated-1',
        type: 'DELETE_CLASS',
        targetId: 'class-cliente',
        payload: {},
      },
    });
  });

  it('returns typed errors for empty, unknown and unresolved commands', () => {
    const parser = new RuleBasedCommandParser(sequentialIds());

    expect(parser.parse(' ', projectFixture())).toMatchObject({
      ok: false,
      error: { code: 'EMPTY_INPUT' },
    });
    expect(parser.parse('haz magia', projectFixture())).toMatchObject({
      ok: false,
      error: { code: 'UNKNOWN_COMMAND' },
    });
    expect(parser.parse('elimina Factura', projectFixture())).toMatchObject({
      ok: false,
      error: { code: 'CLASS_NOT_FOUND' },
    });
  });

  it('produces commands accepted by the existing domain executor', () => {
    const parser = new RuleBasedCommandParser(sequentialIds());
    const result = parser.parse('agrega email String a Cliente', projectFixture());
    if (!result.ok) throw new Error(result.error.message);

    const updated = new CommandExecutor(() => 'unused').execute(projectFixture(), result.command);

    expect(updated.revision).toBe(1);
    expect(updated.classes[0]?.attributes[0]).toMatchObject({
      id: 'generated-2',
      name: 'email',
      dataType: 'String',
    });
  });
});
