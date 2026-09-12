import { beforeEach, describe, expect, it } from 'vitest';
import { createProject } from '../model/factories';
import type { ProjectModel } from '../model/types';
import { CommandExecutor } from './CommandExecutor';
import { CommandHistory } from './CommandHistory';
import { CommandValidationError } from './CommandValidator';
import type { Command } from './types';

function sequentialIds() {
  let value = 0;
  return () => `generated-${++value}`;
}

function command<T extends Command>(value: T): T {
  return value;
}

describe('CommandExecutor', () => {
  let project: ProjectModel;
  let executor: CommandExecutor;

  beforeEach(() => {
    project = createProject('Veterinaria', () => 'project');
    executor = new CommandExecutor(sequentialIds());
  });

  it('adds, renames and moves a class without mutating prior state', () => {
    const added = executor.execute(project, command({
      id: 'cmd-1',
      type: 'ADD_CLASS',
      payload: { id: 'cliente', name: ' Cliente ', position: { x: 10, y: 20 } },
    }));
    const renamed = executor.execute(added, command({
      id: 'cmd-2', type: 'RENAME_CLASS', targetId: 'cliente', payload: { name: 'Persona' },
    }));
    const moved = executor.execute(renamed, command({
      id: 'cmd-3', type: 'MOVE_CLASS', targetId: 'cliente', payload: { position: { x: 80, y: 90 } },
    }));

    expect(project.classes).toHaveLength(0);
    expect(moved.classes[0]).toMatchObject({ name: 'Persona', position: { x: 80, y: 90 } });
    expect(moved.revision).toBe(3);
  });

  it('consumes one generated ID per accepted creation', () => {
    const ids = sequentialIds();
    const deterministicExecutor = new CommandExecutor(ids);

    const state = deterministicExecutor.execute(project, command({
      id: 'cmd-1', type: 'ADD_CLASS', payload: { name: 'Cliente' },
    }));

    expect(state.classes[0]?.id).toBe('generated-1');
  });

  it('rejects a collision produced by the ID generator', () => {
    const brokenExecutor = new CommandExecutor(() => 'project');

    expect(() => brokenExecutor.execute(project, command({
      id: 'cmd-1', type: 'ADD_CLASS', payload: { name: 'Cliente' },
    }))).toThrow(CommandValidationError);
    expect(project.classes).toEqual([]);
  });

  it('preserves external identity when an imported class is edited', () => {
    project.classes.push({
      id: 'cliente-interno',
      name: 'Cliente',
      position: { x: 10, y: 20 },
      attributes: [],
      externalReferences: [
        {
          source: 'enterprise-architect',
          scope: 'veterinaria-repository',
          guid: '{A1B2C3D4-E5F6-47A8-9012-123456789ABC}',
          xmiId: 'EAID_A1B2C3D4_E5F6_47A8_9012_123456789ABC',
        },
      ],
    });

    const renamed = executor.execute(project, command({
      id: 'cmd-rename',
      type: 'RENAME_CLASS',
      targetId: 'cliente-interno',
      payload: { name: 'ClientePreferente' },
    }));

    expect(renamed.classes[0]?.name).toBe('ClientePreferente');
    expect(renamed.classes[0]?.externalReferences).toEqual(
      project.classes[0]?.externalReferences,
    );
  });

  it('preserves external identities across move and element updates', () => {
    const externalReferences = [
      {
        source: 'enterprise-architect',
        scope: 'veterinaria-repository',
        guid: '{A1B2C3D4-E5F6-47A8-9012-123456789ABC}',
      },
    ];
    project.classes = [
      {
        id: 'cliente',
        name: 'Cliente',
        position: { x: 0, y: 0 },
        externalReferences,
        attributes: [
          {
            id: 'nombre',
            name: 'nombre',
            dataType: 'String',
            nullable: false,
            unique: false,
            primaryKey: false,
            externalReferences,
          },
        ],
      },
      { id: 'mascota', name: 'Mascota', position: { x: 300, y: 0 }, attributes: [] },
    ];
    project.relationships = [
      {
        id: 'cliente-mascota',
        type: 'ASSOCIATION',
        sourceClassId: 'cliente',
        targetClassId: 'mascota',
        sourceMultiplicity: '1',
        targetMultiplicity: '0..*',
        externalReferences,
      },
    ];

    let state = executor.execute(project, command({
      id: 'move', type: 'MOVE_CLASS', targetId: 'cliente', payload: { position: { x: 50, y: 80 } },
    }));
    state = executor.execute(state, command({
      id: 'attribute', type: 'UPDATE_ATTRIBUTE', targetId: 'nombre', payload: { unique: true },
    }));
    state = executor.execute(state, command({
      id: 'relationship', type: 'UPDATE_RELATIONSHIP', targetId: 'cliente-mascota', payload: { targetMultiplicity: '1..*' },
    }));

    expect(state.classes[0]?.externalReferences).toEqual(externalReferences);
    expect(state.classes[0]?.attributes[0]?.externalReferences).toEqual(externalReferences);
    expect(state.relationships[0]?.externalReferences).toEqual(externalReferences);
  });

  it('adds, updates and deletes attributes', () => {
    let state = executor.execute(project, command({
      id: 'cmd-1', type: 'ADD_CLASS', payload: { id: 'cliente', name: 'Cliente' },
    }));
    state = executor.execute(state, command({
      id: 'cmd-2',
      type: 'ADD_ATTRIBUTE',
      targetId: 'cliente',
      payload: { id: 'attr-id', name: 'id', dataType: 'Long', primaryKey: true },
    }));
    expect(state.classes[0]?.attributes[0]).toMatchObject({
      id: 'attr-id', nullable: false, unique: true, primaryKey: true,
    });

    state = executor.execute(state, command({
      id: 'cmd-3', type: 'UPDATE_ATTRIBUTE', targetId: 'attr-id', payload: { name: 'codigo', dataType: 'UUID' },
    }));
    expect(state.classes[0]?.attributes[0]?.name).toBe('codigo');

    state = executor.execute(state, command({
      id: 'cmd-4', type: 'DELETE_ATTRIBUTE', targetId: 'attr-id', payload: {},
    }));
    expect(state.classes[0]?.attributes).toEqual([]);
  });

  it('adds, updates and deletes relationships', () => {
    let state = executor.execute(project, command({
      id: 'cmd-1', type: 'ADD_CLASS', payload: { id: 'cliente', name: 'Cliente' },
    }));
    state = executor.execute(state, command({
      id: 'cmd-2', type: 'ADD_CLASS', payload: { id: 'mascota', name: 'Mascota' },
    }));
    state = executor.execute(state, command({
      id: 'cmd-3',
      type: 'ADD_RELATIONSHIP',
      payload: {
        id: 'cliente-mascota',
        type: 'ASSOCIATION',
        sourceClassId: 'cliente',
        targetClassId: 'mascota',
        sourceMultiplicity: '1',
        targetMultiplicity: '0..*',
      },
    }));
    state = executor.execute(state, command({
      id: 'cmd-4', type: 'UPDATE_RELATIONSHIP', targetId: 'cliente-mascota', payload: { targetMultiplicity: '1..*' },
    }));
    expect(state.relationships[0]?.targetMultiplicity).toBe('1..*');

    state = executor.execute(state, command({
      id: 'cmd-5', type: 'DELETE_RELATIONSHIP', targetId: 'cliente-mascota', payload: {},
    }));
    expect(state.relationships).toEqual([]);
  });

  it('deleting a class also removes its relationships', () => {
    let state = executor.execute(project, command({
      id: 'cmd-1', type: 'ADD_CLASS', payload: { id: 'a', name: 'A' },
    }));
    state = executor.execute(state, command({
      id: 'cmd-2', type: 'ADD_CLASS', payload: { id: 'b', name: 'B' },
    }));
    state = executor.execute(state, command({
      id: 'cmd-3', type: 'ADD_RELATIONSHIP', payload: {
        id: 'r', type: 'ASSOCIATION', sourceClassId: 'a', targetClassId: 'b', sourceMultiplicity: '1', targetMultiplicity: '1',
      },
    }));
    state = executor.execute(state, command({
      id: 'cmd-4', type: 'DELETE_CLASS', targetId: 'a', payload: {},
    }));

    expect(state.classes.map((item) => item.id)).toEqual(['b']);
    expect(state.relationships).toEqual([]);
  });

  it('rejects invalid commands before changing state', () => {
    const state = executor.execute(project, command({
      id: 'cmd-1', type: 'ADD_CLASS', payload: { id: 'cliente', name: 'Cliente' },
    }));

    expect(() => executor.execute(state, command({
      id: 'cmd-2', type: 'ADD_CLASS', payload: { id: 'otro', name: 'cliente' },
    }))).toThrow(CommandValidationError);
    expect(state.classes).toHaveLength(1);
  });
});

