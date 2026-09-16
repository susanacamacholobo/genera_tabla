import type { Command } from '../commands/types';
import { randomId, type IdGenerator } from '../model/factories';
import {
  BUILT_IN_DATA_TYPES,
  MULTIPLICITIES,
  RELATIONSHIP_TYPES,
  type DataType,
  type JsonScalar,
  type Multiplicity,
  type ProjectModel,
  type RelationshipType,
} from '../model/types';
import type {
  CommandParseResult,
  NaturalLanguageCommandParser,
} from './NaturalLanguageCommandParser';

export interface LocalLLMProvider {
  generate(prompt: string): Promise<string>;
}

type JsonObject = Record<string, unknown>;

function isObject(value: unknown): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function normalized(value: string): string {
  return value.trim().replace(/\s+/gu, ' ').toLocaleLowerCase('es');
}

function cleanName(value: string): string {
  return value.trim().replace(/\s+/gu, ' ');
}

function stringProperty(object: JsonObject, property: string): string | undefined {
  const value = object[property];
  return typeof value === 'string' ? cleanName(value) : undefined;
}

function optionalBoolean(
  object: JsonObject,
  property: string,
): { valid: boolean; value?: boolean } {
  const value = object[property];
  if (value === undefined) return { valid: true };
  return typeof value === 'boolean' ? { valid: true, value } : { valid: false };
}

function optionalScalar(
  object: JsonObject,
  property: string,
): { valid: boolean; value?: JsonScalar } {
  const value = object[property];
  if (value === undefined) return { valid: true };
  if (value === null || ['string', 'number', 'boolean'].includes(typeof value)) {
    return { valid: true, value: value as JsonScalar };
  }
  return { valid: false };
}

function nextClassPosition(project: ProjectModel): { x: number; y: number } {
  const index = project.classes.length;
  return {
    x: 100 + (index % 3) * 300,
    y: 100 + Math.floor(index / 3) * 240,
  };
}

function parseFailure(message: string): CommandParseResult {
  return {
    ok: false,
    error: { code: 'INVALID_MODEL_RESPONSE', message },
  };
}

export class LocalLLMCommandParser implements NaturalLanguageCommandParser {
  constructor(
    private readonly provider: LocalLLMProvider,
    private readonly createId: IdGenerator = randomId,
  ) {}

  async parse(input: string, project: ProjectModel): Promise<CommandParseResult> {
    const text = input.trim();
    if (!text) {
      return {
        ok: false,
        error: { code: 'EMPTY_INPUT', message: 'Escribe un comando.' },
      };
    }

    let response: string;
    try {
      response = await this.provider.generate(this.buildPrompt(text, project));
    } catch {
      return {
        ok: false,
        error: {
          code: 'MODEL_FAILURE',
          message: 'La IA no pudo interpretar el comando.',
        },
      };
    }

    return this.decode(response, project);
  }

