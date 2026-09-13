# Persistencia del modelo UML

La fase 5 persiste el `ProjectModel` canónico completo como JSONB y conserva el
comando que produjo cada revisión. No replica clases, atributos ni relaciones
en tablas SQL independientes.

## Tablas

`project_snapshots` contiene un documento `model_json` por proyecto y revisión.
`change_events` contiene `command_json`, `base_revision` y la revisión
resultante. Ambas tablas referencian `projects` con borrado en cascada.

Al crear un proyecto se genera automáticamente un modelo vacío en revisión 0.
Los eventos comienzan en la revisión 1.

## API

| Método | Ruta | Resultado |
| --- | --- | --- |
| `GET` | `/projects/{id}/model` | Devuelve el snapshot de la revisión actual. |
| `POST` | `/projects/{id}/changes` | Guarda comando y snapshot; responde `201`. |
| `GET` | `/projects/{id}/changes?after_revision=0` | Lista eventos posteriores a la revisión indicada. |

El cuerpo para registrar un cambio contiene el comando ejecutado y el modelo
resultante:

```json
{
  "base_revision": 0,
  "command": {
    "id": "command-add-cliente",
    "type": "ADD_CLASS",
    "payload": {
      "id": "class-cliente",
      "name": "Cliente",
      "position": { "x": 120, "y": 160 }
    }
  },
  "model": {
    "id": "project-id",
    "name": "Veterinaria",
    "revision": 1,
    "classes": [],
    "relationships": [],
    "enumerations": []
  }
}
```

El servidor acepta el cambio únicamente cuando:

- `base_revision` coincide con `projects.revision`;
- `model.id` coincide con el proyecto de la URL;
- `model.revision` es exactamente `base_revision + 1`;
- el modelo respeta la forma canónica, usa IDs únicos y no contiene relaciones
  hacia clases inexistentes.

Una revisión desactualizada responde `409 Conflict` e informa la revisión
actual. Un modelo incompatible responde `422`. La actualización del proyecto,
el evento y el snapshot se confirman en una sola transacción PostgreSQL.

## Alcance

Esta fase almacena comandos ya ejecutados por el dominio TypeScript; el backend
no vuelve a interpretarlos. La difusión por WebSocket, presencia de usuarios y
resolución avanzada de conflictos pertenecen a fases posteriores.
