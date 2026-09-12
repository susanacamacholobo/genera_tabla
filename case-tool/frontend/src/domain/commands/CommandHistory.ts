import type { ProjectModel } from '../model/types';
import { CommandExecutor } from './CommandExecutor';
import type { Command } from './types';

export class CommandHistory {
  private currentState: ProjectModel;
  private readonly undoStack: ProjectModel[] = [];
  private readonly redoStack: ProjectModel[] = [];

  constructor(
    initialState: ProjectModel,
    private readonly executor = new CommandExecutor(),
    private readonly capacity = 100,
  ) {
    if (!Number.isSafeInteger(capacity) || capacity < 1) {
      throw new Error('La capacidad del historial debe ser un entero positivo.');
    }
    this.currentState = executor.restore(initialState);
  }

  get state(): ProjectModel {
    return structuredClone(this.currentState);
  }

  get canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  get canRedo(): boolean {
    return this.redoStack.length > 0;
  }

  execute(command: Command): ProjectModel {
    const previous = this.currentState;
    const next = this.executor.execute(previous, command);
    this.undoStack.push(this.executor.restore(previous));
    if (this.undoStack.length > this.capacity) this.undoStack.shift();
    this.redoStack.length = 0;
    this.currentState = next;
    return this.state;
  }

  undo(): ProjectModel {
    const previous = this.undoStack.pop();
    if (!previous) return this.state;
    this.redoStack.push(this.executor.restore(this.currentState));
    this.currentState = this.executor.restoreAsNextRevision(
      previous,
      this.currentState.revision,
    );
    return this.state;
  }

  redo(): ProjectModel {
    const next = this.redoStack.pop();
    if (!next) return this.state;
    this.undoStack.push(this.executor.restore(this.currentState));
    this.currentState = this.executor.restoreAsNextRevision(
      next,
      this.currentState.revision,
    );
    return this.state;
  }

  clear(): void {
    this.undoStack.length = 0;
    this.redoStack.length = 0;
  }
}
