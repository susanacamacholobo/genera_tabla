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

Ejemplo de creación:

```json
{
  "name": "Veterinaria"
}
```

La primera migración, `20260912_01`, crea la tabla `projects` y un índice para
el nombre. La API no crea tablas automáticamente al arrancar: antes de usarla
debe ejecutarse `python -m alembic upgrade head` desde `case-tool/backend`.

## Evolución posterior

La fase 5 añade snapshots, eventos y control de revisión sobre estos proyectos.
Consulta [model-history.md](model-history.md). WebSockets y edición multiusuario
se incorporarán después de establecer ese contrato.
