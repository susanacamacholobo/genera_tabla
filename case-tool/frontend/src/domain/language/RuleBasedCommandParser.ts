import type { Command } from '../commands/types';
import { BUILT_IN_DATA_TYPES, type DataType, type ProjectModel } from '../model/types';
import { randomId, type IdGenerator } from '../model/factories';
import type {
  CommandParseResult,
  NaturalLanguageCommandParser,
} from './NaturalLanguageCommandParser';

const CREATE_CLASS = /^(?:crea|crear)\s+(?:(?:la|una)\s+)?clase\s+(.+)$/iu;
const ADD_ATTRIBUTE = /^(?:agrega|agregar|añade|añadir)\s+(?:(?:el|un)\s+)?(?:atributo\s+)?(.+?)\s+(\S+)\s+(?:a|en)\s+(?:(?:la)\s+)?(?:clase\s+)?(.+)$/iu;
const DELETE_CLASS = /^(?:elimina|eliminar|borra|borrar)\s+(?:(?:la)\s+)?(?:clase\s+)?(.+)$/iu;

function normalized(value: string): string {
  return value.trim().replace(/\s+/gu, ' ').toLocaleLowerCase('es');
}

function cleanName(value: string): string {
  const compact = value.trim().replace(/\s+/gu, ' ');
  const quoted = compact.match(/^(?:"([^"]+)"|'([^']+)')$/u);
  return (quoted?.[1] ?? quoted?.[2] ?? compact).trim();
}

function invalidName(): CommandParseResult {
  return {
    ok: false,
    error: { code: 'INVALID_NAME', message: 'El nombre no puede estar vacío.' },
  };
}

function nextClassPosition(project: ProjectModel): { x: number; y: number } {
  const index = project.classes.length;
  return {
    x: 100 + (index % 3) * 300,
    y: 100 + Math.floor(index / 3) * 240,
  };
}

export class RuleBasedCommandParser implements NaturalLanguageCommandParser {
  constructor(private readonly createId: IdGenerator = randomId) {}

  async parse(input: string, project: ProjectModel): Promise<CommandParseResult> {
    const text = input.trim().replace(/[.!?]+$/u, '').trim();
    if (!text) {
      return {
        ok: false,
        error: { code: 'EMPTY_INPUT', message: 'Escribe un comando.' },
      };
    }

    const createMatch = text.match(CREATE_CLASS);
    if (createMatch) return this.createClass(createMatch[1] ?? '', project);

    const attributeMatch = text.match(ADD_ATTRIBUTE);
    if (attributeMatch) {
      return this.addAttribute(
        attributeMatch[1] ?? '',
        attributeMatch[2] ?? '',
        attributeMatch[3] ?? '',
        project,
      );
    }

    const deleteMatch = text.match(DELETE_CLASS);
    if (deleteMatch) return this.deleteClass(deleteMatch[1] ?? '', project);

    return {
      ok: false,
      error: {
        code: 'UNKNOWN_COMMAND',
        message: 'No entendí el comando. Prueba «crea clase Cliente», «agrega nombre String a Cliente» o «elimina Cliente».',
      },
    };
  }

  private createClass(rawName: string, project: ProjectModel): CommandParseResult {
    const name = cleanName(rawName);
    if (!name) return invalidName();

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
    rawAttributeName: string,
    rawDataType: string,
    rawClassName: string,
    project: ProjectModel,
  ): CommandParseResult {
    const attributeName = cleanName(rawAttributeName);
    const className = cleanName(rawClassName);
    if (!attributeName || !className) return invalidName();

    const owner = project.classes.find((item) => normalized(item.name) === normalized(className));
    if (!owner) return this.classNotFound(className);

    const command: Command = {
      id: this.createId(),
      type: 'ADD_ATTRIBUTE',
      targetId: owner.id,
      payload: {
        id: this.createId(),
        name: attributeName,
        dataType: this.canonicalDataType(rawDataType, project),
      },
    };
    return { ok: true, command };
  }

  private deleteClass(rawClassName: string, project: ProjectModel): CommandParseResult {
    const className = cleanName(rawClassName);
    if (!className) return invalidName();

    const target = project.classes.find((item) => normalized(item.name) === normalized(className));
    if (!target) return this.classNotFound(className);

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

  private canonicalDataType(rawDataType: string, project: ProjectModel): DataType {
    const requested = cleanName(rawDataType);
    const knownTypes: readonly string[] = [
      ...BUILT_IN_DATA_TYPES,
      ...project.enumerations.map((item) => item.name),
      ...project.classes.map((item) => item.name),
    ];
    return knownTypes.find((item) => normalized(item) === normalized(requested)) ?? requested;
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
