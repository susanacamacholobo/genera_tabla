import { useEffect, useState, type FormEvent } from 'react';
import {
  BUILT_IN_DATA_TYPES,
  MULTIPLICITIES,
  RELATIONSHIP_TYPES,
  randomId,
  type AttributeModel,
  type ClassModel,
  type Command,
  type DataType,
  type Multiplicity,
  type ProjectModel,
  type RelationshipModel,
  type RelationshipType,
} from '../../../domain';
import type { DiagramSelection } from '../hooks/useDiagramEditor';

interface EditorProps {
  onExecute: (command: Command) => boolean;
}

function AttributeEditor({
  attribute,
  dataTypes,
  onExecute,
}: EditorProps & { attribute: AttributeModel; dataTypes: readonly string[] }) {
  const [name, setName] = useState(attribute.name);
  const [dataType, setDataType] = useState<DataType>(attribute.dataType);
  const [primaryKey, setPrimaryKey] = useState(attribute.primaryKey);
  const [nullable, setNullable] = useState(attribute.nullable);
  const [unique, setUnique] = useState(attribute.unique);

  useEffect(() => {
    setName(attribute.name);
    setDataType(attribute.dataType);
    setPrimaryKey(attribute.primaryKey);
    setNullable(attribute.nullable);
    setUnique(attribute.unique);
  }, [attribute]);

  const save = (event: FormEvent) => {
    event.preventDefault();
    onExecute({
      id: randomId(),
      type: 'UPDATE_ATTRIBUTE',
      targetId: attribute.id,
      payload: {
        name,
        dataType,
        primaryKey,
        nullable: primaryKey ? false : nullable,
        unique: primaryKey ? true : unique,
      },
    });
  };

  return (
    <form className="attribute-editor" aria-label={`Editar atributo ${attribute.name}`} onSubmit={save}>
      <label>
        Nombre
        <input value={name} onChange={(event) => setName(event.target.value)} />
      </label>
      <label>
        Tipo
        <select value={dataType} onChange={(event) => setDataType(event.target.value)}>
          {dataTypes.map((type) => <option key={type}>{type}</option>)}
        </select>
      </label>
      <div className="checkbox-row">
        <label><input type="checkbox" checked={primaryKey} onChange={(event) => setPrimaryKey(event.target.checked)} /> PK</label>
        <label><input type="checkbox" checked={nullable} disabled={primaryKey} onChange={(event) => setNullable(event.target.checked)} /> Nullable</label>
        <label><input type="checkbox" checked={unique || primaryKey} disabled={primaryKey} onChange={(event) => setUnique(event.target.checked)} /> Unique</label>
      </div>
      <div className="inline-actions">
        <button type="submit" className="button button--small">Guardar</button>
        <button
          type="button"
          className="button button--small button--danger"
          onClick={() => onExecute({ id: randomId(), type: 'DELETE_ATTRIBUTE', targetId: attribute.id, payload: {} })}
        >
          Eliminar
        </button>
      </div>
    </form>
  );
}

function AddAttributeForm({
  classId,
  dataTypes,
  onExecute,
}: EditorProps & { classId: string; dataTypes: readonly string[] }) {
  const [name, setName] = useState('');
  const [dataType, setDataType] = useState<DataType>('String');
  const [primaryKey, setPrimaryKey] = useState(false);
  const [nullable, setNullable] = useState(true);
  const [unique, setUnique] = useState(false);

  const add = (event: FormEvent) => {
    event.preventDefault();
    const accepted = onExecute({
      id: randomId(),
      type: 'ADD_ATTRIBUTE',
      targetId: classId,
      payload: {
        id: randomId(),
        name,
        dataType,
        primaryKey,
        nullable: primaryKey ? false : nullable,
        unique: primaryKey ? true : unique,
      },
    });
    if (accepted) {
      setName('');
      setDataType('String');
      setPrimaryKey(false);
      setNullable(true);
      setUnique(false);
    }
  };

  return (
    <form className="property-form" aria-label="Agregar atributo" onSubmit={add}>
      <h3>Nuevo atributo</h3>
      <label>
        Nombre
        <input required value={name} onChange={(event) => setName(event.target.value)} placeholder="telefono" />
      </label>
      <label>
        Tipo
        <select value={dataType} onChange={(event) => setDataType(event.target.value)}>
          {dataTypes.map((type) => <option key={type}>{type}</option>)}
        </select>
      </label>
      <div className="checkbox-row">
        <label><input type="checkbox" checked={primaryKey} onChange={(event) => setPrimaryKey(event.target.checked)} /> PK</label>
        <label><input type="checkbox" checked={nullable} disabled={primaryKey} onChange={(event) => setNullable(event.target.checked)} /> Nullable</label>
        <label><input type="checkbox" checked={unique || primaryKey} disabled={primaryKey} onChange={(event) => setUnique(event.target.checked)} /> Unique</label>
      </div>
      <button type="submit" className="button button--primary button--full">Agregar atributo</button>
    </form>
  );
}

