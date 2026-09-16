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
const RENAME_CLASS = /^(?:renombra|renombrar)\s+(?:la\s+)?clase\s+(.+?)\s+(?:a|por)\s+(.+)$/iu;
const RENAME_ATTRIBUTE = /^(?:renombra|renombrar)\s+(?:el\s+)?atributo\s+(.+?)\s+(?:de|en)\s+(?:la\s+)?(?:clase\s+)?(.+?)\s+(?:a|por)\s+(.+)$/iu;
const CHANGE_ATTRIBUTE_TYPE = /^(?:cambia|cambiar|modifica|modificar)\s+(?:el\s+)?tipo\s+(?:del?\s+)?atributo\s+(.+?)\s+(?:de|en)\s+(?:la\s+)?(?:clase\s+)?(.+?)\s+(?:a|por)\s+(\S+)$/iu;
const DELETE_ATTRIBUTE = /^(?:elimina|eliminar|borra|borrar)\s+(?:el\s+)?atributo\s+(.+?)\s+(?:de|en)\s+(?:la\s+)?(?:clase\s+)?(.+)$/iu;
const CARDINALITY = '(uno a uno|uno a muchos|muchos a uno|muchos a muchos)';
const ADD_RELATIONSHIP = new RegExp(`^(?:relaciona|relacionar|conecta|conectar)\\s+(.+?)\\s+con\\s+(.+?)\\s+${CARDINALITY}$`, 'iu');
const CHANGE_RELATIONSHIP = new RegExp(`^(?:cambia|cambiar|modifica|modificar)\\s+(?:la\\s+)?multiplicidad\\s+de\\s+(.+?)\\s+con\\s+(.+?)\\s+a\\s+${CARDINALITY}$`, 'iu');
const CHANGE_RELATIONSHIP_END = /^(?:cambia|cambiar|modifica|modificar)\s+(?:el\s+)?(origen|destino)\s+de\s+(?:la\s+)?relaci[oó]n\s+(.+?)\s+con\s+(.+?)\s+a\s+(.+)$/iu;
const CHANGE_RELATIONSHIP_TYPE = /^(?:cambia|cambiar|modifica|modificar)\s+(?:el\s+)?tipo\s+de\s+(?:la\s+)?relaci[oó]n\s+(.+?)\s+con\s+(.+?)\s+a\s+(asociaci[oó]n|generalizaci[oó]n)$/iu;
const DELETE_RELATIONSHIP = /^(?:elimina|eliminar|borra|borrar)\s+(?:la\s+)?relaci[oó]n\s+(?:de|entre)\s+(.+?)\s+con\s+(.+)$/iu;

