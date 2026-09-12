import type {
  AttributeModel,
  ClassModel,
  Position,
  ProjectModel,
} from './types';

export type IdGenerator = () => string;

export const randomId: IdGenerator = () => crypto.randomUUID();

export function createProject(
  name: string,
  createId: IdGenerator = randomId,
): ProjectModel {
  return {
    id: createId(),
    name,
    revision: 0,
    classes: [],
    relationships: [],
    enumerations: [],
  };
}

export function createClass(
  name: string,
  position: Position = { x: 0, y: 0 },
  createId: IdGenerator = randomId,
): ClassModel {
  return { id: createId(), name, position, attributes: [] };
}

export function createAttribute(
  input: Pick<AttributeModel, 'name' | 'dataType'> & Partial<Omit<AttributeModel, 'id' | 'name' | 'dataType'>>,
  createId: IdGenerator = randomId,
): AttributeModel {
  const primaryKey = input.primaryKey ?? false;

  return {
    id: createId(),
    name: input.name,
    dataType: input.dataType,
    nullable: primaryKey ? false : (input.nullable ?? true),
    unique: input.unique ?? primaryKey,
    primaryKey,
    ...(input.defaultValue !== undefined
      ? { defaultValue: input.defaultValue }
      : {}),
  };
}

