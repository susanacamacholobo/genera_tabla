import {
  BUILT_IN_DATA_TYPES,
  MULTIPLICITIES,
  RELATIONSHIP_TYPES,
  type ProjectModel,
} from './types';

export interface ValidationIssue {
  code: string;
  path: string;
  message: string;
}

export interface ModelValidationResult {
  valid: boolean;
  issues: ValidationIssue[];
}

const ID_PATTERN = /^[\p{L}\p{N}][\p{L}\p{N}_.-]*$/u;

function normalized(value: string): string {
  return value.trim().toLocaleLowerCase('es');
}

function addDuplicateNameIssues(
  items: ReadonlyArray<{ name: string }>,
  path: string,
  issues: ValidationIssue[],
): void {
  const seen = new Map<string, number>();
  items.forEach((item, index) => {
    const key = normalized(item.name);
    const firstIndex = seen.get(key);
    if (key && firstIndex !== undefined) {
      issues.push({
        code: 'DUPLICATE_NAME',
        path: `${path}[${index}].name`,
        message: `El nombre '${item.name}' ya existe en ${path}[${firstIndex}].`,
      });
    } else if (key) {
      seen.set(key, index);
    }
  });
}

function validateId(
  id: string,
  path: string,
  seenIds: Set<string>,
  issues: ValidationIssue[],
): void {
  if (!ID_PATTERN.test(id)) {
    issues.push({
      code: 'INVALID_ID',
      path,
      message: 'El identificador debe ser una cadena no vacía sin espacios.',
    });
    return;
  }
  if (seenIds.has(id)) {
    issues.push({
      code: 'DUPLICATE_ID',
      path,
      message: `El identificador '${id}' está repetido en el proyecto.`,
    });
  }
  seenIds.add(id);
}

function detectGeneralizationCycles(project: ProjectModel): ValidationIssue[] {
  const graph = new Map<string, string[]>();
  for (const relationship of project.relationships) {
    if (relationship.type === 'GENERALIZATION') {
      const parents = graph.get(relationship.sourceClassId) ?? [];
      parents.push(relationship.targetClassId);
      graph.set(relationship.sourceClassId, parents);
    }
  }

  const visiting = new Set<string>();
  const visited = new Set<string>();

  function visit(classId: string): boolean {
    if (visiting.has(classId)) return true;
    if (visited.has(classId)) return false;
    visiting.add(classId);
    for (const parentId of graph.get(classId) ?? []) {
      if (visit(parentId)) return true;
    }
    visiting.delete(classId);
    visited.add(classId);
    return false;
  }

  for (const classId of graph.keys()) {
    if (visit(classId)) {
      return [
        {
          code: 'GENERALIZATION_CYCLE',
          path: 'relationships',
          message: 'Las generalizaciones no pueden formar ciclos de herencia.',
        },
      ];
    }
  }
  return [];
}

