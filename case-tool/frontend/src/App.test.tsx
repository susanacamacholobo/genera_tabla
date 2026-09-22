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

afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });

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

it('imports an Enterprise Architect XMI and offers the reverse export', async () => {
  const model: ProjectModel = {
    id: 'from-ea', name: 'Biblioteca EA', revision: 0,
    classes: [], relationships: [], enumerations: [],
  };
  const fetchMock = vi.fn((url: string, options?: RequestInit) => {
    if (url === '/ai/status') return Promise.resolve({ ok: true, json: async () => ({ configured: false, remote: false }) });
    if (url === '/projects' && !options) return Promise.resolve({ ok: true, json: async () => [] });
    if (url === '/projects/xmi/import' && options?.method === 'POST') {
      expect(options.body).toBeInstanceOf(FormData);
      expect((options.body as FormData).get('file')).toBeInstanceOf(File);
      return Promise.resolve({ ok: true, json: async () => ({ project_id: 'from-ea', model }) });
    }
    if (url === '/projects/from-ea/model') return Promise.resolve({ ok: true, json: async () => ({ model }) });
    throw new Error(`Unexpected ${url}`);
  });
  vi.stubGlobal('fetch', fetchMock);
  const user = userEvent.setup();
  render(<App />);
  await screen.findByText('Crea un proyecto para comenzar a editar.');

  const file = new File(['<xmi:XMI />'], 'biblioteca.xmi', { type: 'application/xml' });
  await user.upload(screen.getByLabelText('Archivo XMI de Enterprise Architect'), file);
  await user.click(screen.getByRole('button', { name: 'Importar XMI' }));

  expect((await screen.findByTestId('editor')).textContent).toContain('Biblioteca EA / guardado');
  expect(screen.getByRole('link', { name: 'Exportar XMI' }).getAttribute('href')).toBe('/projects/from-ea/xmi');
});

it('downloads the Spring ZIP for the selected persisted project', async () => {
  const model: ProjectModel = { id: 'p1', name: 'Veterinaria', revision: 0, classes: [], relationships: [], enumerations: [] };
  const fetchMock = vi.fn((url: string) => {
    if (url === '/ai/status') return Promise.resolve({ ok: true, json: async () => ({ configured: false, remote: false }) });
    if (url === '/projects') return Promise.resolve({ ok: true, json: async () => [{ id: 'p1', name: 'Veterinaria' }] });
    if (url === '/projects/p1/model') return Promise.resolve({ ok: true, json: async () => ({ model }) });
    if (url === '/projects/p1/spring.zip') return Promise.resolve({ ok: true, blob: async () => new Blob(['zip']) });
    throw new Error(`Unexpected ${url}`);
  });
  vi.stubGlobal('fetch', fetchMock);
  const createObjectURL = vi.fn(() => 'blob:backend');
  const revokeObjectURL = vi.fn();
  vi.stubGlobal('URL', class extends URL {
    static createObjectURL = createObjectURL;
    static revokeObjectURL = revokeObjectURL;
  });
  const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
  const user = userEvent.setup();
  render(<App />);
  await screen.findByTestId('editor');

  await user.click(screen.getByRole('button', { name: 'Generar backend ZIP' }));

  await waitFor(() => expect(click).toHaveBeenCalledOnce());
  expect(fetchMock).toHaveBeenCalledWith('/projects/p1/spring.zip');
  expect(createObjectURL).toHaveBeenCalledOnce();
  expect(revokeObjectURL).toHaveBeenCalledWith('blob:backend');
});

it('shows generation validation issues without downloading', async () => {
  const model: ProjectModel = { id: 'p1', name: 'Incompleto', revision: 0, classes: [], relationships: [], enumerations: [] };
  const fetchMock = vi.fn((url: string) => {
    if (url === '/ai/status') return Promise.resolve({ ok: true, json: async () => ({ configured: false, remote: false }) });
    if (url === '/projects') return Promise.resolve({ ok: true, json: async () => [{ id: 'p1', name: 'Incompleto' }] });
    if (url === '/projects/p1/model') return Promise.resolve({ ok: true, json: async () => ({ model }) });
    if (url === '/projects/p1/spring.zip') return Promise.resolve({ ok: false, json: async () => ({
      detail: [{ path: 'classes', message: 'Agrega al menos una clase antes de generar.' }],
    }) });
    throw new Error(`Unexpected ${url}`);
  });
  vi.stubGlobal('fetch', fetchMock);
  const user = userEvent.setup();
  render(<App />);
  await screen.findByTestId('editor');

  await user.click(screen.getByRole('button', { name: 'Generar backend ZIP' }));

  expect(await screen.findByRole('alert')).toHaveProperty('textContent', 'classes: Agrega al menos una clase antes de generar.');
});
