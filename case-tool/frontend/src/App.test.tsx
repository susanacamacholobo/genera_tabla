// @vitest-environment jsdom

import { cleanup, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, expect, it, vi } from 'vitest';
import type { ProjectModel } from './domain';
import { App } from './App';

vi.mock('./features/diagram', () => ({
  DiagramEditor: ({ initialProject, session }: { initialProject: ProjectModel; session?: unknown }) => (
    <div data-testid="editor">{initialProject.name} / {session ? 'guardado' : 'demo'}</div>
  ),
}));

afterEach(() => { cleanup(); vi.unstubAllGlobals(); });

it('creates and loads a persisted project before showing the editor', async () => {
  const fetchMock = vi.fn((url: string, options?: RequestInit) => {
    if (url === '/ai/status') return Promise.resolve({ ok: true, json: async () => ({ configured: false, remote: false }) });
    if (url === '/projects' && !options) return Promise.resolve({ ok: true, json: async () => [] });
    if (url === '/projects' && options?.method === 'POST') return Promise.resolve({ ok: true, json: async () => ({ id: 'p1', name: 'Ventas' }) });
    if (url === '/projects/p1/model') return Promise.resolve({ ok: true, json: async () => ({ model: {
      id: 'p1', name: 'Ventas', revision: 0, classes: [], relationships: [], enumerations: [],
    } }) });
    throw new Error(`Unexpected ${url}`);
  });
  vi.stubGlobal('fetch', fetchMock);
  const user = userEvent.setup();
  render(<App />);
  await screen.findByText('Crea un proyecto para comenzar a editar.');
  await user.type(screen.getByRole('textbox', { name: 'Nombre del nuevo proyecto' }), 'Ventas');
  await user.click(screen.getByRole('button', { name: 'Crear proyecto' }));
  expect((await screen.findByTestId('editor')).textContent).toContain('Ventas / guardado');
  expect(fetchMock).toHaveBeenCalledWith('/projects', expect.objectContaining({ method: 'POST' }));
});

it('labels the local fixture as unsaved demo when the backend is unavailable', async () => {
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('offline')));
  render(<App />);
  expect((await screen.findByTestId('editor')).textContent).toContain('Veterinaria / demo');
  await waitFor(() => expect(screen.getByText(/sin guardar cambios/)).toBeTruthy());
});
