# Arquitectura

## Alcance actual

La raíz del repositorio es el monorepo. Los productos se mantienen separados:

```text
case-tool/frontend          interfaz CASE y dominio TypeScript
case-tool/backend           API FastAPI
generators/spring-generator generador determinista futuro
mobile-client/flutter       cliente móvil genérico
```

En las fases 1 y 2 el núcleo ejecutable vive en
`case-tool/frontend/src/domain`. Es TypeScript puro: no importa React, Vite ni
ninguna librería de diagramación. La futura capa React Flow deberá ser un
adaptador que proyecte este estado y traduzca gestos a comandos.

```text
UI / futuro ReactFlowAdapter
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
