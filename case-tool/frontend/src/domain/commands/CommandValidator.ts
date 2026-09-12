import { createAttribute } from '../model/factories';
import type { ProjectModel } from '../model/types';
import { validateProject, type ValidationIssue } from '../model/validation';
import type { Command } from './types';

export interface CommandValidationResult {
  valid: boolean;
  issues: ValidationIssue[];
}

export class CommandValidationError extends Error {
  constructor(public readonly issues: ValidationIssue[]) {
    super(issues.map((issue) => issue.message).join(' '));
    this.name = 'CommandValidationError';
  }
}

function issue(code: string, path: string, message: string): ValidationIssue {
  return { code, path, message };
}

export class CommandValidator {
  validate(project: ProjectModel, command: Command): CommandValidationResult {
    const issues: ValidationIssue[] = [];

    if (!command.id.trim()) {
      issues.push(issue('INVALID_COMMAND_ID', 'command.id', 'El comando debe tener identificador.'));
    }

    switch (command.type) {
      case 'ADD_CLASS': {
        if (!command.payload.name.trim()) {
          issues.push(issue('EMPTY_NAME', 'command.payload.name', 'La clase debe tener nombre.'));
        }
        if (
          project.classes.some(
            (item) => item.name.trim().toLocaleLowerCase('es') === command.payload.name.trim().toLocaleLowerCase('es'),
          )
        ) {
          issues.push(issue('DUPLICATE_NAME', 'command.payload.name', 'Ya existe una clase con ese nombre.'));
        }
        break;
      }
      case 'DELETE_CLASS':
      case 'RENAME_CLASS':
      case 'MOVE_CLASS': {
        if (!project.classes.some((item) => item.id === command.targetId)) {
          issues.push(issue('CLASS_NOT_FOUND', 'command.targetId', `No existe la clase '${command.targetId}'.`));
        }
        if (command.type === 'RENAME_CLASS') {
          if (!command.payload.name.trim()) {
            issues.push(issue('EMPTY_NAME', 'command.payload.name', 'La clase debe tener nombre.'));
          }
          if (
            project.classes.some(
              (item) =>
                item.id !== command.targetId &&
                item.name.trim().toLocaleLowerCase('es') === command.payload.name.trim().toLocaleLowerCase('es'),
            )
          ) {
            issues.push(issue('DUPLICATE_NAME', 'command.payload.name', 'Ya existe una clase con ese nombre.'));
          }
        }
        if (
          command.type === 'MOVE_CLASS' &&
          (!Number.isFinite(command.payload.position.x) || !Number.isFinite(command.payload.position.y))
        ) {
          issues.push(issue('INVALID_POSITION', 'command.payload.position', 'La posición debe contener coordenadas finitas.'));
        }
        break;
      }
      case 'ADD_ATTRIBUTE': {
        const owner = project.classes.find((item) => item.id === command.targetId);
        if (!owner) {
          issues.push(issue('CLASS_NOT_FOUND', 'command.targetId', `No existe la clase '${command.targetId}'.`));
        } else if (
          owner.attributes.some(
            (item) => item.name.trim().toLocaleLowerCase('es') === command.payload.name.trim().toLocaleLowerCase('es'),
          )
        ) {
          issues.push(issue('DUPLICATE_NAME', 'command.payload.name', 'La clase ya contiene un atributo con ese nombre.'));
        }
        if (!command.payload.name.trim()) {
          issues.push(issue('EMPTY_NAME', 'command.payload.name', 'El atributo debe tener nombre.'));
        }
        break;
      }
      case 'UPDATE_ATTRIBUTE':
      case 'DELETE_ATTRIBUTE': {
        const owner = project.classes.find((item) =>
          item.attributes.some((attribute) => attribute.id === command.targetId),
        );
        if (!owner) {
          issues.push(issue('ATTRIBUTE_NOT_FOUND', 'command.targetId', `No existe el atributo '${command.targetId}'.`));
        } else if (command.type === 'UPDATE_ATTRIBUTE') {
          if (Object.keys(command.payload).length === 0) {
            issues.push(issue('EMPTY_UPDATE', 'command.payload', 'La actualización no contiene cambios.'));
          }
          if (command.payload.name !== undefined && !command.payload.name.trim()) {
            issues.push(issue('EMPTY_NAME', 'command.payload.name', 'El atributo debe tener nombre.'));
          }
          if (
            command.payload.name !== undefined &&
            owner.attributes.some(
              (item) =>
                item.id !== command.targetId &&
                item.name.trim().toLocaleLowerCase('es') === command.payload.name?.trim().toLocaleLowerCase('es'),
            )
          ) {
            issues.push(issue('DUPLICATE_NAME', 'command.payload.name', 'La clase ya contiene un atributo con ese nombre.'));
          }
        }
        break;
      }
      case 'ADD_RELATIONSHIP': {
        if (!project.classes.some((item) => item.id === command.payload.sourceClassId)) {
          issues.push(issue('CLASS_NOT_FOUND', 'command.payload.sourceClassId', 'No existe la clase origen.'));
        }
        if (!project.classes.some((item) => item.id === command.payload.targetClassId)) {
          issues.push(issue('CLASS_NOT_FOUND', 'command.payload.targetClassId', 'No existe la clase destino.'));
        }
        break;
      }
      case 'UPDATE_RELATIONSHIP':
      case 'DELETE_RELATIONSHIP': {
        if (!project.relationships.some((item) => item.id === command.targetId)) {
          issues.push(issue('RELATIONSHIP_NOT_FOUND', 'command.targetId', `No existe la relación '${command.targetId}'.`));
        }
        if (command.type === 'UPDATE_RELATIONSHIP' && Object.keys(command.payload).length === 0) {
          issues.push(issue('EMPTY_UPDATE', 'command.payload', 'La actualización no contiene cambios.'));
        }
        break;
      }
    }

    if (issues.length === 0) {
      const candidate = this.preview(project, command);
      const modelResult = validateProject(candidate);
      issues.push(...modelResult.issues);
    }

    return { valid: issues.length === 0, issues };
  }