function ClassProperties({
  umlClass,
  project,
  onExecute,
}: EditorProps & { umlClass: ClassModel; project: ProjectModel }) {
  const [name, setName] = useState(umlClass.name);
  const dataTypes = [
    ...BUILT_IN_DATA_TYPES,
    ...project.enumerations.map((enumeration) => enumeration.name),
  ];

  useEffect(() => setName(umlClass.name), [umlClass.id, umlClass.name]);

  return (
    <div className="properties-content">
      <p className="properties-kicker">Clase</p>
      <form
        className="property-form"
        aria-label="Renombrar clase"
        onSubmit={(event) => {
          event.preventDefault();
          onExecute({ id: randomId(), type: 'RENAME_CLASS', targetId: umlClass.id, payload: { name } });
        }}
      >
        <label>
          Nombre de clase
          <input value={name} onChange={(event) => setName(event.target.value)} />
        </label>
        <button type="submit" className="button button--secondary button--full">Renombrar</button>
      </form>

      <section className="properties-section">
        <h3>Atributos</h3>
        {umlClass.attributes.length === 0 ? (
          <p className="muted">Esta clase todavía no tiene atributos.</p>
        ) : (
          umlClass.attributes.map((attribute) => (
            <AttributeEditor
              key={attribute.id}
              attribute={attribute}
              dataTypes={dataTypes}
              onExecute={onExecute}
            />
          ))
        )}
      </section>
      <AddAttributeForm classId={umlClass.id} dataTypes={dataTypes} onExecute={onExecute} />
    </div>
  );
}

function RelationshipProperties({
  relationship,
  project,
  onExecute,
}: EditorProps & { relationship: RelationshipModel; project: ProjectModel }) {
  const [type, setType] = useState<RelationshipType>(relationship.type);
  const [sourceMultiplicity, setSourceMultiplicity] = useState<Multiplicity>(relationship.sourceMultiplicity);
  const [targetMultiplicity, setTargetMultiplicity] = useState<Multiplicity>(relationship.targetMultiplicity);

  useEffect(() => {
    setType(relationship.type);
    setSourceMultiplicity(relationship.sourceMultiplicity);
    setTargetMultiplicity(relationship.targetMultiplicity);
  }, [relationship]);

  const source = project.classes.find((item) => item.id === relationship.sourceClassId)?.name;
  const target = project.classes.find((item) => item.id === relationship.targetClassId)?.name;

  return (
    <div className="properties-content">
      <p className="properties-kicker">Relación</p>
      <h2>{source} → {target}</h2>
      <form
        className="property-form"
        aria-label="Editar relación"
        onSubmit={(event) => {
          event.preventDefault();
          onExecute({
            id: randomId(),
            type: 'UPDATE_RELATIONSHIP',
            targetId: relationship.id,
            payload: { type, sourceMultiplicity, targetMultiplicity },
          });
        }}
      >
        <label>
          Tipo
          <select value={type} onChange={(event) => setType(event.target.value as RelationshipType)}>
            {RELATIONSHIP_TYPES.map((item) => <option key={item} value={item}>{item === 'ASSOCIATION' ? 'Asociación' : 'Generalización'}</option>)}
          </select>
        </label>
        <label>
          Multiplicidad en {source}
          <select value={sourceMultiplicity} onChange={(event) => setSourceMultiplicity(event.target.value as Multiplicity)}>
            {MULTIPLICITIES.map((item) => <option key={item}>{item}</option>)}
          </select>
        </label>
        <label>
          Multiplicidad en {target}
          <select value={targetMultiplicity} onChange={(event) => setTargetMultiplicity(event.target.value as Multiplicity)}>
            {MULTIPLICITIES.map((item) => <option key={item}>{item}</option>)}
          </select>
        </label>
        <button type="submit" className="button button--primary button--full">Guardar relación</button>
      </form>
    </div>
  );
}

export function PropertiesPanel({
  project,
  selection,
  onExecute,
}: EditorProps & { project: ProjectModel; selection: DiagramSelection }) {
  if (!selection) {
    return (
      <aside className="properties-panel properties-panel--empty">
        <div>
          <h2>Propiedades</h2>
          <p>Selecciona una clase o una relación para editarla.</p>
        </div>
      </aside>
    );
  }

  if (selection.kind === 'class') {
    const umlClass = project.classes.find((item) => item.id === selection.id);
    return (
      <aside className="properties-panel">
        {umlClass ? <ClassProperties umlClass={umlClass} project={project} onExecute={onExecute} /> : <p>La clase ya no existe.</p>}
      </aside>
    );
  }

  const relationship = project.relationships.find((item) => item.id === selection.id);
  return (
    <aside className="properties-panel">
      {relationship ? <RelationshipProperties relationship={relationship} project={project} onExecute={onExecute} /> : <p>La relación ya no existe.</p>}
    </aside>
  );
}