  private buildPrompt(input: string, project: ProjectModel): string {
    const context = {
      project: project.name,
      classes: project.classes.map((umlClass) => ({
        name: umlClass.name,
        attributes: umlClass.attributes.map((attribute) => ({
          name: attribute.name,
          dataType: attribute.dataType,
        })),
      })),
      enumerations: project.enumerations.map((enumeration) => enumeration.name),
      relationships: project.relationships.map((relationship) => ({
        sourceName: project.classes.find((item) => item.id === relationship.sourceClassId)?.name,
        targetName: project.classes.find((item) => item.id === relationship.targetClassId)?.name,
        type: relationship.type,
        sourceMultiplicity: relationship.sourceMultiplicity,
        targetMultiplicity: relationship.targetMultiplicity,
      })),
      builtInDataTypes: BUILT_IN_DATA_TYPES,
    };

    return [
      'Convierte una instrucción de edición UML en JSON.',
      'Responde exclusivamente con un objeto JSON válido, sin Markdown ni explicaciones.',
      'Devuelve exactamente una acción dentro de "actions".',
      'Si el usuario pide una sugerencia, propone sólo una mejora concreta en actions y explica el motivo en "explanation" y tus suposiciones en "assumptions".',
      'Si la solicitud es ambigua, devuelve {"actions":[],"clarification":"Pregunta concreta para el usuario"}.',
      'Acciones permitidas:',
      '{"actions":[{"type":"ADD_CLASS","payload":{"name":"Nombre"}}]}',
      '{"actions":[{"type":"ADD_ATTRIBUTE","targetName":"Clase","payload":{"name":"atributo","dataType":"String","nullable":true,"unique":false,"primaryKey":false}}]}',
      '{"actions":[{"type":"DELETE_CLASS","targetName":"Clase","payload":{}}]}',
      '{"actions":[{"type":"RENAME_CLASS","targetName":"Clase","payload":{"name":"Nuevo nombre"}}]}',
      '{"actions":[{"type":"UPDATE_ATTRIBUTE","targetName":"Clase","attributeName":"atributo","payload":{"name":"nuevoNombre","dataType":"String"}}]}',
      '{"actions":[{"type":"DELETE_ATTRIBUTE","targetName":"Clase","attributeName":"atributo","payload":{}}]}',
      '{"actions":[{"type":"ADD_RELATIONSHIP","sourceName":"Clase A","targetName":"Clase B","payload":{"type":"ASSOCIATION","sourceMultiplicity":"1","targetMultiplicity":"0..*"}}]}',
      '{"actions":[{"type":"UPDATE_RELATIONSHIP","sourceName":"Clase A","targetName":"Clase B","payload":{"sourceMultiplicity":"1","targetMultiplicity":"1..*"}}]}',
      '{"actions":[{"type":"DELETE_RELATIONSHIP","sourceName":"Clase A","targetName":"Clase B","payload":{}}]}',
      'Si faltan clases, extremos, tipos o multiplicidades, no inventes datos: devuelve {"actions":[]} para pedir aclaración.',
      'No generes todo el diagrama ni acciones no solicitadas. Usa una sola acción concreta.',
      'No inventes IDs. Usa nombres presentes en el contexto para los objetivos existentes.',
      `Contexto UML: ${JSON.stringify(context)}`,
      `Instrucción del usuario: ${JSON.stringify(input)}`,
    ].join('\n');
  }

  private decode(response: string, project: ProjectModel): CommandParseResult {
    let root: unknown;
    try {
      root = JSON.parse(response);
    } catch {
      return parseFailure('La IA devolvió una respuesta que no es JSON válido.');
    }

    if (!isObject(root) || !Array.isArray(root.actions)) {
      return parseFailure('La IA debe devolver exactamente una acción.');
    }
    if (root.actions.length === 0) {
      const clarification = stringProperty(root, 'clarification');
      return parseFailure(clarification && clarification.length <= 300
        ? clarification : 'La instrucción necesita más detalles. Especifica la clase, atributo o relación y el cambio deseado.');
    }
    if (root.actions.length !== 1) return parseFailure('La IA debe devolver exactamente una acción.');

    const action = root.actions[0];
    if (!isObject(action) || typeof action.type !== 'string' || !isObject(action.payload)) {
      return parseFailure('La acción generada no cumple el contrato esperado.');
    }

    let result: CommandParseResult;
    switch (action.type) {
      case 'ADD_CLASS':
        result = this.addClass(action.payload, project); break;
      case 'ADD_ATTRIBUTE':
        result = this.addAttribute(action, action.payload, project); break;
      case 'DELETE_CLASS':
        result = this.deleteClass(action, project); break;
      case 'RENAME_CLASS':
        result = this.renameClass(action, action.payload, project); break;
      case 'UPDATE_ATTRIBUTE':
        result = this.updateAttribute(action, action.payload, project); break;
      case 'DELETE_ATTRIBUTE':
        result = this.deleteAttribute(action, project); break;
      case 'ADD_RELATIONSHIP':
        result = this.addRelationship(action, action.payload, project); break;
      case 'UPDATE_RELATIONSHIP':
        result = this.updateRelationship(action, action.payload, project); break;
      case 'DELETE_RELATIONSHIP':
        result = this.deleteRelationship(action, project); break;
      default:
        return {
          ok: false,
          error: {
            code: 'UNSUPPORTED_COMMAND',
            message: `La IA produjo una acción no permitida: ${action.type}.`,
          },
        };
    }
    if (!result.ok) return result;
    const explanation = stringProperty(root, 'explanation');
    const assumptions = Array.isArray(root.assumptions) && root.assumptions.length <= 5
      && root.assumptions.every((item) => typeof item === 'string' && item.trim().length <= 200)
      ? root.assumptions.map((item: string) => item.trim()) : undefined;
    return {
      ...result,
      ...(explanation && explanation.length <= 500 ? { explanation } : {}),
      ...(assumptions ? { assumptions } : {}),
    };
  }

