import { describe, expect, it } from 'vitest';
import { createAttribute, createClass, createProject } from './factories';
import type { ProjectModel } from './types';
import { validateProject } from './validation';

const ids = (...values: string[]) => {
  let index = 0;
  return () => values[index++] ?? `generated-${index}`;
};

describe('validateProject', () => {
  it('accepts a structurally valid canonical model', () => {
    const project = createProject('Veterinaria', ids('project'));
    const cliente = createClass('Cliente', { x: 10, y: 20 }, ids('cliente'));
    cliente.attributes.push(
      createAttribute(
        { name: 'id', dataType: 'Long', primaryKey: true },
        ids('cliente-id'),
      ),
    );
    project.classes.push(cliente);

    expect(validateProject(project)).toEqual({ valid: true, issues: [] });
  });

  it('detects duplicate names and identifiers', () => {
    const project = createProject('Duplicado', ids('project'));
    project.classes = [
      createClass('Cliente', { x: 0, y: 0 }, ids('same-id')),
      createClass('cliente', { x: 1, y: 1 }, ids('same-id')),
    ];

    const codes = validateProject(project).issues.map((item) => item.code);
    expect(codes).toContain('DUPLICATE_NAME');
    expect(codes).toContain('DUPLICATE_ID');
  });

  it('accepts enumerations as attribute data types', () => {
    const project = createProject('Pedidos', ids('project'));
    project.enumerations.push({ id: 'estado-enum', name: 'Estado', values: ['NUEVO', 'PAGADO'] });
    const pedido = createClass('Pedido', { x: 0, y: 0 }, ids('pedido'));
    pedido.attributes.push(createAttribute({ name: 'estado', dataType: 'Estado' }, ids('estado')));
    project.classes.push(pedido);

    expect(validateProject(project).valid).toBe(true);
  });

  it('rejects unknown data types and broken relationships', () => {
    const project = createProject('Inválido', ids('project'));
    const cliente = createClass('Cliente', { x: 0, y: 0 }, ids('cliente'));
    cliente.attributes.push(createAttribute({ name: 'dato', dataType: 'Blob' }, ids('attr')));
    project.classes.push(cliente);
    project.relationships.push({
      id: 'rel',
      type: 'ASSOCIATION',
      sourceClassId: 'cliente',
      targetClassId: 'missing',
      sourceMultiplicity: '1',
      targetMultiplicity: '0..*',
    });

    const codes = validateProject(project).issues.map((item) => item.code);
    expect(codes).toContain('UNKNOWN_DATA_TYPE');
    expect(codes).toContain('MISSING_TARGET_CLASS');
  });

  it('rejects inheritance cycles', () => {
    const project: ProjectModel = {
      id: 'project',
      name: 'Herencia',
      revision: 0,
      enumerations: [],
      classes: [
        { id: 'a', name: 'A', position: { x: 0, y: 0 }, attributes: [] },
        { id: 'b', name: 'B', position: { x: 1, y: 1 }, attributes: [] },
      ],
      relationships: [
        { id: 'r1', type: 'GENERALIZATION', sourceClassId: 'a', targetClassId: 'b', sourceMultiplicity: '1', targetMultiplicity: '1' },
        { id: 'r2', type: 'GENERALIZATION', sourceClassId: 'b', targetClassId: 'a', sourceMultiplicity: '1', targetMultiplicity: '1' },
      ],
    };

    expect(validateProject(project).issues.map((item) => item.code)).toContain('GENERALIZATION_CYCLE');
  });
});