describe('CommandHistory', () => {
  it('supports undo, redo and clears redo after a divergent edit', () => {
    const executor = new CommandExecutor(sequentialIds());
    const history = new CommandHistory(createProject('Demo', () => 'project'), executor);

    history.execute(command({ id: 'cmd-1', type: 'ADD_CLASS', payload: { id: 'a', name: 'A' } }));
    history.execute(command({ id: 'cmd-2', type: 'RENAME_CLASS', targetId: 'a', payload: { name: 'B' } }));
    expect(history.state.classes[0]?.name).toBe('B');
    expect(history.state.revision).toBe(2);

    history.undo();
    expect(history.state.classes[0]?.name).toBe('A');
    expect(history.state.revision).toBe(3);
    expect(history.canRedo).toBe(true);

    history.redo();
    expect(history.state.classes[0]?.name).toBe('B');
    expect(history.state.revision).toBe(4);

    history.undo();
    history.execute(command({ id: 'cmd-3', type: 'MOVE_CLASS', targetId: 'a', payload: { position: { x: 4, y: 8 } } }));
    expect(history.canRedo).toBe(false);
    expect(history.state.classes[0]?.position).toEqual({ x: 4, y: 8 });
  });

  it('returns defensive copies of state', () => {
    const history = new CommandHistory(createProject('Demo', () => 'project'));
    const exposed = history.state;
    exposed.name = 'Alterado desde fuera';
    expect(history.state.name).toBe('Demo');
  });
});