  private addClass(payload: JsonObject, project: ProjectModel): CommandParseResult {
    const name = stringProperty(payload, 'name');
    if (!name) return this.invalidName();

    const command: Command = {
      id: this.createId(),
      type: 'ADD_CLASS',
      payload: {
        id: this.createId(),
        name,
        position: nextClassPosition(project),
      },
    };
    return { ok: true, command };
  }

  private addAttribute(
    action: JsonObject,
    payload: JsonObject,
    project: ProjectModel,
  ): CommandParseResult {
    const targetName = stringProperty(action, 'targetName');
    const name = stringProperty(payload, 'name');
    const dataType = stringProperty(payload, 'dataType');
    if (!targetName || !name || !dataType) {
      return parseFailure('ADD_ATTRIBUTE requiere targetName, name y dataType.');
    }

    const owner = this.findClass(targetName, project);
    if (!owner) return this.classNotFound(targetName);

    const nullable = optionalBoolean(payload, 'nullable');
    const unique = optionalBoolean(payload, 'unique');
    const primaryKey = optionalBoolean(payload, 'primaryKey');
    const defaultValue = optionalScalar(payload, 'defaultValue');
    if (!nullable.valid || !unique.valid || !primaryKey.valid || !defaultValue.valid) {
      return parseFailure('Los modificadores del atributo tienen tipos inválidos.');
    }

    const command: Command = {
      id: this.createId(),
      type: 'ADD_ATTRIBUTE',
      targetId: owner.id,
      payload: {
        id: this.createId(),
        name,
        dataType: this.canonicalDataType(dataType, project),
        ...(nullable.value !== undefined ? { nullable: nullable.value } : {}),
        ...(unique.value !== undefined ? { unique: unique.value } : {}),
        ...(primaryKey.value !== undefined ? { primaryKey: primaryKey.value } : {}),
        ...(defaultValue.value !== undefined ? { defaultValue: defaultValue.value } : {}),
      },
    };
    return { ok: true, command };
  }

  private deleteClass(action: JsonObject, project: ProjectModel): CommandParseResult {
    const targetName = stringProperty(action, 'targetName');
    if (!targetName) return this.invalidName();

    const target = this.findClass(targetName, project);
    if (!target) return this.classNotFound(targetName);

    return {
      ok: true,
      command: {
        id: this.createId(),
        type: 'DELETE_CLASS',
        targetId: target.id,
        payload: {},
      },
    };
  }

  private renameClass(action: JsonObject, payload: JsonObject, project: ProjectModel): CommandParseResult {
    const targetName = stringProperty(action, 'targetName');
    const name = stringProperty(payload, 'name');
    if (!targetName || !name) return parseFailure('RENAME_CLASS requiere targetName y name.');
    const target = this.findClass(targetName, project);
    if (!target) return this.classNotFound(targetName);
    return { ok: true, command: { id: this.createId(), type: 'RENAME_CLASS', targetId: target.id, payload: { name } } };
  }

