import {
  BaseEdge,
  EdgeLabelRenderer,
  getBezierPath,
  type EdgeProps,
} from '@xyflow/react';
import type { RelationshipFlowEdge } from '../types/reactFlowTypes';

export function RelationshipEdge({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  markerEnd,
  style,
  data,
  selected,
}: EdgeProps<RelationshipFlowEdge>) {
  const [edgePath] = getBezierPath({
    sourceX,
    sourceY,
    sourcePosition,
    targetX,
    targetY,
    targetPosition,
  });
  const sourceLabel = {
    x: sourceX + (targetX - sourceX) * 0.16,
    y: sourceY + (targetY - sourceY) * 0.16,
  };
  const targetLabel = {
    x: sourceX + (targetX - sourceX) * 0.84,
    y: sourceY + (targetY - sourceY) * 0.84,
  };

  return (
    <>
      <BaseEdge
        id={id}
        path={edgePath}
        {...(markerEnd ? { markerEnd } : {})}
        {...(style ? { style } : {})}
        {...(selected ? { className: 'relationship-edge__path--selected' } : {})}
      />
      <EdgeLabelRenderer>
        <span
          className="relationship-label nodrag nopan"
          style={{ transform: `translate(-50%, -50%) translate(${sourceLabel.x}px, ${sourceLabel.y}px)` }}
          aria-label={`Multiplicidad origen ${data?.sourceMultiplicity ?? ''}`}
        >
          {data?.sourceMultiplicity}
        </span>
        <span
          className="relationship-label nodrag nopan"
          style={{ transform: `translate(-50%, -50%) translate(${targetLabel.x}px, ${targetLabel.y}px)` }}
          aria-label={`Multiplicidad destino ${data?.targetMultiplicity ?? ''}`}
        >
          {data?.targetMultiplicity}
        </span>
      </EdgeLabelRenderer>
    </>
  );
}
