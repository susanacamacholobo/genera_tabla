import { Handle, Position, type NodeProps } from '@xyflow/react';
import type { UMLClassFlowNode } from '../types/reactFlowTypes';

export function UMLClassNode({ data, selected }: NodeProps<UMLClassFlowNode>) {
  return (
    <article
      className={`uml-node uml-class-node${selected ? ' uml-node--selected' : ''}`}
      aria-label={`Clase ${data.name}`}
    >
      <Handle
        type="target"
        position={Position.Left}
        className="uml-handle"
        aria-label={`Conectar hacia ${data.name}`}
      />
      <header className="uml-node__header">{data.name}</header>
      <div className="uml-node__body">
        {data.attributes.length === 0 ? (
          <p className="uml-node__empty">Sin atributos</p>
        ) : (
          <ul className="uml-attribute-list">
            {data.attributes.map((attribute) => (
              <li key={attribute.id} className="uml-attribute">
                <span
                  className="uml-attribute__key"
                  aria-label={attribute.primaryKey ? 'Clave primaria' : undefined}
                >
                  {attribute.primaryKey ? '◆' : ''}
                </span>
                <span className="uml-attribute__name">{attribute.name}</span>
                <span aria-hidden="true">:</span>
                <span className="uml-attribute__type">{attribute.dataType}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
      <Handle
        type="source"
        position={Position.Right}
        className="uml-handle"
        aria-label={`Conectar desde ${data.name}`}
      />
    </article>
  );
}