  private updateAttribute(action: JsonObject, payload: JsonObject, project: ProjectModel): CommandParseResult {
    const target = this.findAttribute(action, project);
    if (!target.ok) return target.result;
    const name = payload.name === undefined ? undefined : stringProperty(payload, 'name');
    const dataType = payload.dataType === undefined ? undefined : stringProperty(payload, 'dataType');
    const nullable = optionalBoolean(payload, 'nullable');
    const unique = optionalBoolean(payload, 'unique');
    const primaryKey = optionalBoolean(payload, 'primaryKey');
    const defaultValue = optionalScalar(payload, 'defaultValue');
    if ((payload.name !== undefined && !name) || (payload.dataType !== undefined && !dataType)
      || !nullable.valid || !unique.valid || !primaryKey.valid || !defaultValue.valid) {
      return parseFailure('Los cambios del atributo son inválidos.');
    }
    const changes = {
      ...(name !== undefined ? { name } : {}),
      ...(dataType !== undefined ? { dataType: this.canonicalDataType(dataType, project) } : {}),
      ...(nullable.value !== undefined ? { nullable: nullable.value } : {}),
      ...(unique.value !== undefined ? { unique: unique.value } : {}),
      ...(primaryKey.value !== undefined ? { primaryKey: primaryKey.value } : {}),
      ...(defaultValue.value !== undefined ? { defaultValue: defaultValue.value } : {}),
    };
    if (Object.keys(changes).length === 0) return parseFailure('UPDATE_ATTRIBUTE no contiene cambios.');
    return { ok: true, command: { id: this.createId(), type: 'UPDATE_ATTRIBUTE', targetId: target.id, payload: changes } };
  }

  private deleteAttribute(action: JsonObject, project: ProjectModel): CommandParseResult {
    const target = this.findAttribute(action, project);
    if (!target.ok) return target.result;
    return { ok: true, command: { id: this.createId(), type: 'DELETE_ATTRIBUTE', targetId: target.id, payload: {} } };
  }

  private addRelationship(action: JsonObject, payload: JsonObject, project: ProjectModel): CommandParseResult {
    const sourceName = stringProperty(action, 'sourceName');
    const targetName = stringProperty(action, 'targetName');
    const type = stringProperty(payload, 'type');
    const sourceMultiplicity = stringProperty(payload, 'sourceMultiplicity');
    const targetMultiplicity = stringProperty(payload, 'targetMultiplicity');
    if (!sourceName || !targetName || !type || !sourceMultiplicity || !targetMultiplicity
      || !RELATIONSHIP_TYPES.includes(type as RelationshipType)
      || !MULTIPLICITIES.includes(sourceMultiplicity as Multiplicity)
      || !MULTIPLICITIES.includes(targetMultiplicity as Multiplicity)) {
      return parseFailure('La relación requiere clases, tipo y multiplicidades válidas.');
    }
    const source = this.findClass(sourceName, project);
    const target = this.findClass(targetName, project);
    if (!source) return this.classNotFound(sourceName);
    if (!target) return this.classNotFound(targetName);
    return { ok: true, command: { id: this.createId(), type: 'ADD_RELATIONSHIP', payload: {
      id: this.createId(), type: type as RelationshipType, sourceClassId: source.id,
      targetClassId: target.id, sourceMultiplicity: sourceMultiplicity as Multiplicity,
      targetMultiplicity: targetMultiplicity as Multiplicity,
    } } };
  }

