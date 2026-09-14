# Colaboración en tiempo real

La fase 13 incorpora rooms WebSocket en FastAPI. Cada proyecto tiene una sala
independiente y usa las mismas revisiones, snapshots y bitácora persistente que
la API HTTP.

## Conexión

```text
ws://127.0.0.1:8000/ws/projects/{project_id}?userId={id}&displayName={nombre}
```

`userId` y `displayName` son obligatorios. Todavía no representan autenticación:
el cliente declara su identidad hasta que una fase posterior incorpore usuarios
y permisos.

Al aceptar la conexión, el servidor envía primero el snapshot actual:

```json
{
  "type": "session.ready",
  "projectId": "project-uuid",
  "userId": "ana",
  "revision": 4,
  "model": {},
  "presence": [
    {"userId": "ana", "displayName": "Ana", "status": "active"}
  ]
}
```

Una conexión a un proyecto inexistente recibe `protocol.error` y se cierra con
el código `4404`. Una identidad inválida se cierra con `4400`.

## Mensajes del cliente

Enviar un cambio ya ejecutado por el dominio del editor:

```json
{
  "type": "change.submit",
  "baseRevision": 4,
  "command": {
    "id": "command-uuid",
    "type": "MOVE_CLASS",
    "targetId": "class-cliente",
    "payload": {"position": {"x": 260, "y": 180}}
  },
  "model": {
    "id": "project-uuid",
    "name": "Veterinaria",
    "revision": 5,
    "classes": [],
    "relationships": [],
    "enumerations": []
  }
}
```

Actualizar presencia:

```json
{"type": "presence.update", "status": "editing"}
```

Los estados aceptados son `active`, `editing` y `away`. Un mensaje
`{"type":"ping"}` recibe `{"type":"pong"}`.

## Eventos del servidor

Un cambio se difunde a toda la room únicamente después de confirmar en la base
de datos el evento, el snapshot y la nueva revisión:

```json
{
  "type": "change.applied",
  "eventId": "event-uuid",
  "projectId": "project-uuid",
  "userId": "ana",
  "baseRevision": 4,
  "revision": 5,
  "command": {},
  "model": {},
  "rebased": false,
  "createdAt": "2026-09-13T20:00:00+00:00"
}
```

`presence.changed` contiene la lista completa y ordenada de usuarios de la
room. Varias pestañas del mismo `userId` se agregan como una sola presencia; el
estado más activo prevalece.

Los errores recuperables no cierran una conexión válida:

- `protocol.error / INVALID_MESSAGE`: JSON o mensaje fuera del contrato.
- `change.rejected / REVISION_CONFLICT`: cambio estructural basado en una
  revisión antigua.
- `change.rejected / INVALID_MODEL`: el modelo no coincide con el proyecto o
  con la revisión siguiente.

## Conflictos

El MVP no usa CRDT. Una estrategia intercambiable aplica estas reglas:

- los eventos aceptados quedan totalmente ordenados por `revision`;
- un cambio basado en la revisión actual se persiste normalmente;
- un `MOVE_CLASS` atrasado se rebasa sobre el último snapshot y aplica
  *last-write-wins* sólo a la posición indicada;
- cualquier otro cambio atrasado se rechaza con la revisión actual, para que el
  cliente recargue el snapshot y vuelva a ejecutar su intención.

El rebase de movimientos nunca reemplaza clases, atributos o relaciones que
otro usuario haya modificado mientras tanto.

## Alcance operativo

Las rooms y la presencia son efímeras y viven en memoria; los cambios y
snapshots sí permanecen en PostgreSQL. Por ello, esta primera versión se ejecuta
con un solo proceso de Uvicorn. Para escalar a varios workers se necesitará un
bus compartido, por ejemplo Redis o PostgreSQL `LISTEN/NOTIFY`, sin modificar el
protocolo público.
