import { createAttribute, randomId, type IdGenerator } from '../model/factories';
import type { ProjectModel } from '../model/types';
import { validateProject } from '../model/validation';
import { CommandValidationError, CommandValidator } from './CommandValidator';
import type { Command } from './types';

export class CommandExecutor {
  private readonly validator: CommandValidator;

  constructor(private readonly createId: IdGenerator = randomId) {
    this.validator = new CommandValidator();
  }

  execute(project: ProjectModel, command: Command): ProjectModel {
    this.validator.assertValid(project, command);
    const next = structuredClone(project);
    next.revision += 1;

    switch (command.type) {
      case 'ADD_CLASS':
        next.classes.push({
          id: command.payload.id ?? this.createId(),
          name: command.payload.name.trim(),
          position: command.payload.position ?? { x: 0, y: 0 },
          attributes: [],
        });
        break;
      case 'DELETE_CLASS':
        next.classes = next.classes.filter((item) => item.id !== command.targetId);
        next.relationships = next.relationships.filter(
          (item) => item.sourceClassId !== command.targetId && item.targetClassId !== command.targetId,
        );
        break;
      case 'RENAME_CLASS': {
        const umlClass = next.classes.find((item) => item.id === command.targetId);
        if (umlClass) umlClass.name = command.payload.name.trim();
        break;
      }
      case 'MOVE_CLASS': {
        const umlClass = next.classes.find((item) => item.id === command.targetId);
        if (umlClass) umlClass.position = { ...command.payload.position };
        break;
      }
      case 'ADD_ATTRIBUTE': {
        const umlClass = next.classes.find((item) => item.id === command.targetId);
        if (umlClass) {
          const attribute = createAttribute(command.payload, this.createId);
          umlClass.attributes.push({
            ...attribute,
            ...(command.payload.id ? { id: command.payload.id } : {}),
            name: attribute.name.trim(),
          });
        }
        break;
      }
      case 'UPDATE_ATTRIBUTE':
        for (const umlClass of next.classes) {
          const index = umlClass.attributes.findIndex((item) => item.id === command.targetId);
          const current = umlClass.attributes[index];
          if (index >= 0 && current) {
            umlClass.attributes[index] = {
              ...current,
              ...command.payload,
              ...(command.payload.name ? { name: command.payload.name.trim() } : {}),
            };
            break;
          }
        }
        break;
      case 'DELETE_ATTRIBUTE':
        for (const umlClass of next.classes) {
          umlClass.attributes = umlClass.attributes.filter((item) => item.id !== command.targetId);
        }
        break;
      case 'ADD_RELATIONSHIP':
        next.relationships.push({
          ...command.payload,
          id: command.payload.id ?? this.createId(),
        });
        break;
      case 'UPDATE_RELATIONSHIP': {
        const index = next.relationships.findIndex((item) => item.id === command.targetId);
        const current = next.relationships[index];
        if (index >= 0 && current) next.relationships[index] = { ...current, ...command.payload };
        break;
      }
      case 'DELETE_RELATIONSHIP':
        next.relationships = next.relationships.filter((item) => item.id !== command.targetId);
        break;
    }

    return next;
  }

  restore(snapshot: ProjectModel): ProjectModel {
    const result = validateProject(snapshot);
    if (!result.valid) throw new CommandValidationError(result.issues);
    return structuredClone(snapshot);
  }

  restoreAsNextRevision(snapshot: ProjectModel, currentRevision: number): ProjectModel {
    const restored = structuredClone(snapshot);
    restored.revision = currentRevision + 1;
    return this.restore(restored);
  }
}
