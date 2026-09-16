import { useCallback, useEffect, useRef, useState } from 'react';
import {
  CommandHistory,
  CommandValidationError,
  randomId,
  type Command,
  type ProjectModel,
} from '../../../domain';
import { ProjectSession, type SessionStatus, type StoredCommand } from '../collaboration/ProjectSession';

export type DiagramSelection =
  | { kind: 'class'; id: string }
  | { kind: 'relationship'; id: string }
  | null;

export function useDiagramEditor(initialProject: ProjectModel, session?: ProjectSession) {
  const history = useRef<CommandHistory | null>(null);
  if (!history.current) history.current = new CommandHistory(initialProject);

  const [project, setProject] = useState(() => history.current?.state ?? initialProject);
  const [selection, setSelection] = useState<DiagramSelection>(null);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<SessionStatus>(session ? 'connecting' : 'connected');
  const [pending, setPending] = useState(false);
  const statusRef = useRef<SessionStatus>(session ? 'connecting' : 'connected');
  const pendingId = useRef<string | null>(null);

  useEffect(() => {
    if (!session) return;
    session.start({
      onSnapshot: (snapshot, commandId) => {
        if (commandId && commandId === pendingId.current &&
          JSON.stringify(snapshot) === JSON.stringify(history.current?.state)) {
          pendingId.current = null;
          setPending(false);
          setError(null);
          return;
        }
        history.current = new CommandHistory(snapshot);
        setProject(snapshot);
        setSelection(null);
        if (!commandId || commandId === pendingId.current) {
          pendingId.current = null;
          setPending(false);
        }
      },
      onRejected: (message) => {
        setError(message);
      },
      onStatus: (next) => {
        statusRef.current = next;
        setStatus(next);
        if (next === 'disconnected') {
          pendingId.current = null;
          setPending(false);
          setError('Conexión perdida. Los cambios se bloquearon hasta volver a sincronizar.');
        }
      },
    });
    return () => session.stop();
  }, [session]);

  const apply = useCallback((command: StoredCommand, change: () => ProjectModel): boolean => {
    if (session && (statusRef.current !== 'connected' || pendingId.current)) {
      setError('Espera a que termine la sincronización del cambio anterior.');
      return false;
    }
    const previous = history.current?.state;
    try {
      const next = change();
      if (session && previous) {
        if (!session.submit(command, previous.revision, next)) {
          history.current = new CommandHistory(previous);
          setError('No se pudo enviar el cambio. Comprueba la conexión.');
          return false;
        }
        pendingId.current = command.id;
        setPending(true);
      }
      setProject(next);
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
  }, [session]);

  const execute = useCallback((command: Command): boolean => {
    return apply(command, () => history.current!.execute(command));
  }, [apply]);

  const undo = useCallback(() => {
    if (!history.current?.canUndo) return;
    if (apply({ id: randomId(), type: 'UNDO', payload: {} }, () => history.current!.undo())) setSelection(null);
  }, [apply]);

  const redo = useCallback(() => {
    if (!history.current?.canRedo) return;
    if (apply({ id: randomId(), type: 'REDO', payload: {} }, () => history.current!.redo())) setSelection(null);
  }, [apply]);

  return {
    project,
    selection,
    error,
    canUndo: history.current.canUndo && !pending && status === 'connected',
    canRedo: history.current.canRedo && !pending && status === 'connected',
    canEdit: !pending && status === 'connected',
    connectionStatus: status,
    pending,
    execute,
    undo,
    redo,
    select: setSelection,
    dismissError: () => setError(null),
  };
}