  private updateRelationship(action: JsonObject, payload: JsonObject, project: ProjectModel): CommandParseResult {
    const target = this.findRelationship(action, project);
    if (!target.ok) return target.result;
    const type = payload.type === undefined ? undefined : stringProperty(payload, 'type');
    const sourceMultiplicity = payload.sourceMultiplicity === undefined ? undefined : stringProperty(payload, 'sourceMultiplicity');
    const targetMultiplicity = payload.targetMultiplicity === undefined ? undefined : stringProperty(payload, 'targetMultiplicity');
    if ((payload.type !== undefined && (!type || !RELATIONSHIP_TYPES.includes(type as RelationshipType)))
      || (payload.sourceMultiplicity !== undefined && (!sourceMultiplicity || !MULTIPLICITIES.includes(sourceMultiplicity as Multiplicity)))
      || (payload.targetMultiplicity !== undefined && (!targetMultiplicity || !MULTIPLICITIES.includes(targetMultiplicity as Multiplicity)))) {
      return parseFailure('Los cambios de la relación son inválidos.');
    }
    const changes = {
      ...(type !== undefined ? { type: type as RelationshipType } : {}),
      ...(sourceMultiplicity !== undefined ? { sourceMultiplicity: sourceMultiplicity as Multiplicity } : {}),
      ...(targetMultiplicity !== undefined ? { targetMultiplicity: targetMultiplicity as Multiplicity } : {}),
    };
    if (Object.keys(changes).length === 0) return parseFailure('UPDATE_RELATIONSHIP no contiene cambios.');
    return { ok: true, command: { id: this.createId(), type: 'UPDATE_RELATIONSHIP', targetId: target.id, payload: changes } };
  }

  private deleteRelationship(action: JsonObject, project: ProjectModel): CommandParseResult {
    const target = this.findRelationship(action, project);
    if (!target.ok) return target.result;
    return { ok: true, command: { id: this.createId(), type: 'DELETE_RELATIONSHIP', targetId: target.id, payload: {} } };
  }

  private findAttribute(action: JsonObject, project: ProjectModel): { ok: true; id: string } | { ok: false; result: CommandParseResult } {
    const targetName = stringProperty(action, 'targetName');
    const attributeName = stringProperty(action, 'attributeName');
    if (!targetName || !attributeName) return { ok: false, result: parseFailure('Se requiere clase y atributo.') };
    const owner = this.findClass(targetName, project);
    if (!owner) return { ok: false, result: this.classNotFound(targetName) };
    const attribute = owner.attributes.find((item) => normalized(item.name) === normalized(attributeName));
    if (!attribute) return { ok: false, result: parseFailure(`No existe el atributo «${attributeName}» en «${owner.name}».`) };
    return { ok: true, id: attribute.id };
  }

  private findRelationship(action: JsonObject, project: ProjectModel): { ok: true; id: string } | { ok: false; result: CommandParseResult } {
    const sourceName = stringProperty(action, 'sourceName');
    const targetName = stringProperty(action, 'targetName');
    if (!sourceName || !targetName) return { ok: false, result: parseFailure('Se requieren ambas clases de la relación.') };
    const source = this.findClass(sourceName, project);
    const target = this.findClass(targetName, project);
    if (!source) return { ok: false, result: this.classNotFound(sourceName) };
    if (!target) return { ok: false, result: this.classNotFound(targetName) };
    const matches = project.relationships.filter((item) => item.sourceClassId === source.id && item.targetClassId === target.id);
    if (matches.length !== 1) return { ok: false, result: parseFailure(matches.length === 0 ? 'No existe esa relación.' : 'Hay varias relaciones entre esas clases; selecciona una en el diagrama.') };
    return { ok: true, id: matches[0]!.id };
  }

  private findClass(name: string, project: ProjectModel) {
    return project.classes.find((item) => normalized(item.name) === normalized(name));
  }

  private canonicalDataType(rawDataType: string, project: ProjectModel): DataType {
    const knownTypes: readonly string[] = [
      ...BUILT_IN_DATA_TYPES,
      ...project.enumerations.map((item) => item.name),
      ...project.classes.map((item) => item.name),
    ];
    return knownTypes.find((item) => normalized(item) === normalized(rawDataType)) ?? rawDataType;
  }

  private invalidName(): CommandParseResult {
    return {
      ok: false,
      error: { code: 'INVALID_NAME', message: 'El nombre no puede estar vacío.' },
    };
  }

  private classNotFound(className: string): CommandParseResult {
    return {
      ok: false,
      error: {
        code: 'CLASS_NOT_FOUND',
        message: `No existe la clase «${className}».`,
      },
    };
  }
}
