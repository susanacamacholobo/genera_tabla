import { describe, expect, it } from 'vitest';
import veterinariaFixture from '../../../../../docs/examples/veterinaria.json';
import { createAttribute, createClass, createProject } from './factories';
import type { ProjectModel } from './types';
import { validateProject } from './validation';

const ids = (...values: string[]) => {
  let index = 0;
  return () => values[index++] ?? `generated-${index}`;
};

describe('validateProject', () => {
  it('keeps the documented Veterinaria JSON fixture valid', () => {
    expect(validateProject(veterinariaFixture as ProjectModel)).toEqual({
      valid: true,
      issues: [],
    });
  });

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

  it('preserves optional external identities on every interoperable UML element', () => {
    const project = createProject('Veterinaria importada', ids('project'));
    const externalReference = {
      source: 'enterprise-architect',
      scope: 'veterinaria-repository',
      guid: '{4F9C6750-6298-4fc8-A312-F71953B10A67}',
      xmiId: 'EAID_4F9C6750_6298_4fc8_A312_F71953B10A67',
      package: {
        name: 'Modelo de dominio',
        guid: '{70E3B025-C983-44f4-8AD9-6282E516730F}',
      },
    };
    const cliente = createClass('Cliente', { x: 10, y: 10 }, ids('cliente'));
    cliente.externalReferences = [externalReference];
    cliente.attributes.push({
      ...createAttribute({ name: 'nombre', dataType: 'String' }, ids('nombre')),
      externalReferences: [{ ...externalReference, xmiId: 'EAID_attribute_nombre' }],
    });
    project.classes.push(cliente);
    project.enumerations.push({
      id: 'estado',
      name: 'Estado',
      values: ['ACTIVO'],
      externalReferences: [{ ...externalReference, xmiId: 'EAID_enum_estado' }],
    });
    project.relationships.push({
      id: 'autorelacion',
      type: 'ASSOCIATION',
      sourceClassId: 'cliente',
      targetClassId: 'cliente',
      sourceMultiplicity: '0..1',
      targetMultiplicity: '0..*',
      externalReferences: [{ ...externalReference, xmiId: 'EAID_association_cliente' }],
    });

    expect(validateProject(project)).toEqual({ valid: true, issues: [] });
    expect(project.classes[0]?.id).not.toBe(project.classes[0]?.externalReferences?.[0]?.guid);
  });

  it('rejects external metadata without source or external identity', () => {
    const project = createProject('Importación inválida', ids('project'));
    const cliente = createClass('Cliente', { x: 0, y: 0 }, ids('cliente'));
    cliente.externalReferences = [{ source: ' ', xmiId: '' }];
    project.classes.push(cliente);

    const codes = validateProject(project).issues.map((item) => item.code);
    expect(codes).toContain('EMPTY_EXTERNAL_SOURCE');
    expect(codes).toContain('MISSING_EXTERNAL_IDENTITY');
    expect(codes).toContain('EMPTY_EXTERNAL_REFERENCE_VALUE');
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
