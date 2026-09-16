// @vitest-environment jsdom

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ProjectModel } from '../../../domain';
import veterinariaFixture from '../../../../../../docs/examples/veterinaria.json';
import { ProjectSession, type ProjectSessionListener } from './ProjectSession';

class FakeWebSocket {
  static OPEN = 1;
  static instances: FakeWebSocket[] = [];
  readyState = FakeWebSocket.OPEN;
  onmessage: ((event: MessageEvent<string>) => void) | null = null;
  onclose: (() => void) | null = null;
  onerror: (() => void) | null = null;
  sent: unknown[] = [];

  constructor(readonly url: string) { FakeWebSocket.instances.push(this); }
  send(raw: string) { this.sent.push(JSON.parse(raw)); }
  close() { this.readyState = 3; this.onclose?.(); }
  emit(message: unknown) { this.onmessage?.({ data: JSON.stringify(message) } as MessageEvent<string>); }
}

const fixture = veterinariaFixture as ProjectModel;

beforeEach(() => {
  FakeWebSocket.instances = [];
  vi.stubGlobal('WebSocket', FakeWebSocket);
});
afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('ProjectSession', () => {
  it('waits for ready, submits canonical changes, and receives its own and remote snapshots', () => {
    const listener: ProjectSessionListener = {
      onSnapshot: vi.fn(), onRejected: vi.fn(), onStatus: vi.fn(),
    };
    const session = new ProjectSession(fixture.id);
    session.start(listener);
    const socket = FakeWebSocket.instances[0]!;
    expect(socket.url).toContain(`/ws/projects/${fixture.id}?`);
    const command = { id: 'c1', type: 'ADD_CLASS' as const, payload: { id: 'n1', name: 'Factura' } };
    expect(session.submit(command, fixture.revision, fixture)).toBe(false);

    socket.emit({ type: 'session.ready', model: fixture });
    expect(listener.onStatus).toHaveBeenLastCalledWith('connected');
    expect(session.submit(command, fixture.revision, fixture)).toBe(true);
    expect(socket.sent[0]).toMatchObject({ type: 'change.submit', baseRevision: fixture.revision, command });

    socket.emit({ type: 'change.applied', model: fixture, command });
    expect(listener.onSnapshot).toHaveBeenLastCalledWith(fixture, 'c1');
    socket.emit({ type: 'change.applied', model: fixture, command: { id: 'another-tab' } });
    expect(listener.onSnapshot).toHaveBeenLastCalledWith(fixture, 'another-tab');
    session.stop();
  });

  it('refreshes the authoritative model after a conflict', async () => {
    const listener: ProjectSessionListener = {
      onSnapshot: vi.fn(), onRejected: vi.fn(), onStatus: vi.fn(),
    };
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ model: fixture }) });
    vi.stubGlobal('fetch', fetchMock);
    const session = new ProjectSession(fixture.id);
    session.start(listener);
    FakeWebSocket.instances[0]!.emit({ type: 'change.rejected' });
    await vi.waitFor(() => expect(listener.onSnapshot).toHaveBeenCalledWith(fixture));
    expect(listener.onRejected).toHaveBeenCalledOnce();
    expect(fetchMock).toHaveBeenCalledWith(`/projects/${fixture.id}/model`);
    session.stop();
  });
});
