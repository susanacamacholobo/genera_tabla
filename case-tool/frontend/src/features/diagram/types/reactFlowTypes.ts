import type { Edge, Node } from '@xyflow/react';
import type {
  DataType,
  Multiplicity,
  RelationshipType,
} from '../../../domain';

export interface AttributeViewModel extends Record<string, unknown> {
  id: string;
  name: string;
  dataType: DataType;
  primaryKey: boolean;
  nullable: boolean;
  unique: boolean;
}

export interface UMLClassNodeData extends Record<string, unknown> {
  classId: string;
  name: string;
  attributes: AttributeViewModel[];
}

export interface UMLEnumNodeData extends Record<string, unknown> {
  enumerationId: string;
  name: string;
  values: string[];
}

export interface RelationshipEdgeData extends Record<string, unknown> {
  relationshipId: string;
  relationshipType: RelationshipType;
  sourceMultiplicity: Multiplicity;
  targetMultiplicity: Multiplicity;
  sourceRole?: string;
  targetRole?: string;
}

export type UMLClassFlowNode = Node<UMLClassNodeData, 'umlClass'>;
export type UMLEnumFlowNode = Node<UMLEnumNodeData, 'umlEnum'>;
export type DiagramFlowNode = UMLClassFlowNode | UMLEnumFlowNode;
export type RelationshipFlowEdge = Edge<
  RelationshipEdgeData,
  'umlRelationship'
>;

export interface ReactFlowDiagram {
  nodes: DiagramFlowNode[];
  edges: RelationshipFlowEdge[];
}

