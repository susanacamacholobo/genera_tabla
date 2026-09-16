import { useEffect, useMemo, useState } from 'react';
import { CommandExecutor, type ProjectModel } from './domain';
import veterinariaFixture from '../../../docs/examples/veterinaria.json';
import { DiagramEditor } from './features/diagram';
import { CaseAIProvider, getCaseAIStatus, type CaseAIStatus } from './features/diagram/ai/CaseAIProvider';
import { ProjectSession } from './features/diagram/collaboration/ProjectSession';

interface ProjectSummary { id: string; name: string }

export function App() {
  const [aiStatus, setAIStatus] = useState<CaseAIStatus>({ configured: false, remote: false });
  const aiProvider = useMemo(() => new CaseAIProvider(), []);
  const [projects, setProjects] = useState<ProjectSummary[] | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [snapshot, setSnapshot] = useState<ProjectModel | null>(null);
  const [projectName, setProjectName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [offline, setOffline] = useState(false);
  const projectId = snapshot?.id;
  const session = useMemo(() => projectId ? new ProjectSession(projectId) : null, [projectId]);

  useEffect(() => {
    let active = true;
    getCaseAIStatus().then((status) => {
      if (active) setAIStatus(status);
    }).catch(() => {
      if (active) setAIStatus({ configured: false, remote: false });
    });
    return () => { active = false; };
  }, []);

  const loadProjects = async () => {
    try {
      const response = await fetch('/projects');
      if (!response.ok) throw new Error('No se pudo consultar la lista de proyectos.');
      const list = await response.json() as ProjectSummary[];
      setProjects(list);
      setSelectedId((current) => current && list.some((item) => item.id === current) ? current : list[0]?.id ?? null);
      setOffline(false);
      setError(null);
    } catch {
      setOffline(true);
      setError('El backend no está disponible. El ejemplo funciona sin guardar cambios.');
    }
  };

  useEffect(() => { void loadProjects(); }, []);

  useEffect(() => {
    if (!selectedId || offline) return;
    let active = true;
    setSnapshot(null);
    fetch(`/projects/${encodeURIComponent(selectedId)}/model`)
      .then(async (response) => {
        if (!response.ok) throw new Error('No se pudo cargar el proyecto.');
        const body = await response.json() as { model: ProjectModel };
        return new CommandExecutor().restore(body.model);
      })
      .then((model) => { if (active) { setSnapshot(model); setError(null); } })
      .catch(() => { if (active) setError('No se pudo cargar el proyecto seleccionado.'); });
    return () => { active = false; };
  }, [selectedId, offline]);

  const createProject = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const name = projectName.trim();
    if (!name || busy) return;
    setBusy(true);
    try {
      const response = await fetch('/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name }),
      });
      if (!response.ok) throw new Error('No se pudo crear el proyecto.');
      const created = await response.json() as ProjectSummary;
      setProjects((current) => [...(current ?? []), created]);
      setSelectedId(created.id);
      setProjectName('');
      setError(null);
    } catch {
      setError('No se pudo crear el proyecto. Comprueba que PostgreSQL y el backend estén activos.');
    } finally {
      setBusy(false);
    }
  };

  if (offline) return (
    <>
      <div className="project-switcher" role="status">
        <span>{error}</span>
        <button className="button" onClick={() => void loadProjects()}>Reintentar conexión</button>
      </div>
      <DiagramEditor
        initialProject={veterinariaFixture as ProjectModel}
        {...(aiStatus.configured ? { aiProvider } : {})}
        aiRemote={aiStatus.remote}
      />
    </>
  );

  return (
    <>
      <div className="project-switcher">
        <label htmlFor="project-select">Proyecto</label>
        <select
          id="project-select"
          value={selectedId ?? ''}
          onChange={(event) => setSelectedId(event.target.value)}
          disabled={!projects?.length}
        >
          {!projects?.length && <option value="">Sin proyectos</option>}
          {projects?.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
        </select>
        <form onSubmit={(event) => void createProject(event)}>
          <input
            aria-label="Nombre del nuevo proyecto"
            value={projectName}
            onChange={(event) => setProjectName(event.target.value)}
            placeholder="Nuevo proyecto"
            maxLength={200}
          />
          <button className="button" disabled={busy || !projectName.trim()}>Crear proyecto</button>
        </form>
        {error && <span role="alert">{error}</span>}
      </div>
      {snapshot && session
        ? <DiagramEditor
            key={snapshot.id}
            initialProject={snapshot}
            session={session}
            {...(aiStatus.configured ? { aiProvider } : {})}
            aiRemote={aiStatus.remote}
          />
        : <div className="project-empty" role="status">
            {projects === null ? 'Conectando con el backend…' : projects.length === 0 ? 'Crea un proyecto para comenzar a editar.' : 'Cargando proyecto…'}
          </div>}
    </>
  );
}
