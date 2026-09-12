# Editor visual UML

## Arquitectura

El editor utiliza `@xyflow/react`, pero React Flow no es el modelo de dominio ni
la fuente de verdad.

```text
ProjectModel
    |
    v
ReactFlowAdapter (transformación pura)
    |
    v
Node[] / Edge[] de presentación
    |
    v
interacción visual
    |
    v
Command -> CommandValidator -> CommandExecutor -> ProjectModel
```

`ReactFlowAdapter.fromProject` proyecta clases, atributos, enumeraciones,
relaciones, posiciones y multiplicidades. `node.id` usa el ID interno estable de
la clase. `node.data` sólo contiene datos renderizables; deliberadamente excluye
el modelo completo y `externalReferences`.

## Componentes

- `DiagramEditor`: integra lienzo, toolbar, selección, errores e inspectores.
- `UMLClassNode`: muestra nombre, atributos, tipos, PK, selección y handles.
- `UMLEnumNode`: representación básica y de sólo lectura de enumeraciones.
- `RelationshipEdge`: dibuja el enlace y las multiplicidades en ambos extremos.
- `PropertiesPanel`: comandos de clases, atributos y relaciones.
- `useDiagramEditor`: conecta React con una única instancia de `CommandHistory`.

## Interacciones y comandos

| Interacción | Comando de dominio |
| --- | --- |
| `+ Clase` | `ADD_CLASS` |
| Soltar una clase después de arrastrarla | `MOVE_CLASS` |
| Renombrar desde propiedades | `RENAME_CLASS` |
| Agregar, guardar o eliminar atributo | `ADD_ATTRIBUTE`, `UPDATE_ATTRIBUTE`, `DELETE_ATTRIBUTE` |
| Arrastrar entre handles | `ADD_RELATIONSHIP` |
| Guardar tipo o multiplicidades | `UPDATE_RELATIONSHIP` |
| Eliminar selección | `DELETE_CLASS` o `DELETE_RELATIONSHIP` |

Una conexión nueva se crea como asociación `1` → `0..*` y queda seleccionada
inmediatamente para editar tipo y multiplicidades. Los errores del dominio se
muestran en un panel visible; la UI no replica las reglas de validación.

## Movimiento y viewport

La posición persistente siempre es `ClassModel.position`. `useNodesState` se usa
sólo durante el drag para que el movimiento sea fluido. `onNodeDragStop` emite
un único `MOVE_CLASS`; al cambiar el modelo, el adaptador vuelve a proyectar los
nodos. No se genera un comando por píxel.

Zoom, pan y fit view son estado visual de React Flow y no modifican el modelo
canónico.

## Relaciones

La dirección se conserva literalmente:

```text
sourceClassId         -> edge.source
targetClassId         -> edge.target
sourceMultiplicity   -> etiqueta cercana al origen
targetMultiplicity   -> etiqueta cercana al destino
```

Una generalización va desde la clase especializada (`source`) hacia la clase
base (`target`) y muestra una flecha cerrada en el target. Los intentos de crear
ciclos se rechazan por el validador canónico.

## Historial e interoperabilidad

Deshacer y rehacer utilizan exclusivamente `CommandHistory`; no existe un
historial paralelo de nodos o aristas. Los comandos de movimiento, renombrado y
actualización preservan las referencias externas añadidas en la fase 2.5.

## Enumeraciones

Las enumeraciones se muestran como nodos básicos, determinísticos y no
arrastrables. `EnumerationModel` todavía no tiene posición ni comandos de
edición dentro del alcance actual; añadir movimiento o edición requiere ampliar
el contrato canónico en una fase futura, no guardar estado permanente sólo en
React Flow.

## Ejecución

```bash
npm run dev --workspace @software1/case-frontend
```

El editor inicia con `docs/examples/veterinaria.json` y ofrece controles de zoom,
pan y fit view.

