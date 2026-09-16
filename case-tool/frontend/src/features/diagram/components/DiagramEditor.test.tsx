// @vitest-environment jsdom

import { cleanup, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type {
  CommandParseResult,
  NaturalLanguageCommandParser,
  ProjectModel,
} from '../../../domain';
import veterinariaFixture from '../../../../../../docs/examples/veterinaria.json';
import { DiagramEditor } from './DiagramEditor';
import type { SpeechProvider } from '../voice/BrowserSpeechProvider';
import { ProjectSession } from '../collaboration/ProjectSession';

class FakeWebSocket {
  static OPEN = 1;
  static instances: FakeWebSocket[] = [];
  readyState = 1;
  onmessage: ((event: MessageEvent<string>) => void) | null = null;
  onclose: (() => void) | null = null;
  onerror: (() => void) | null = null;
  sent: Array<{ command: { id: string; type: string }; model: ProjectModel; baseRevision: number }> = [];
  constructor() { FakeWebSocket.instances.push(this); }
  send(value: string) { this.sent.push(JSON.parse(value)); }
  close() { this.readyState = 3; this.onclose?.(); }
  emit(value: unknown) { this.onmessage?.({ data: JSON.stringify(value) } as MessageEvent<string>); }
}

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

afterEach(() => { cleanup(); vi.unstubAllGlobals(); });

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

  it('executes deterministic text commands through the same history', async () => {
    const user = userEvent.setup();
    const states: ProjectModel[] = [];
    render(
      <DiagramEditor
        initialProject={structuredClone(veterinariaFixture) as ProjectModel}
        onProjectChange={(project) => states.push(project)}
      />,
    );

    const input = screen.getByLabelText('Comando');
    await user.type(input, 'crea clase Factura');
    await user.click(screen.getByRole('button', { name: 'Revisar propuesta' }));
    expect(states.at(-1)?.classes.some((item) => item.name === 'Factura')).toBe(false);
    await user.click(await screen.findByRole('button', { name: 'Confirmar cambio' }));
    await waitFor(() => expect(states.at(-1)?.classes.some((item) => item.name === 'Factura')).toBe(true));
    expect(screen.getByRole('status').textContent).toContain('Comando aplicado');

    await user.type(input, 'agrega total decimal a Factura');
    await user.click(screen.getByRole('button', { name: 'Revisar propuesta' }));
    await user.click(await screen.findByRole('button', { name: 'Confirmar cambio' }));
    await waitFor(() => expect(
      states.at(-1)?.classes.find((item) => item.name === 'Factura')?.attributes[0],
    ).toMatchObject({ name: 'total', dataType: 'Decimal' }));

    await user.click(screen.getByRole('button', { name: 'Deshacer' }));
    await waitFor(() => expect(
      states.at(-1)?.classes.find((item) => item.name === 'Factura')?.attributes,
    ).toHaveLength(0));
  });

  it('shows parser errors without changing the project', async () => {
    const user = userEvent.setup();
    const states: ProjectModel[] = [];
    render(
      <DiagramEditor
        initialProject={structuredClone(veterinariaFixture) as ProjectModel}
        onProjectChange={(project) => states.push(project)}
      />,
    );

    await user.type(screen.getByLabelText('Comando'), 'elimina Fantasma');
    await user.click(screen.getByRole('button', { name: 'Revisar propuesta' }));

    expect((await screen.findByRole('alert')).textContent).toContain('No existe la clase «Fantasma»');
    expect(states.at(-1)?.classes).toHaveLength(2);
  });

  it('waits for an asynchronous command parser before executing its command', async () => {
    const user = userEvent.setup();
    let completeParsing: ((result: CommandParseResult) => void) | undefined;
    const parser: NaturalLanguageCommandParser = {
      parse: vi.fn(() => new Promise<CommandParseResult>((resolve) => {
        completeParsing = resolve;
      })),
    };
    const states: ProjectModel[] = [];
    render(
      <DiagramEditor
        initialProject={structuredClone(veterinariaFixture) as ProjectModel}
        onProjectChange={(project) => states.push(project)}
        commandParser={parser}
      />,
    );

    await user.type(screen.getByLabelText('Comando'), 'crea una factura');
    await user.click(screen.getByRole('button', { name: 'Revisar propuesta' }));

    expect((screen.getByRole('button', { name: 'Interpretando…' }) as HTMLButtonElement).disabled).toBe(true);
    completeParsing?.({
      ok: true,
      command: {
        id: 'command-from-llm',
        type: 'ADD_CLASS',
        payload: {
          id: 'class-factura',
          name: 'Factura',
          position: { x: 500, y: 100 },
        },
      },
    });

    await screen.findByRole('region', { name: 'Propuesta de cambio' });
    expect(states.at(-1)?.classes.some((item) => item.id === 'class-factura')).toBe(false);
    await user.click(screen.getByRole('button', { name: 'Confirmar cambio' }));
    await waitFor(() => expect(
      states.at(-1)?.classes.some((item) => item.id === 'class-factura'),
    ).toBe(true));
    expect((screen.getByRole('button', { name: 'Revisar propuesta' }) as HTMLButtonElement).disabled).toBe(false);
  });

  it('dictates, previews, cancels and confirms a class change without applying it early', async () => {
    const user = userEvent.setup();
    const speechProvider: SpeechProvider = {
      isSupported: () => true,
      listen: vi.fn().mockResolvedValue('crea clase Factura'),
      cancel: vi.fn(),
    };
    const states: ProjectModel[] = [];
    render(
      <DiagramEditor
        initialProject={structuredClone(veterinariaFixture) as ProjectModel}
        onProjectChange={(project) => states.push(project)}
        speechProvider={speechProvider}
      />,
    );

    await user.click(screen.getByRole('button', { name: '🎤 Dictar' }));
    await waitFor(() => expect((screen.getByLabelText('Comando') as HTMLInputElement).value).toBe('crea clase Factura'));
    expect(states.at(-1)?.classes).toHaveLength(2);

    await user.click(screen.getByRole('button', { name: 'Revisar propuesta' }));
    expect((await screen.findByRole('region', { name: 'Propuesta de cambio' })).textContent).toContain('Factura');
    expect(states.at(-1)?.classes).toHaveLength(2);
    await user.click(screen.getByRole('button', { name: 'Cancelar' }));
    expect(states.at(-1)?.classes).toHaveLength(2);

    await user.click(screen.getByRole('button', { name: 'Revisar propuesta' }));
    await user.click(await screen.findByRole('button', { name: 'Confirmar cambio' }));
    await waitFor(() => expect(states.at(-1)?.classes.some((item) => item.name === 'Factura')).toBe(true));
    await user.click(screen.getByRole('button', { name: 'Deshacer' }));
    await waitFor(() => expect(states.at(-1)?.classes.some((item) => item.name === 'Factura')).toBe(false));
  });

  it('uses AI only after the user selects it and still requires confirmation', async () => {
    const user = userEvent.setup();
    const aiProvider = { generate: vi.fn().mockResolvedValue(JSON.stringify({
      actions: [{ type: 'RENAME_CLASS', targetName: 'Cliente', payload: { name: 'Persona' } }],
    })) };
    const states: ProjectModel[] = [];
    render(
      <DiagramEditor
        initialProject={structuredClone(veterinariaFixture) as ProjectModel}
        onProjectChange={(project) => states.push(project)}
        aiProvider={aiProvider}
        aiRemote
      />,
    );

    await user.click(screen.getByRole('button', { name: 'IA asistida' }));
    expect(screen.getByText(/contexto UML se enviará al proveedor remoto/)).toBeTruthy();
    await user.type(screen.getByLabelText('Comando'), 'Cambia Cliente a Persona');
    await user.click(screen.getByRole('button', { name: 'Revisar propuesta' }));
    await screen.findByRole('region', { name: 'Propuesta de cambio' });

    expect(aiProvider.generate).toHaveBeenCalledOnce();
    expect(states.at(-1)?.classes[0]?.name).toBe('Cliente');
    await user.click(screen.getByRole('button', { name: 'Confirmar cambio' }));
    await waitFor(() => expect(states.at(-1)?.classes[0]?.name).toBe('Persona'));
  });

  it('syncs confirmed commands, undo and remote changes through the project session', async () => {
    FakeWebSocket.instances = [];
    vi.stubGlobal('WebSocket', FakeWebSocket);
    const user = userEvent.setup();
    const initial = structuredClone(veterinariaFixture) as ProjectModel;
    const states: ProjectModel[] = [];
    render(<DiagramEditor initialProject={initial} session={new ProjectSession(initial.id)} onProjectChange={(model) => states.push(model)} />);
    const socket = FakeWebSocket.instances[0]!;
    expect((screen.getByRole('button', { name: '+ Clase' }) as HTMLButtonElement).disabled).toBe(true);
    socket.emit({ type: 'session.ready', model: initial });
    await screen.findByText('Sincronizado');

    await user.type(screen.getByLabelText('Comando'), 'crea clase Factura');
    await user.click(screen.getByRole('button', { name: 'Revisar propuesta' }));
    await user.click(await screen.findByRole('button', { name: 'Confirmar cambio' }));
    expect(socket.sent).toHaveLength(1);
    expect(socket.sent[0]).toMatchObject({ baseRevision: 0, command: { type: 'ADD_CLASS' } });
    expect(states.at(-1)?.classes.some((item) => item.name === 'Factura')).toBe(true);
    expect((screen.getByRole('button', { name: 'Deshacer' }) as HTMLButtonElement).disabled).toBe(true);
    socket.emit({ type: 'change.applied', model: socket.sent[0]!.model, command: socket.sent[0]!.command });
    await screen.findByText('Sincronizado');

    await user.click(screen.getByRole('button', { name: 'Deshacer' }));
    expect(socket.sent[1]).toMatchObject({ baseRevision: 1, command: { type: 'UNDO' } });
    socket.emit({ type: 'change.applied', model: socket.sent[1]!.model, command: socket.sent[1]!.command });
    await waitFor(() => expect(states.at(-1)?.classes.some((item) => item.name === 'Factura')).toBe(false));

    const remote = structuredClone(socket.sent[1]!.model);
    remote.revision += 1;
    remote.classes.push({ id: 'remote-class', name: 'Pedido', position: { x: 1, y: 2 }, attributes: [] });
    socket.emit({ type: 'change.applied', model: remote, command: { id: 'remote-command' } });
    await waitFor(() => expect(states.at(-1)?.classes.some((item) => item.name === 'Pedido')).toBe(true));
    expect((screen.getByRole('button', { name: 'Deshacer' }) as HTMLButtonElement).disabled).toBe(true);
  });
});
