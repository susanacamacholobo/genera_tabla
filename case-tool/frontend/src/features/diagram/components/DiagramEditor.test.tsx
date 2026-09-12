// @vitest-environment jsdom

import { cleanup, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ProjectModel } from '../../../domain';
import veterinariaFixture from '../../../../../../docs/examples/veterinaria.json';
import { DiagramEditor } from './DiagramEditor';

vi.mock('@xyflow/react', async () => {
  const actual = await vi.importActual<typeof import('@xyflow/react')>('@xyflow/react');
  const { useState: useReactState } = await import('react');
  return {
    ...actual,
    ReactFlow: ({
      nodes,
      edges,
      onNodeClick,
      onNodeDragStop,
      onEdgeClick,
      onConnect,
      children,
    }: {
      nodes: Array<{ id: string; type?: string; position: { x: number; y: number } }>;
      edges: Array<{ id: string }>;
      onNodeClick?: (event: unknown, node: unknown) => void;
      onNodeDragStop?: (event: unknown, node: unknown, nodes: unknown[]) => void;
      onEdgeClick?: (event: unknown, edge: unknown) => void;
      onConnect?: (connection: { source: string; target: string }) => void;
      children?: ReactNode;
    }) => (
      <div data-testid="react-flow">
        {nodes.map((node) => (
          <span key={node.id}>
            <button onClick={() => onNodeClick?.({}, node)}>Seleccionar {node.id}</button>
            {node.type === 'umlClass' && (
              <button onClick={() => onNodeDragStop?.({}, { ...node, position: { x: node.position.x + 50, y: node.position.y + 25 } }, nodes)}>
                Mover {node.id}
              </button>
            )}
          </span>
        ))}
        {edges.map((edge) => (
          <button key={edge.id} onClick={() => onEdgeClick?.({}, edge)}>Relación {edge.id}</button>
        ))}
        {nodes.length >= 2 && (
          <button onClick={() => onConnect?.({ source: nodes[0]?.id ?? '', target: nodes[1]?.id ?? '' })}>
            Conectar primeras clases
          </button>
        )}
        {children}
      </div>
    ),
    Background: () => null,
    Controls: () => null,
    useNodesState: <T,>(initial: T[]) => {
      const [nodes, setNodes] = useReactState(initial);
      return [nodes, setNodes, () => undefined] as const;
    },
  };
});

afterEach(cleanup);

describe('DiagramEditor', () => {
  it('routes create, move, rename, relationship, undo and redo through canonical state', async () => {
    const user = userEvent.setup();
    const states: ProjectModel[] = [];
    render(
      <DiagramEditor
        initialProject={structuredClone(veterinariaFixture) as ProjectModel}
        onProjectChange={(project) => states.push(project)}
      />,
    );

    await user.click(screen.getByRole('button', { name: '+ Clase' }));
    expect(await screen.findByText('3 clases')).toBeTruthy();
    expect(states.at(-1)?.classes).toHaveLength(3);

    await user.click(screen.getByRole('button', { name: 'Deshacer' }));
    expect(await screen.findByText('2 clases')).toBeTruthy();
    await user.click(screen.getByRole('button', { name: 'Rehacer' }));
    expect(await screen.findByText('3 clases')).toBeTruthy();

    await user.click(screen.getByRole('button', { name: 'Seleccionar class-cliente' }));
    const className = screen.getByLabelText('Nombre de clase');
    await user.clear(className);
    await user.type(className, 'Persona');
    await user.click(screen.getByRole('button', { name: 'Renombrar' }));
    await waitFor(() => expect(states.at(-1)?.classes[0]?.name).toBe('Persona'));

    await user.click(screen.getByRole('button', { name: 'Mover class-cliente' }));
    await waitFor(() => expect(states.at(-1)?.classes[0]?.position).toEqual({ x: 170, y: 185 }));

    await user.type(screen.getByPlaceholderText('telefono'), 'direccion');
    await user.click(screen.getByRole('button', { name: 'Agregar atributo' }));
    await waitFor(() => expect(states.at(-1)?.classes[0]?.attributes.some((item) => item.name === 'direccion')).toBe(true));
    await user.click(within(screen.getByRole('form', { name: 'Editar atributo direccion' })).getByRole('button', { name: 'Eliminar' }));
    await waitFor(() => expect(states.at(-1)?.classes[0]?.attributes.some((item) => item.name === 'direccion')).toBe(false));

    await user.click(screen.getByRole('button', { name: 'Conectar primeras clases' }));
    await waitFor(() => expect(states.at(-1)?.relationships).toHaveLength(2));
    await user.selectOptions(screen.getByLabelText('Tipo'), 'GENERALIZATION');
    await user.selectOptions(screen.getByLabelText('Multiplicidad en Mascota'), '1..*');
    await user.click(screen.getByRole('button', { name: 'Guardar relación' }));
    await waitFor(() => expect(states.at(-1)?.relationships[1]).toMatchObject({
      type: 'GENERALIZATION',
      sourceMultiplicity: '1',
      targetMultiplicity: '1..*',
    }));

    await user.click(screen.getByRole('button', { name: 'Eliminar selección' }));
    await waitFor(() => expect(states.at(-1)?.relationships).toHaveLength(1));
    await user.click(screen.getByRole('button', { name: 'Deshacer' }));
    await waitFor(() => expect(states.at(-1)?.relationships).toHaveLength(2));
    await user.click(screen.getByRole('button', { name: 'Rehacer' }));
    await waitFor(() => expect(states.at(-1)?.relationships).toHaveLength(1));
  });

  it('shows domain validation errors in the interface', async () => {
    const user = userEvent.setup();
    render(<DiagramEditor initialProject={structuredClone(veterinariaFixture) as ProjectModel} />);

    await user.click(screen.getByRole('button', { name: 'Seleccionar class-cliente' }));
    const className = screen.getByLabelText('Nombre de clase');
    await user.clear(className);
    await user.type(className, 'Mascota');
    await user.click(screen.getByRole('button', { name: 'Renombrar' }));

    expect((await screen.findByRole('alert')).textContent).toContain('Ya existe una clase con ese nombre');
  });
});
