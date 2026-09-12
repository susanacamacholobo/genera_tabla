# Arquitectura

## Alcance actual

La raíz del repositorio es el monorepo. Los productos se mantienen separados:

```text
case-tool/frontend          interfaz CASE y dominio TypeScript
case-tool/backend           API FastAPI
generators/spring-generator generador determinista futuro
mobile-client/flutter       cliente móvil genérico
```

Desde las fases 1 y 2 el núcleo ejecutable vive en
`case-tool/frontend/src/domain`. Es TypeScript puro: no importa React, Vite ni
ninguna librería de diagramación. La capa de la fase 3 proyecta este estado a
React Flow y traduce los gestos a comandos.

```text
UI / ReactFlowAdapter
          |
          v
Command -> CommandValidator -> CommandExecutor
                                  |
                                  v
                           ProjectModel
```

El `ProjectModel` es el contrato canónico. Las fronteras futuras (FastAPI, XMI,
generador y OpenAPI) deberán serializar o mapear este contrato, nunca modelos de
la librería visual.

La interoperabilidad sigue el mismo principio de puertos y adaptadores:

```text
Enterprise Architect -> XMIImporter -> Canonical Model
Canonical Model -> XMIExporter -> Enterprise Architect
```

Los adaptadores XMI se ubicarán en el backend. El dominio sólo conoce una
colección opcional y genérica de referencias externas; no conoce clases ni
formatos propios de Sparx Systems. Los IDs internos nunca se reemplazan por IDs
externos.

El editor visual está aislado en `src/features/diagram`. `ReactFlowAdapter` es
una transformación pura `ProjectModel -> Node[] / Edge[]`; no reconstruye el
dominio desde el grafo. `useNodesState` se limita al movimiento visual
transitorio y `onNodeDragStop` confirma la posición mediante `MOVE_CLASS`.

La persistencia inicial se organiza por capas en el backend:

```text
FastAPI router -> ProjectService -> ProjectRepository -> SQLAlchemy -> PostgreSQL
```

Los routers resuelven HTTP y validación de entrada; los servicios contienen los
casos de uso y los repositorios encapsulan las consultas. Alembic es el único
mecanismo para evolucionar el esquema. En fase 4 sólo se almacena la identidad
y metadata del proyecto; el modelo canónico y sus revisiones se incorporarán
como snapshots y eventos en la fase 5.

## Decisiones

- Actualizaciones inmutables para facilitar historial, pruebas y colaboración.
- Revisión monotónica incrementada por cada comando aceptado.
- Identificadores opacos, estables y globalmente únicos dentro del proyecto.
- Undo/redo conserva snapshots validados; es sencillo y suficiente para el MVP.
- El borrado de una clase elimina en la misma transacción sus relaciones
  incidentes para no producir referencias rotas.
- Las reglas específicas de generación (por ejemplo, exigir PK o nombres Java)
  no invalidan un diagrama mientras el usuario aún lo está editando.
- `ExternalReference` conserva identidades para round-trip por `source` y
  `scope`, además de metadata mínima del package externo.
- `Position` permanece en el dominio y la conversión de coordenadas corresponde
  a cada adaptador visual o XMI.
- Selección y viewport pertenecen a la UI; clases, atributos, relaciones y
  posiciones pertenecen exclusivamente al modelo canónico.
- La configuración de PostgreSQL se recibe por variables de entorno o por un
  `.env` local ignorado por Git; ninguna contraseña tiene valor por defecto.
