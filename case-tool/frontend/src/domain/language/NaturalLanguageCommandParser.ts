import type { Command } from '../commands/types';
import type { ProjectModel } from '../model/types';

export type CommandParseErrorCode =
  | 'EMPTY_INPUT'
  | 'UNKNOWN_COMMAND'
  | 'INVALID_NAME'
  | 'CLASS_NOT_FOUND'
  | 'INVALID_MODEL_RESPONSE'
  | 'UNSUPPORTED_COMMAND'
  | 'AMBIGUOUS_TARGET'
  | 'MODEL_FAILURE';

export interface CommandParseError {
  code: CommandParseErrorCode;
  message: string;
}

export type CommandParseResult =
  | { ok: true; command: Command; explanation?: string; assumptions?: string[] }
  | { ok: false; error: CommandParseError };

export interface NaturalLanguageCommandParser {
  parse(input: string, project: ProjectModel): Promise<CommandParseResult>;
}
