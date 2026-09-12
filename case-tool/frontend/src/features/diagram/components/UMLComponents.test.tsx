// @vitest-environment jsdom

import { cleanup, render, screen } from '@testing-library/react';
import type { EdgeProps, NodeProps } from '@xyflow/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type {
  RelationshipFlowEdge,
  UMLClassFlowNode,
} from '../types/reactFlowTypes';
import { RelationshipEdge } from './RelationshipEdge';
import { UMLClassNode } from './UMLClassNode';

vi.mock('@xyflow/react', () => ({
  Position: { Left: 'left', Right: 'right' },
  Handle: ({ type }: { type: string }) => <span data-testid={`handle-${type}`} />,
  BaseEdge: ({ path, className }: { path: string; className?: string }) => (
    <svg><path data-testid="edge-path" d={path} className={className} /></svg>
  ),
  EdgeLabelRenderer: ({ children }: { children: React.ReactNode }) => <>{children}</>,
  getBezierPath: () => ['M 0 0 L 100 0'],
}));

afterEach(cleanup);

describe('UMLClassNode', () => {
  it('renders class name, attributes, primary key and connection handles', () => {
    const props = {
      id: 'cliente',
      type: 'umlClass',
      data: {
        classId: 'cliente',
        name: 'Cliente',
        attributes: [
          { id: 'id', name: 'id', dataType: 'Long', primaryKey: true, nullable: false, unique: true },
          { id: 'nombre', name: 'nombre', dataType: 'String', primaryKey: false, nullable: false, unique: false },
        ],
      },
      selected: true,
      dragging: false,
      zIndex: 0,
      selectable: true,
      deletable: true,
      draggable: true,
      isConnectable: true,
      positionAbsoluteX: 0,
      positionAbsoluteY: 0,
    } as NodeProps<UMLClassFlowNode>;

    render(<UMLClassNode {...props} />);

    expect(screen.getByLabelText('Clase Cliente').classList.contains('uml-node--selected')).toBe(true);
    expect(screen.getByText('Cliente')).toBeTruthy();
    expect(screen.getByLabelText('Clave primaria')).toBeTruthy();
    expect(screen.getByText('String')).toBeTruthy();
    expect(screen.getByTestId('handle-source')).toBeTruthy();
    expect(screen.getByTestId('handle-target')).toBeTruthy();
  });

  it('handles a class without attributes', () => {
    const props = {
      id: 'empty',
      type: 'umlClass',
      data: { classId: 'empty', name: 'Vacía', attributes: [] },
      selected: false,
      dragging: false,
      zIndex: 0,
      selectable: true,
      deletable: true,
      draggable: true,
      isConnectable: true,
      positionAbsoluteX: 0,
      positionAbsoluteY: 0,
    } as NodeProps<UMLClassFlowNode>;

    render(<UMLClassNode {...props} />);
    expect(screen.getByText('Sin atributos')).toBeTruthy();
  });
});

describe('RelationshipEdge', () => {
  it('renders both endpoint multiplicities and selected state', () => {
    const props = {
      id: 'cliente-mascota',
      type: 'umlRelationship',
      source: 'cliente',
      target: 'mascota',
      sourceX: 0,
      sourceY: 0,
      targetX: 100,
      targetY: 0,
      sourcePosition: 'right',
      targetPosition: 'left',
      selected: true,
      data: {
        relationshipId: 'cliente-mascota',
        relationshipType: 'ASSOCIATION',
        sourceMultiplicity: '1',
        targetMultiplicity: '0..*',
      },
    } as EdgeProps<RelationshipFlowEdge>;

    render(<RelationshipEdge {...props} />);

    expect(screen.getByLabelText('Multiplicidad origen 1')).toBeTruthy();
    expect(screen.getByLabelText('Multiplicidad destino 0..*')).toBeTruthy();
    expect(screen.getByTestId('edge-path').classList.contains('relationship-edge__path--selected')).toBe(true);
  });
});
