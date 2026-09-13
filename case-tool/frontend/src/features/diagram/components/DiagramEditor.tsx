import {
  Background,
  BackgroundVariant,
  Controls,
  ReactFlow,
  useNodesState,
  type Connection,
  type EdgeTypes,
  type NodeMouseHandler,
  type NodeTypes,
  type OnNodeDrag,
} from '@xyflow/react';
import { useEffect, useMemo } from 'react';
import {
  randomId,
  type Command,
  type ProjectModel,
} from '../../../domain';
import { ReactFlowAdapter } from '../adapters/ReactFlowAdapter';
import { useDiagramEditor } from '../hooks/useDiagramEditor';
import type { DiagramFlowNode } from '../types/reactFlowTypes';
import { PropertiesPanel } from './PropertiesPanel';
import { RelationshipEdge } from './RelationshipEdge';
import { TextCommandBar } from './TextCommandBar';
import { UMLClassNode } from './UMLClassNode';
import { UMLEnumNode } from './UMLEnumNode';

const nodeTypes = {
  umlClass: UMLClassNode,
  umlEnum: UMLEnumNode,
} satisfies NodeTypes;

const edgeTypes = {
  umlRelationship: RelationshipEdge,
} satisfies EdgeTypes;

function nextClassName(project: ProjectModel): string {
  const existingNames = new Set(project.classes.map((item) => item.name.toLocaleLowerCase('es')));
  let suffix = project.classes.length + 1;
  let name = `NuevaClase${suffix}`;
  while (existingNames.has(name.toLocaleLowerCase('es'))) name = `NuevaClase${++suffix}`;
  return name;
}

export interface DiagramEditorProps {
  initialProject: ProjectModel;
  onProjectChange?: (project: ProjectModel) => void;
}

export function DiagramEditor({ initialProject, onProjectChange }: DiagramEditorProps) {
  const editor = useDiagramEditor(initialProject);
  const diagram = useMemo(
    () => ReactFlowAdapter.fromProject(editor.project),
    [editor.project],
  );
  const [nodes, setNodes, onNodesChange] = useNodesState<DiagramFlowNode>(diagram.nodes);
  const edges = useMemo(
    () => diagram.edges.map((edge) => ({
      ...edge,
      selected: editor.selection?.kind === 'relationship' && editor.selection.id === edge.id,
    })),
    [diagram.edges, editor.selection],
  );

  useEffect(() => setNodes(diagram.nodes), [diagram.nodes, setNodes]);
  useEffect(() => {
    onProjectChange?.(editor.project);
  }, [editor.project, onProjectChange]);

  const addClass = () => {
    const classId = randomId();
    const accepted = editor.execute({
      id: randomId(),
      type: 'ADD_CLASS',
      payload: {
        id: classId,
        name: nextClassName(editor.project),
        position: {
          x: 100 + (editor.project.classes.length % 3) * 300,
          y: 100 + Math.floor(editor.project.classes.length / 3) * 240,
        },
      },
    });
    if (accepted) editor.select({ kind: 'class', id: classId });
  };

  const deleteSelection = () => {
    if (!editor.selection) return;
    const command: Command = editor.selection.kind === 'class'
      ? { id: randomId(), type: 'DELETE_CLASS', targetId: editor.selection.id, payload: {} }
      : { id: randomId(), type: 'DELETE_RELATIONSHIP', targetId: editor.selection.id, payload: {} };
    if (editor.execute(command)) editor.select(null);
  };

  const connect = (connection: Connection) => {
    if (!connection.source || !connection.target) return;
    const relationshipId = randomId();
    const accepted = editor.execute({
      id: randomId(),
      type: 'ADD_RELATIONSHIP',
      payload: {
        id: relationshipId,
        type: 'ASSOCIATION',
        sourceClassId: connection.source,
        targetClassId: connection.target,
        sourceMultiplicity: '1',
        targetMultiplicity: '0..*',
      },
    });
    if (accepted) editor.select({ kind: 'relationship', id: relationshipId });
  };

  const nodeClicked: NodeMouseHandler<DiagramFlowNode> = (_event, node) => {
    if (node.type === 'umlClass') editor.select({ kind: 'class', id: node.id });
  };

  const nodeDragStopped: OnNodeDrag<DiagramFlowNode> = (_event, node) => {
    if (node.type !== 'umlClass') return;
    const accepted = editor.execute({
      id: randomId(),
      type: 'MOVE_CLASS',
      targetId: node.id,
      payload: { position: { x: node.position.x, y: node.position.y } },
    });
    if (!accepted) setNodes(diagram.nodes);
  };

  return (
    <main className="diagram-app">
      <header className="app-header">
        <div>
          <p className="eyebrow">GeneraTabla · Editor UML</p>
          <h1>{editor.project.name}</h1>
        </div>
        <div className="project-stats" aria-label="Estado del proyecto">
          <span>{editor.project.classes.length} clases</span>
          <span>revisión {editor.project.revision}</span>
        </div>
      </header>

      <nav className="diagram-toolbar" aria-label="Herramientas del diagrama">
        <button className="button button--primary" onClick={addClass}>+ Clase</button>
        <span className="toolbar-divider" />
        <button className="button" disabled={!editor.canUndo} onClick={editor.undo}>Deshacer</button>
        <button className="button" disabled={!editor.canRedo} onClick={editor.redo}>Rehacer</button>
        <button className="button button--danger" disabled={!editor.selection} onClick={deleteSelection}>Eliminar selección</button>
        <p className="toolbar-hint">Arrastra entre los conectores para crear una relación.</p>
      </nav>

      <div className="command-area">
        <TextCommandBar project={editor.project} onExecute={editor.execute} />
        {editor.error && (
          <div className="error-banner" role="alert">
            <span>{editor.error}</span>
            <button aria-label="Cerrar error" onClick={editor.dismissError}>×</button>
          </div>
        )}
      </div>

      <div className="editor-layout">
        <section className="diagram-canvas" aria-label="Lienzo UML">
          <ReactFlow
            nodes={nodes}
            edges={edges}
            nodeTypes={nodeTypes}
            edgeTypes={edgeTypes}
            onNodesChange={onNodesChange}
            onNodeClick={nodeClicked}
            onNodeDragStop={nodeDragStopped}
            onEdgeClick={(_event, edge) => editor.select({ kind: 'relationship', id: edge.id })}
            onConnect={connect}
            onPaneClick={() => editor.select(null)}
            deleteKeyCode={null}
            fitView
            minZoom={0.25}
            maxZoom={2}
          >
            <Background variant={BackgroundVariant.Dots} gap={20} size={1.2} />
            <Controls showInteractive={false} />
          </ReactFlow>
        </section>
        <PropertiesPanel
          project={editor.project}
          selection={editor.selection}
          onExecute={editor.execute}
        />
      </div>
    </main>
  );
}
