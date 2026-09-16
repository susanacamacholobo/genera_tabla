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
  it('creates a class command with a predictable free position', async () => {
    const parser = new RuleBasedCommandParser(sequentialIds());

    await expect(parser.parse('  Crea una clase Factura.  ', projectFixture())).resolves.toEqual({
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

  it('adds an attribute resolving class and built-in type without case sensitivity', async () => {
    const parser = new RuleBasedCommandParser(sequentialIds());

    await expect(parser.parse('agrega nombre string a la clase cliente', projectFixture())).resolves.toEqual({
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

  it('supports quoted attribute and class names', async () => {
    const project = projectFixture();
    project.classes[0] = { ...project.classes[0]!, name: 'Orden de compra' };
    const parser = new RuleBasedCommandParser(sequentialIds());

    const result = await parser.parse(
      'añade "fecha entrega" Date a "Orden de compra"',
      project,
    );

    expect(result.ok && result.command).toMatchObject({
      type: 'ADD_ATTRIBUTE',
      targetId: 'class-cliente',
      payload: { name: 'fecha entrega', dataType: 'Date' },
    });
  });

  it('deletes a class by name', async () => {
    const parser = new RuleBasedCommandParser(sequentialIds());

    await expect(parser.parse('elimina la clase Cliente', projectFixture())).resolves.toEqual({
      ok: true,
      command: {
        id: 'generated-1',
        type: 'DELETE_CLASS',
        targetId: 'class-cliente',
        payload: {},
      },
    });
  });

  it('returns typed errors for empty, unknown and unresolved commands', async () => {
    const parser = new RuleBasedCommandParser(sequentialIds());

    await expect(parser.parse(' ', projectFixture())).resolves.toMatchObject({
      ok: false,
      error: { code: 'EMPTY_INPUT' },
    });
    await expect(parser.parse('haz magia', projectFixture())).resolves.toMatchObject({
      ok: false,
      error: { code: 'UNKNOWN_COMMAND' },
    });
    await expect(parser.parse('elimina Factura', projectFixture())).resolves.toMatchObject({
      ok: false,
      error: { code: 'CLASS_NOT_FOUND' },
    });
  });

  it('produces commands accepted by the existing domain executor', async () => {
    const parser = new RuleBasedCommandParser(sequentialIds());
    const result = await parser.parse('agrega email String a Cliente', projectFixture());
    if (!result.ok) throw new Error(result.error.message);

    const updated = new CommandExecutor(() => 'unused').execute(projectFixture(), result.command);

    expect(updated.revision).toBe(1);
    expect(updated.classes[0]?.attributes[0]).toMatchObject({
      id: 'generated-2',
      name: 'email',
      dataType: 'String',
    });
  });

  it('renames classes and edits attributes through canonical commands', async () => {
    const project = projectFixture();
    project.classes[0]!.attributes.push({
      id: 'attribute-nombre', name: 'nombre', dataType: 'String',
      nullable: true, unique: false, primaryKey: false,
    });
    const parser = new RuleBasedCommandParser(sequentialIds());

    await expect(parser.parse('renombra clase Cliente a Persona', project)).resolves.toMatchObject({
      ok: true, command: { type: 'RENAME_CLASS', targetId: 'class-cliente', payload: { name: 'Persona' } },
    });
    await expect(parser.parse('renombra atributo nombre de Cliente a nombreCompleto', project)).resolves.toMatchObject({
      ok: true, command: { type: 'UPDATE_ATTRIBUTE', targetId: 'attribute-nombre', payload: { name: 'nombreCompleto' } },
    });
    await expect(parser.parse('cambia tipo de atributo nombre de Cliente a UUID', project)).resolves.toMatchObject({
      ok: true, command: { type: 'UPDATE_ATTRIBUTE', targetId: 'attribute-nombre', payload: { dataType: 'UUID' } },
    });
    await expect(parser.parse('elimina atributo nombre de Cliente', project)).resolves.toMatchObject({
      ok: true, command: { type: 'DELETE_ATTRIBUTE', targetId: 'attribute-nombre' },
    });
  });

  it('creates, edits and removes a relationship only when its target is unambiguous', async () => {
    const project = projectFixture();
    project.classes.push({ id: 'class-pedido', name: 'Pedido', position: { x: 300, y: 40 }, attributes: [] });
    const parser = new RuleBasedCommandParser(sequentialIds());

    const created = await parser.parse('relaciona Cliente con Pedido uno a muchos', project);
    expect(created).toMatchObject({
      ok: true, command: { type: 'ADD_RELATIONSHIP', payload: {
        sourceClassId: 'class-cliente', targetClassId: 'class-pedido',
        sourceMultiplicity: '1', targetMultiplicity: '0..*',
      } },
    });
    if (!created.ok) throw new Error(created.error.message);
    const withRelationship = new CommandExecutor(() => 'unused').execute(project, created.command);
    await expect(parser.parse('cambia multiplicidad de Cliente con Pedido a muchos a muchos', withRelationship)).resolves.toMatchObject({
      ok: true, command: { type: 'UPDATE_RELATIONSHIP', targetId: created.command.type === 'ADD_RELATIONSHIP' ? created.command.payload.id : undefined,
        payload: { sourceMultiplicity: '0..*', targetMultiplicity: '0..*' } },
    });
    await expect(parser.parse('elimina relación de Cliente con Pedido', withRelationship)).resolves.toMatchObject({
      ok: true, command: { type: 'DELETE_RELATIONSHIP' },
    });
    withRelationship.relationships.push({ ...withRelationship.relationships[0]!, id: 'duplicate' });
    await expect(parser.parse('elimina relación de Cliente con Pedido', withRelationship)).resolves.toMatchObject({
      ok: false, error: { code: 'AMBIGUOUS_TARGET' },
    });
  });
});
