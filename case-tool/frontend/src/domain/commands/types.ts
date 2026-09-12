import type {
  AttributeModel,
  ClassModel,
  Position,
  RelationshipModel,
} from '../model/types';

interface BaseCommand<Type extends string, Payload> {
  id: string;
  type: Type;
  payload: Payload;
  targetId?: string;
}

export type AddClassCommand = BaseCommand<
  'ADD_CLASS',
  Pick<ClassModel, 'name'> & Partial<Pick<ClassModel, 'id' | 'position'>>
>;

export type DeleteClassCommand = BaseCommand<'DELETE_CLASS', Record<string, never>> & {
  targetId: string;
};

export type RenameClassCommand = BaseCommand<'RENAME_CLASS', Pick<ClassModel, 'name'>> & {
  targetId: string;
};

export type MoveClassCommand = BaseCommand<'MOVE_CLASS', { position: Position }> & {
  targetId: string;
};

export type AddAttributeCommand = BaseCommand<
  'ADD_ATTRIBUTE',
  Pick<AttributeModel, 'name' | 'dataType'> &
    Partial<Omit<AttributeModel, 'name' | 'dataType'>>
> & { targetId: string };

export type UpdateAttributeCommand = BaseCommand<
  'UPDATE_ATTRIBUTE',
  Partial<Omit<AttributeModel, 'id'>>
> & { targetId: string };

export type DeleteAttributeCommand = BaseCommand<
  'DELETE_ATTRIBUTE',
  Record<string, never>
> & { targetId: string };

export type AddRelationshipCommand = BaseCommand<
  'ADD_RELATIONSHIP',
  Omit<RelationshipModel, 'id'> & Partial<Pick<RelationshipModel, 'id'>>
>;

export type UpdateRelationshipCommand = BaseCommand<
  'UPDATE_RELATIONSHIP',
  Partial<Omit<RelationshipModel, 'id'>>
> & { targetId: string };

export type DeleteRelationshipCommand = BaseCommand<
  'DELETE_RELATIONSHIP',
  Record<string, never>
> & { targetId: string };

export type Command =
  | AddClassCommand
  | DeleteClassCommand
  | RenameClassCommand
  | MoveClassCommand
  | AddAttributeCommand
  | UpdateAttributeCommand
  | DeleteAttributeCommand
  | AddRelationshipCommand
  | UpdateRelationshipCommand
  | DeleteRelationshipCommand;

export type CommandType = Command['type'];
