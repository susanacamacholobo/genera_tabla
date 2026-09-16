import { useEffect, useMemo, useState } from 'react';
import type { ProjectModel } from './domain';
import veterinariaFixture from '../../../docs/examples/veterinaria.json';
import { DiagramEditor } from './features/diagram';
import { CaseAIProvider, getCaseAIStatus, type CaseAIStatus } from './features/diagram/ai/CaseAIProvider';

export function App() {
  const [aiStatus, setAIStatus] = useState<CaseAIStatus>({ configured: false, remote: false });
  const aiProvider = useMemo(() => new CaseAIProvider(), []);

  useEffect(() => {
    let active = true;
    getCaseAIStatus().then((status) => {
      if (active) setAIStatus(status);
    }).catch(() => {
      if (active) setAIStatus({ configured: false, remote: false });
    });
    return () => { active = false; };
  }, []);

  return (
    <DiagramEditor
      initialProject={veterinariaFixture as ProjectModel}
      {...(aiStatus.configured ? { aiProvider } : {})}
      aiRemote={aiStatus.remote}
    />
  );
}
