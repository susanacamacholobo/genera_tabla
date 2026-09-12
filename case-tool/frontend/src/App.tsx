import type { ProjectModel } from './domain';
import veterinariaFixture from '../../../docs/examples/veterinaria.json';
import { DiagramEditor } from './features/diagram';

export function App() {
  return <DiagramEditor initialProject={veterinariaFixture as ProjectModel} />;
}