const multiplicities = {
  'uno a uno': ['1', '1'],
  'uno a muchos': ['1', '0..*'],
  'muchos a uno': ['0..*', '1'],
  'muchos a muchos': ['0..*', '0..*'],
} as const;

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

    const renameClassMatch = text.match(RENAME_CLASS);
    if (renameClassMatch) return this.renameClass(renameClassMatch[1] ?? '', renameClassMatch[2] ?? '', project);

    const renameAttributeMatch = text.match(RENAME_ATTRIBUTE);
    if (renameAttributeMatch) return this.updateAttribute(renameAttributeMatch[1] ?? '', renameAttributeMatch[2] ?? '', { name: cleanName(renameAttributeMatch[3] ?? '') }, project);

    const changeAttributeTypeMatch = text.match(CHANGE_ATTRIBUTE_TYPE);
    if (changeAttributeTypeMatch) return this.updateAttribute(changeAttributeTypeMatch[1] ?? '', changeAttributeTypeMatch[2] ?? '', { dataType: this.canonicalDataType(changeAttributeTypeMatch[3] ?? '', project) }, project);

    const deleteAttributeMatch = text.match(DELETE_ATTRIBUTE);
    if (deleteAttributeMatch) return this.deleteAttribute(deleteAttributeMatch[1] ?? '', deleteAttributeMatch[2] ?? '', project);

    const addRelationshipMatch = text.match(ADD_RELATIONSHIP);
    if (addRelationshipMatch) return this.addRelationship(addRelationshipMatch[1] ?? '', addRelationshipMatch[2] ?? '', addRelationshipMatch[3] ?? '', project);

    const changeRelationshipMatch = text.match(CHANGE_RELATIONSHIP);
    if (changeRelationshipMatch) return this.changeRelationship(changeRelationshipMatch[1] ?? '', changeRelationshipMatch[2] ?? '', changeRelationshipMatch[3] ?? '', project);

    const changeRelationshipEndMatch = text.match(CHANGE_RELATIONSHIP_END);
    if (changeRelationshipEndMatch) return this.changeRelationshipEnd(changeRelationshipEndMatch[1] ?? '', changeRelationshipEndMatch[2] ?? '', changeRelationshipEndMatch[3] ?? '', changeRelationshipEndMatch[4] ?? '', project);

    const changeRelationshipTypeMatch = text.match(CHANGE_RELATIONSHIP_TYPE);
    if (changeRelationshipTypeMatch) return this.changeRelationshipType(changeRelationshipTypeMatch[1] ?? '', changeRelationshipTypeMatch[2] ?? '', changeRelationshipTypeMatch[3] ?? '', project);

    const deleteRelationshipMatch = text.match(DELETE_RELATIONSHIP);
    if (deleteRelationshipMatch) return this.deleteRelationship(deleteRelationshipMatch[1] ?? '', deleteRelationshipMatch[2] ?? '', project);

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

  private renameClass(rawName: string, rawNewName: string, project: ProjectModel): CommandParseResult {
    const name = cleanName(rawNewName);
    if (!name) return invalidName();
    const target = this.findClass(rawName, project);
    if (!target) return this.classNotFound(cleanName(rawName));
    return { ok: true, command: { id: this.createId(), type: 'RENAME_CLASS', targetId: target.id, payload: { name } } };
  }

  private updateAttribute(rawName: string, rawClass: string, payload: { name?: string; dataType?: DataType }, project: ProjectModel): CommandParseResult {
    const owner = this.findClass(rawClass, project);
    if (!owner) return this.classNotFound(cleanName(rawClass));
    const attribute = owner.attributes.find((item) => normalized(item.name) === normalized(cleanName(rawName)));
    if (!attribute) return this.attributeNotFound(cleanName(rawName), owner.name);
    if ((payload.name !== undefined && !payload.name) || (payload.dataType !== undefined && !payload.dataType)) return invalidName();
    return { ok: true, command: { id: this.createId(), type: 'UPDATE_ATTRIBUTE', targetId: attribute.id, payload } };
  }

  private deleteAttribute(rawName: string, rawClass: string, project: ProjectModel): CommandParseResult {
    const owner = this.findClass(rawClass, project);
    if (!owner) return this.classNotFound(cleanName(rawClass));
    const attribute = owner.attributes.find((item) => normalized(item.name) === normalized(cleanName(rawName)));
    if (!attribute) return this.attributeNotFound(cleanName(rawName), owner.name);
    return { ok: true, command: { id: this.createId(), type: 'DELETE_ATTRIBUTE', targetId: attribute.id, payload: {} } };
  }

  private addRelationship(rawSource: string, rawTarget: string, rawCardinality: string, project: ProjectModel): CommandParseResult {
    const source = this.findClass(rawSource, project);
    const target = this.findClass(rawTarget, project);
    if (!source) return this.classNotFound(cleanName(rawSource));
    if (!target) return this.classNotFound(cleanName(rawTarget));
    const [sourceMultiplicity, targetMultiplicity] = multiplicities[normalized(rawCardinality) as keyof typeof multiplicities];
    return { ok: true, command: {
      id: this.createId(), type: 'ADD_RELATIONSHIP', payload: {
        id: this.createId(), type: 'ASSOCIATION', sourceClassId: source.id,
        targetClassId: target.id, sourceMultiplicity, targetMultiplicity,
      },
    } };
  }

  private changeRelationship(rawSource: string, rawTarget: string, rawCardinality: string, project: ProjectModel): CommandParseResult {
    const match = this.findRelationship(rawSource, rawTarget, project);
    if (!match.ok) return match;
    const [sourceMultiplicity, targetMultiplicity] = multiplicities[normalized(rawCardinality) as keyof typeof multiplicities];
    return { ok: true, command: {
      id: this.createId(), type: 'UPDATE_RELATIONSHIP', targetId: match.id,
      payload: { sourceMultiplicity, targetMultiplicity },
    } };
  }

  private changeRelationshipEnd(rawEnd: string, rawSource: string, rawTarget: string, rawNewClass: string, project: ProjectModel): CommandParseResult {
    const match = this.findRelationship(rawSource, rawTarget, project);
    if (!match.ok) return match;
    const nextClass = this.findClass(rawNewClass, project);
    if (!nextClass) return this.classNotFound(cleanName(rawNewClass));
    const payload = normalized(rawEnd) === 'origen'
      ? { sourceClassId: nextClass.id } : { targetClassId: nextClass.id };
    return { ok: true, command: { id: this.createId(), type: 'UPDATE_RELATIONSHIP', targetId: match.id, payload } };
  }

  private changeRelationshipType(rawSource: string, rawTarget: string, rawType: string, project: ProjectModel): CommandParseResult {
    const match = this.findRelationship(rawSource, rawTarget, project);
    if (!match.ok) return match;
    const type = /^generalizaci[oó]n$/iu.test(rawType) ? 'GENERALIZATION' : 'ASSOCIATION';
    return { ok: true, command: { id: this.createId(), type: 'UPDATE_RELATIONSHIP', targetId: match.id, payload: { type } } };
  }

  private deleteRelationship(rawSource: string, rawTarget: string, project: ProjectModel): CommandParseResult {
    const match = this.findRelationship(rawSource, rawTarget, project);
    if (!match.ok) return match;
    return { ok: true, command: { id: this.createId(), type: 'DELETE_RELATIONSHIP', targetId: match.id, payload: {} } };
  }

  private findRelationship(rawSource: string, rawTarget: string, project: ProjectModel): { ok: true; id: string } | { ok: false; error: { code: 'CLASS_NOT_FOUND' | 'AMBIGUOUS_TARGET'; message: string } } {
    const source = this.findClass(rawSource, project);
    const target = this.findClass(rawTarget, project);
    if (!source) return { ok: false, error: { code: 'CLASS_NOT_FOUND', message: `No existe la clase «${cleanName(rawSource)}».` } };
    if (!target) return { ok: false, error: { code: 'CLASS_NOT_FOUND', message: `No existe la clase «${cleanName(rawTarget)}».` } };
    const matches = project.relationships.filter((item) => item.sourceClassId === source.id && item.targetClassId === target.id);
    if (matches.length !== 1) return { ok: false, error: { code: 'AMBIGUOUS_TARGET', message: matches.length === 0 ? 'No existe esa relación.' : 'Hay varias relaciones entre esas clases; selecciona una en el diagrama.' } };
    return { ok: true, id: matches[0]!.id };
  }

  private findClass(name: string, project: ProjectModel) {
    return project.classes.find((item) => normalized(item.name) === normalized(cleanName(name)));
  }

  private attributeNotFound(name: string, owner: string): CommandParseResult {
    return { ok: false, error: { code: 'CLASS_NOT_FOUND', message: `No existe el atributo «${name}» en «${owner}».` } };
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

    const owner = this.findClass(className, project);
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

    const target = this.findClass(className, project);
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
