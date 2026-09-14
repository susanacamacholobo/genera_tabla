# API de proyectos

La fase 4 introduce el agregado persistente mínimo `Project`. Cada proyecto
contiene:

- `id`: UUID opaco representado como texto;
- `name`: nombre normalizado, entre 1 y 200 caracteres;
- `revision`: contador reservado para los cambios del modelo canónico;
- `created_at` y `updated_at`: fechas con zona horaria.

## Endpoints

| Método | Ruta | Resultado |
| --- | --- | --- |
| `POST` | `/projects` | Crea un proyecto y responde `201`. |
| `GET` | `/projects` | Lista los proyectos por fecha de creación. |
| `GET` | `/projects/{id}` | Devuelve un proyecto o `404`. |
| `PUT` | `/projects/{id}` | Reemplaza el nombre o responde `404`. |
| `DELETE` | `/projects/{id}` | Elimina el proyecto y responde `204`. |
| `POST` | `/projects/xmi/import` | Importa XMI 2.1 como proyecto nuevo; responde `201`. |
| `GET` | `/projects/{id}/xmi` | Descarga la revisión actual como XMI 2.1. |

Ejemplo de creación:

```json
{
  "name": "Veterinaria"
}
```

La primera migración, `20260912_01`, crea la tabla `projects` y un índice para
el nombre. La API no crea tablas automáticamente al arrancar: antes de usarla
debe ejecutarse `python -m alembic upgrade head` desde `case-tool/backend`.

## Historial y colaboración

La fase 5 añade snapshots, eventos y control de revisión sobre estos proyectos.
La fase 13 expone esos mismos agregados como rooms WebSocket para edición
multiusuario. Consulta [model-history.md](model-history.md) y
[collaboration.md](collaboration.md).

La carga XMI es `multipart/form-data` con un campo `file`, admite un `scope`
opcional en query y tiene un límite de 5 MiB. Un XMI inválido responde `422` y
un archivo demasiado grande responde `413`.
