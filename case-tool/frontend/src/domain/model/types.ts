export const BUILT_IN_DATA_TYPES = [
  'String',
  'Integer',
  'Long',
  'Double',
  'Decimal',
  'Boolean',
  'Date',
  'DateTime',
  'UUID',
] as const;

export type BuiltInDataType = (typeof BUILT_IN_DATA_TYPES)[number];
export type DataType = BuiltInDataType | string;
export type JsonScalar = string | number | boolean | null;

export const MULTIPLICITIES = ['0..1', '1', '0..*', '1..*'] as const;
export type Multiplicity = (typeof MULTIPLICITIES)[number];

export const RELATIONSHIP_TYPES = ['ASSOCIATION', 'GENERALIZATION'] as const;
export type RelationshipType = (typeof RELATIONSHIP_TYPES)[number];

export interface Position {
  x: number;
  y: number;
}

export interface ExternalPackageReference {
  name?: string;
  externalId?: string;
  guid?: string;
  xmiId?: string;
}

export interface ExternalReference {
  source: string;
  scope?: string;
  externalId?: string;
  guid?: string;
  xmiId?: string;
  package?: ExternalPackageReference;
}

export interface ExternallyReferenceable {
  externalReferences?: ExternalReference[];
}

export interface AttributeModel extends ExternallyReferenceable {
  id: string;
  name: string;
  dataType: DataType;
  nullable: boolean;
  unique: boolean;
  primaryKey: boolean;
  defaultValue?: JsonScalar;
}

export interface ClassModel extends ExternallyReferenceable {
  id: string;
  name: string;
  position: Position;
  attributes: AttributeModel[];
}

export interface RelationshipModel extends ExternallyReferenceable {
  id: string;
  type: RelationshipType;
  sourceClassId: string;
  targetClassId: string;
  sourceMultiplicity: Multiplicity;
  targetMultiplicity: Multiplicity;
  sourceRole?: string;
  targetRole?: string;
}

export interface EnumerationModel extends ExternallyReferenceable {
  id: string;
  name: string;
  values: string[];
}

export interface ProjectModel extends ExternallyReferenceable {
  id: string;
  name: string;
  revision: number;
  classes: ClassModel[];
  relationships: RelationshipModel[];
  enumerations: EnumerationModel[];
}