  assertValid(project: ProjectModel, command: Command): void {
    const result = this.validate(project, command);
    if (!result.valid) throw new CommandValidationError(result.issues);
  }

  private preview(project: ProjectModel, command: Command): ProjectModel {
    const candidate = structuredClone(project);
    candidate.revision += 1;

    const previewId = (kind: string): string => {
      const knownIds = new Set([
        candidate.id,
        ...candidate.classes.flatMap((item) => [
          item.id,
          ...item.attributes.map((attribute) => attribute.id),
        ]),
        ...candidate.relationships.map((item) => item.id),
        ...candidate.enumerations.map((item) => item.id),
      ]);
      let suffix = candidate.revision;
      let value = `preview-${kind}-${suffix}`;
      while (knownIds.has(value)) value = `preview-${kind}-${++suffix}`;
      return value;
    };

    switch (command.type) {
      case 'ADD_CLASS':
        candidate.classes.push({
          id: command.payload.id ?? previewId('class'),
          name: command.payload.name,
          position: command.payload.position ?? { x: 0, y: 0 },
          attributes: [],
        });
        break;
      case 'DELETE_CLASS':
        candidate.classes = candidate.classes.filter((item) => item.id !== command.targetId);
        candidate.relationships = candidate.relationships.filter(
          (item) => item.sourceClassId !== command.targetId && item.targetClassId !== command.targetId,
        );
        break;
      case 'RENAME_CLASS': {
        const umlClass = candidate.classes.find((item) => item.id === command.targetId);
        if (umlClass) umlClass.name = command.payload.name;
        break;
      }
      case 'MOVE_CLASS': {
        const umlClass = candidate.classes.find((item) => item.id === command.targetId);
        if (umlClass) umlClass.position = command.payload.position;
        break;
      }
      case 'ADD_ATTRIBUTE': {
        const umlClass = candidate.classes.find((item) => item.id === command.targetId);
        umlClass?.attributes.push(
          command.payload.id
            ? { ...createAttribute(command.payload, () => command.payload.id ?? previewId('attribute')), id: command.payload.id }
            : createAttribute(command.payload, () => previewId('attribute')),
        );
        break;
      }
      case 'UPDATE_ATTRIBUTE':
        for (const umlClass of candidate.classes) {
          const index = umlClass.attributes.findIndex((item) => item.id === command.targetId);
          if (index >= 0) {
            const current = umlClass.attributes[index];
            if (current) umlClass.attributes[index] = { ...current, ...command.payload };
            break;
          }
        }
        break;
      case 'DELETE_ATTRIBUTE':
        for (const umlClass of candidate.classes) {
          umlClass.attributes = umlClass.attributes.filter((item) => item.id !== command.targetId);
        }
        break;
      case 'ADD_RELATIONSHIP':
        candidate.relationships.push({
          ...command.payload,
          id: command.payload.id ?? previewId('relationship'),
        });
        break;
      case 'UPDATE_RELATIONSHIP': {
        const index = candidate.relationships.findIndex((item) => item.id === command.targetId);
        const current = candidate.relationships[index];
        if (index >= 0 && current) candidate.relationships[index] = { ...current, ...command.payload };
        break;
      }
      case 'DELETE_RELATIONSHIP':
        candidate.relationships = candidate.relationships.filter((item) => item.id !== command.targetId);
        break;
    }

    return candidate;
  }
}
