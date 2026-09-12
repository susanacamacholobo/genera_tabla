import { MarkerType } from '@xyflow/react';
import type { ProjectModel } from '../../../domain';
import type {
  AttributeViewModel,
  ReactFlowDiagram,
  RelationshipFlowEdge,
  UMLClassFlowNode,
  UMLEnumFlowNode,
} from '../types/reactFlowTypes';

const ENUM_HORIZONTAL_GAP = 280;
const ENUM_VERTICAL_GAP = 260;

function toAttributeViewModel(
  attribute: ProjectModel['classes'][number]['attributes'][number],
): AttributeViewModel {
  return {
    id: attribute.id,
    name: attribute.name,
    dataType: attribute.dataType,
    primaryKey: attribute.primaryKey,
    nullable: attribute.nullable,
    unique: attribute.unique,
  };
}

function toClassNode(
  umlClass: ProjectModel['classes'][number],
): UMLClassFlowNode {
  return {
    id: umlClass.id,
    type: 'umlClass',
    position: { ...umlClass.position },
    data: {
      classId: umlClass.id,
      name: umlClass.name,
      attributes: umlClass.attributes.map(toAttributeViewModel),
    },
  };
}

function enumBaseline(project: ProjectModel): number {
  if (project.classes.length === 0) return 80;
  return Math.max(...project.classes.map((umlClass) => umlClass.position.y)) + ENUM_VERTICAL_GAP;
}

function toEnumNode(
  enumeration: ProjectModel['enumerations'][number],
  index: number,
  baseline: number,
): UMLEnumFlowNode {
  return {
    id: enumeration.id,
    type: 'umlEnum',
    position: { x: 80 + index * ENUM_HORIZONTAL_GAP, y: baseline },
    draggable: false,
    selectable: false,
    connectable: false,
    data: {
      enumerationId: enumeration.id,
      name: enumeration.name,
      values: [...enumeration.values],
    },
  };
}

function toRelationshipEdge(
  relationship: ProjectModel['relationships'][number],
): RelationshipFlowEdge {
  const isGeneralization = relationship.type === 'GENERALIZATION';

  return {
    id: relationship.id,
    type: 'umlRelationship',
    source: relationship.sourceClassId,
    target: relationship.targetClassId,
    data: {
      relationshipId: relationship.id,
      relationshipType: relationship.type,
      sourceMultiplicity: relationship.sourceMultiplicity,
      targetMultiplicity: relationship.targetMultiplicity,
      ...(relationship.sourceRole ? { sourceRole: relationship.sourceRole } : {}),
      ...(relationship.targetRole ? { targetRole: relationship.targetRole } : {}),
    },
    className: isGeneralization
      ? 'relationship-edge relationship-edge--generalization'
      : 'relationship-edge relationship-edge--association',
    ...(isGeneralization
      ? {
          markerEnd: {
            type: MarkerType.ArrowClosed,
            width: 24,
            height: 24,
            color: '#475569',
          },
        }
      : {}),
  };
}

export class ReactFlowAdapter {
  static fromProject(project: ProjectModel): ReactFlowDiagram {
    const baseline = enumBaseline(project);

    return {
      nodes: [
        ...project.classes.map(toClassNode),
        ...project.enumerations.map((enumeration, index) =>
          toEnumNode(enumeration, index, baseline),
        ),
      ],
      edges: project.relationships.map(toRelationshipEdge),
    };
  }
}

