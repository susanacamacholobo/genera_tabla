import type { NodeProps } from '@xyflow/react';
import type { UMLEnumFlowNode } from '../types/reactFlowTypes';

export function UMLEnumNode({ data }: NodeProps<UMLEnumFlowNode>) {
  return (
    <article className="uml-node uml-enum-node" aria-label={`Enumeración ${data.name}`}>
      <header className="uml-node__header">
        <small>&lt;&lt;enumeration&gt;&gt;</small>
        <strong>{data.name}</strong>
      </header>
      <ul className="uml-enum-values">
        {data.values.map((value) => (
          <li key={value}>{value}</li>
        ))}
      </ul>
    </article>
  );
}

