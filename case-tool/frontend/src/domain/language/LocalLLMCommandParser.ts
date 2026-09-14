import type { Command } from '../commands/types';
import { randomId, type IdGenerator } from '../model/factories';
import {
  BUILT_IN_DATA_TYPES,
  type DataType,
  type JsonScalar,
  type ProjectModel,
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
          message: 'La IA local no pudo interpretar el comando.',
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
      builtInDataTypes: BUILT_IN_DATA_TYPES,
    };

    return [
      'Convierte una instrucción de edición UML en JSON.',
      'Responde exclusivamente con un objeto JSON válido, sin Markdown ni explicaciones.',
      'Devuelve exactamente una acción dentro de "actions".',
      'Acciones permitidas:',
      '{"actions":[{"type":"ADD_CLASS","payload":{"name":"Nombre"}}]}',
      '{"actions":[{"type":"ADD_ATTRIBUTE","targetName":"Clase","payload":{"name":"atributo","dataType":"String","nullable":true,"unique":false,"primaryKey":false}}]}',
      '{"actions":[{"type":"DELETE_CLASS","targetName":"Clase","payload":{}}]}',
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
      return parseFailure('La IA local devolvió una respuesta que no es JSON válido.');
    }

    if (!isObject(root) || !Array.isArray(root.actions) || root.actions.length !== 1) {
      return parseFailure('La IA local debe devolver exactamente una acción.');
    }

    const action = root.actions[0];
    if (!isObject(action) || typeof action.type !== 'string' || !isObject(action.payload)) {
      return parseFailure('La acción generada no cumple el contrato esperado.');
    }

    switch (action.type) {
      case 'ADD_CLASS':
        return this.addClass(action.payload, project);
      case 'ADD_ATTRIBUTE':
        return this.addAttribute(action, action.payload, project);
      case 'DELETE_CLASS':
        return this.deleteClass(action, project);
      default:
        return {
          ok: false,
          error: {
            code: 'UNSUPPORTED_COMMAND',
            message: `La IA local produjo una acción no permitida: ${action.type}.`,
          },
        };
    }
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
