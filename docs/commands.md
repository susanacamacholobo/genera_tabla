# Comandos

Toda modificación del modelo pasa por `CommandExecutor`. Cada comando tiene un
`id`, un `type`, un `payload` y, cuando corresponde, un `targetId`.

## Tipos implementados

```text
ADD_CLASS            DELETE_CLASS          RENAME_CLASS
MOVE_CLASS           ADD_ATTRIBUTE         UPDATE_ATTRIBUTE
DELETE_ATTRIBUTE     ADD_RELATIONSHIP      UPDATE_RELATIONSHIP
DELETE_RELATIONSHIP
```

`ADD_ATTRIBUTE.targetId` señala la clase propietaria. Para actualizar o borrar,
`targetId` identifica directamente el atributo. En los comandos de relación,
`targetId` identifica la relación existente.

Ejemplo:

```json
{
  "id": "command-42",
  "type": "ADD_ATTRIBUTE",
  "targetId": "class-cliente",
  "payload": {
    "name": "telefono",
    "dataType": "String",
    "nullable": false
  }
}
```

## Flujo

1. `CommandValidator` revisa precondiciones y simula el resultado.
2. La validación canónica comprueba el estado resultante simulado completo.
3. `CommandExecutor` crea una copia, aplica el cambio, aumenta `revision` y
   vuelve a validar el estado real (incluidos los IDs recién asignados).
4. `CommandHistory` conserva el estado anterior y vacía redo tras una nueva
   rama de edición.

Los estados devueltos son copias defensivas. Un comando inválido lanza
`CommandValidationError` con todas las incidencias disponibles. Undo/redo
restaura snapshots exclusivamente a través del ejecutor, que vuelve a
validarlos, y también crea una nueva revisión monotónica.
