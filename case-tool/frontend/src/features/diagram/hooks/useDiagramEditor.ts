import { useCallback, useRef, useState } from 'react';
import {
  CommandHistory,
  CommandValidationError,
  type Command,
  type ProjectModel,
} from '../../../domain';

export type DiagramSelection =
  | { kind: 'class'; id: string }
  | { kind: 'relationship'; id: string }
  | null;

export function useDiagramEditor(initialProject: ProjectModel) {
  const history = useRef<CommandHistory | null>(null);
  if (!history.current) history.current = new CommandHistory(initialProject);

  const [project, setProject] = useState(() => history.current?.state ?? initialProject);
  const [selection, setSelection] = useState<DiagramSelection>(null);
  const [error, setError] = useState<string | null>(null);

  const execute = useCallback((command: Command): boolean => {
    try {
      const next = history.current?.execute(command);
      if (next) setProject(next);
      setError(null);
      return true;
    } catch (caught) {
      setError(
        caught instanceof CommandValidationError
          ? caught.issues.map((item) => item.message).join(' ')
          : 'No se pudo aplicar el cambio.',
      );
      return false;
    }
  }, []);

  const undo = useCallback(() => {
    const next = history.current?.undo();
    if (next) setProject(next);
    setSelection(null);
    setError(null);
  }, []);

  const redo = useCallback(() => {
    const next = history.current?.redo();
    if (next) setProject(next);
    setSelection(null);
    setError(null);
  }, []);

  return {
    project,
    selection,
    error,
    canUndo: history.current.canUndo,
    canRedo: history.current.canRedo,
    execute,
    undo,
    redo,
    select: setSelection,
    dismissError: () => setError(null),
  };
}

