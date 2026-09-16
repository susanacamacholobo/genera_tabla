import { CommandExecutor, randomId, type Command, type ProjectModel } from '../../../domain';

export type SessionStatus = 'connecting' | 'connected' | 'disconnected';
export type StoredCommand = Command | { id: string; type: 'UNDO' | 'REDO'; payload: Record<string, never> };

export interface ProjectSessionListener {
  onSnapshot(project: ProjectModel, commandId?: string): void;
  onRejected(message: string): void;
  onStatus(status: SessionStatus): void;
}

function validModel(value: unknown, projectId: string): ProjectModel | null {
  if (!value || typeof value !== 'object' || !('id' in value) || value.id !== projectId) return null;
  try {
    return new CommandExecutor().restore(value as ProjectModel);
  } catch {
    return null;
  }
}

export class ProjectSession {
  private socket: WebSocket | null = null;
  private listener: ProjectSessionListener | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private stopped = false;
  private ready = false;
  private readonly userId = randomId();

  constructor(private readonly projectId: string) {}

  start(listener: ProjectSessionListener): void {
    this.listener = listener;
    this.stopped = false;
    this.connect();
  }

  stop(): void {
    this.stopped = true;
    this.ready = false;
    this.listener = null;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.socket?.close();
    this.socket = null;
  }

  submit(command: StoredCommand, baseRevision: number, model: ProjectModel): boolean {
    if (!this.ready || this.socket?.readyState !== WebSocket.OPEN) return false;
    try {
      this.socket.send(JSON.stringify({ type: 'change.submit', baseRevision, command, model }));
      return true;
    } catch {
      return false;
    }
  }

  async refresh(): Promise<void> {
    try {
      const response = await fetch(`/projects/${encodeURIComponent(this.projectId)}/model`);
      if (!response.ok) throw new Error('No se pudo cargar el proyecto.');
      const body: unknown = await response.json();
      const model = body && typeof body === 'object' && 'model' in body
        ? validModel(body.model, this.projectId) : null;
      if (!model) throw new Error('El servidor devolvió un modelo inválido.');
      this.listener?.onSnapshot(model);
    } catch {
      this.listener?.onRejected('No se pudo recuperar la última revisión. Espera la reconexión.');
    }
  }

  private connect(): void {
    if (this.stopped) return;
    this.ready = false;
    this.listener?.onStatus('connecting');
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const query = new URLSearchParams({ userId: this.userId, displayName: 'Editor web' });
    const socket = new WebSocket(`${protocol}//${window.location.host}/ws/projects/${encodeURIComponent(this.projectId)}?${query}`);
    this.socket = socket;

    socket.onmessage = (event: MessageEvent<string>) => {
      let message: unknown;
      try { message = JSON.parse(event.data); } catch { return; }
      if (!message || typeof message !== 'object' || !('type' in message)) return;
      if (message.type === 'session.ready' && 'model' in message) {
        const model = validModel(message.model, this.projectId);
        if (!model) return;
        this.ready = true;
        this.listener?.onSnapshot(model);
        this.listener?.onStatus('connected');
      } else if (message.type === 'change.applied' && 'model' in message && 'command' in message) {
        const model = validModel(message.model, this.projectId);
        const command = message.command;
        const commandId = command && typeof command === 'object' && 'id' in command && typeof command.id === 'string'
          ? command.id : undefined;
        if (model) this.listener?.onSnapshot(model, commandId);
      } else if (message.type === 'change.rejected') {
        this.listener?.onRejected('El cambio entró en conflicto o fue rechazado. Se cargará la última revisión.');
        void this.refresh();
      } else if (message.type === 'protocol.error') {
        this.listener?.onRejected('El servidor rechazó el mensaje de colaboración.');
        void this.refresh();
      }
    };

    socket.onclose = () => {
      if (this.stopped || this.socket !== socket) return;
      this.ready = false;
      this.listener?.onStatus('disconnected');
      this.reconnectTimer = setTimeout(() => this.connect(), 2000);
    };
    socket.onerror = () => socket.close();
  }
}
