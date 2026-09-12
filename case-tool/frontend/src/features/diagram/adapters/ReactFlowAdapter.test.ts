import { MarkerType } from '@xyflow/react';
import { describe, expect, it } from 'vitest';
import type { ProjectModel } from '../../../domain';
import type { UMLClassNodeData } from '../types/reactFlowTypes';
import { ReactFlowAdapter } from './ReactFlowAdapter';

function projectFixture(): ProjectModel {
  return {
    id: 'project',
    name: 'Veterinaria',
    revision: 0,
    enumerations: [],
    classes: [
      {
        id: 'cliente',
        name: 'Cliente',
        position: { x: 120, y: 80 },
        attributes: [
          {
            id: 'cliente-id',
            name: 'id',
            dataType: 'Long',
            primaryKey: true,
            nullable: false,
            unique: true,
          },
          {
            id: 'cliente-nombre',
            name: 'nombre',
            dataType: 'String',
            primaryKey: false,
            nullable: false,
            unique: false,
          },
        ],
        externalReferences: [
          { source: 'enterprise-architect', guid: '{CLIENTE-GUID}' },
        ],
      },
      {
        id: 'mascota',
        name: 'Mascota',
        position: { x: 520, y: 80 },
        attributes: [],
      },
    ],
    relationships: [],
  };
}

describe('ReactFlowAdapter', () => {
  it('maps a class to a stable node with canonical position', () => {
    const { nodes } = ReactFlowAdapter.fromProject(projectFixture());

    expect(nodes[0]).toMatchObject({
      id: 'cliente',
      type: 'umlClass',
      position: { x: 120, y: 80 },
      data: { classId: 'cliente', name: 'Cliente' },
    });
  });

  it('maps only renderable attribute fields and excludes external metadata', () => {
    const { nodes } = ReactFlowAdapter.fromProject(projectFixture());
    const data = nodes[0]?.data as UMLClassNodeData;

    expect(data.attributes).toEqual([
      {
        id: 'cliente-id',
        name: 'id',
        dataType: 'Long',
        primaryKey: true,
        nullable: false,
        unique: true,
      },
      {
        id: 'cliente-nombre',
        name: 'nombre',
        dataType: 'String',
        primaryKey: false,
        nullable: false,
        unique: false,
      },
    ]);
    expect(data).not.toHaveProperty('externalReferences');
  });

  it('preserves association direction and multiplicities exactly', () => {
    const project = projectFixture();
    project.relationships.push({
      id: 'cliente-mascota',
      type: 'ASSOCIATION',
      sourceClassId: 'cliente',
      targetClassId: 'mascota',
      sourceMultiplicity: '1',
      targetMultiplicity: '0..*',
    });

    const edge = ReactFlowAdapter.fromProject(project).edges[0];
    expect(edge).toMatchObject({
      id: 'cliente-mascota',
      source: 'cliente',
      target: 'mascota',
      data: {
        relationshipType: 'ASSOCIATION',
        sourceMultiplicity: '1',
        targetMultiplicity: '0..*',
      },
    });
  });

  it('marks a generalization with a closed arrow toward the target', () => {
    const project = projectFixture();
    project.relationships.push({
      id: 'herencia',
      type: 'GENERALIZATION',
      sourceClassId: 'mascota',
      targetClassId: 'cliente',
      sourceMultiplicity: '1',
      targetMultiplicity: '1',
    });

    const edge = ReactFlowAdapter.fromProject(project).edges[0];
    expect(edge?.source).toBe('mascota');
    expect(edge?.target).toBe('cliente');
    expect(edge?.markerEnd).toMatchObject({ type: MarkerType.ArrowClosed });
  });

  it('renders enumerations as deterministic, non-draggable nodes', () => {
    const project = projectFixture();
    project.enumerations.push({
      id: 'estado',
      name: 'Estado',
      values: ['ACTIVO', 'INACTIVO'],
    });

    const enumNode = ReactFlowAdapter.fromProject(project).nodes[2];
    expect(enumNode).toMatchObject({
      id: 'estado',
      type: 'umlEnum',
      draggable: false,
      data: { name: 'Estado', values: ['ACTIVO', 'INACTIVO'] },
    });
  });
});