export function validateProject(project: ProjectModel): ModelValidationResult {
  const issues: ValidationIssue[] = [];
  const seenIds = new Set<string>();

  validateId(project.id, 'id', seenIds, issues);
  if (!project.name.trim()) {
    issues.push({ code: 'EMPTY_NAME', path: 'name', message: 'El proyecto debe tener nombre.' });
  }
  if (!Number.isSafeInteger(project.revision) || project.revision < 0) {
    issues.push({
      code: 'INVALID_REVISION',
      path: 'revision',
      message: 'La revisión debe ser un entero no negativo.',
    });
  }

  addDuplicateNameIssues(project.classes, 'classes', issues);
  addDuplicateNameIssues(project.enumerations, 'enumerations', issues);
  addDuplicateNameIssues(
    [...project.classes, ...project.enumerations],
    'types',
    issues,
  );

  const classIds = new Set(project.classes.map((item) => item.id));
  const enumNames = new Set(project.enumerations.map((item) => item.name));

  project.classes.forEach((umlClass, classIndex) => {
    const classPath = `classes[${classIndex}]`;
    validateId(umlClass.id, `${classPath}.id`, seenIds, issues);
    if (!umlClass.name.trim()) {
      issues.push({ code: 'EMPTY_NAME', path: `${classPath}.name`, message: 'La clase debe tener nombre.' });
    }
    if (!Number.isFinite(umlClass.position.x) || !Number.isFinite(umlClass.position.y)) {
      issues.push({
        code: 'INVALID_POSITION',
        path: `${classPath}.position`,
        message: 'La posición debe contener coordenadas finitas.',
      });
    }
    addDuplicateNameIssues(umlClass.attributes, `${classPath}.attributes`, issues);

    umlClass.attributes.forEach((attribute, attributeIndex) => {
      const attributePath = `${classPath}.attributes[${attributeIndex}]`;
      validateId(attribute.id, `${attributePath}.id`, seenIds, issues);
      if (!attribute.name.trim()) {
        issues.push({
          code: 'EMPTY_NAME',
          path: `${attributePath}.name`,
          message: 'El atributo debe tener nombre.',
        });
      }
      if (
        !(BUILT_IN_DATA_TYPES as readonly string[]).includes(attribute.dataType) &&
        !enumNames.has(attribute.dataType)
      ) {
        issues.push({
          code: 'UNKNOWN_DATA_TYPE',
          path: `${attributePath}.dataType`,
          message: `El tipo '${attribute.dataType}' no es un tipo incorporado ni una enumeración.`,
        });
      }
      if (attribute.primaryKey && attribute.nullable) {
        issues.push({
          code: 'NULLABLE_PRIMARY_KEY',
          path: `${attributePath}.nullable`,
          message: 'Una clave primaria no puede ser nullable.',
        });
      }
    });
  });

  project.enumerations.forEach((enumeration, enumIndex) => {
    const enumPath = `enumerations[${enumIndex}]`;
    validateId(enumeration.id, `${enumPath}.id`, seenIds, issues);
    if (!enumeration.name.trim()) {
      issues.push({ code: 'EMPTY_NAME', path: `${enumPath}.name`, message: 'La enumeración debe tener nombre.' });
    }
    if (enumeration.values.length === 0) {
      issues.push({
        code: 'EMPTY_ENUMERATION',
        path: `${enumPath}.values`,
        message: 'La enumeración debe definir al menos un valor.',
      });
    }
    addDuplicateNameIssues(
      enumeration.values.map((name) => ({ name })),
      `${enumPath}.values`,
      issues,
    );
    enumeration.values.forEach((value, valueIndex) => {
      if (!value.trim()) {
        issues.push({
          code: 'EMPTY_ENUM_VALUE',
          path: `${enumPath}.values[${valueIndex}]`,
          message: 'Los valores de una enumeración no pueden estar vacíos.',
        });
      }
    });
  });

  project.relationships.forEach((relationship, relationshipIndex) => {
    const relationshipPath = `relationships[${relationshipIndex}]`;
    validateId(relationship.id, `${relationshipPath}.id`, seenIds, issues);
    if (!(RELATIONSHIP_TYPES as readonly string[]).includes(relationship.type)) {
      issues.push({
        code: 'INVALID_RELATIONSHIP_TYPE',
        path: `${relationshipPath}.type`,
        message: `El tipo de relación '${relationship.type}' no está soportado.`,
      });
    }
    if (!classIds.has(relationship.sourceClassId)) {
      issues.push({
        code: 'MISSING_SOURCE_CLASS',
        path: `${relationshipPath}.sourceClassId`,
        message: `No existe la clase origen '${relationship.sourceClassId}'.`,
      });
    }
    if (!classIds.has(relationship.targetClassId)) {
      issues.push({
        code: 'MISSING_TARGET_CLASS',
        path: `${relationshipPath}.targetClassId`,
        message: `No existe la clase destino '${relationship.targetClassId}'.`,
      });
    }
    if (!(MULTIPLICITIES as readonly string[]).includes(relationship.sourceMultiplicity)) {
      issues.push({
        code: 'INVALID_MULTIPLICITY',
        path: `${relationshipPath}.sourceMultiplicity`,
        message: `La multiplicidad '${relationship.sourceMultiplicity}' no está soportada.`,
      });
    }
    if (!(MULTIPLICITIES as readonly string[]).includes(relationship.targetMultiplicity)) {
      issues.push({
        code: 'INVALID_MULTIPLICITY',
        path: `${relationshipPath}.targetMultiplicity`,
        message: `La multiplicidad '${relationship.targetMultiplicity}' no está soportada.`,
      });
    }
    if (
      relationship.type === 'GENERALIZATION' &&
      relationship.sourceClassId === relationship.targetClassId
    ) {
      issues.push({
        code: 'SELF_GENERALIZATION',
        path: relationshipPath,
        message: 'Una clase no puede generalizarse a sí misma.',
      });
    }
  });

  issues.push(...detectGeneralizationCycles(project));
  return { valid: issues.length === 0, issues };
}

