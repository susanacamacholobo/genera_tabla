# Arquitectura

## Alcance actual

La raíz del repositorio es el monorepo. Los productos se mantienen separados:

```text
case-tool/frontend          interfaz CASE y dominio TypeScript
case-tool/backend           API FastAPI
generators/spring-generator generador determinista Spring Boot
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
mecanismo para evolucionar el esquema.

Desde la fase 5, cada revisión aceptada se confirma en una única transacción:

```text
comprobar base_revision y bloquear proyecto
                  |
                  v
change_event + project_snapshot + project.revision
```

`project_snapshots.model_json` y `change_events.command_json` son columnas
JSONB. El modelo canónico permanece como documento completo y no se fragmenta
en tablas por clase o atributo. Las restricciones únicas por proyecto y
revisión impiden bifurcaciones accidentales; el bloqueo de fila y
`base_revision` implementan concurrencia optimista para el MVP.

Los comandos escritos entran por otra frontera de adaptador:

```text
texto -> NaturalLanguageCommandParser -> Command -> CommandValidator -> modelo
```

`RuleBasedCommandParser` es la primera implementación. Sólo reconoce una
gramática explícita y no modifica el modelo directamente. Una futura
implementación con LLM deberá satisfacer la misma interfaz y producir los
mismos comandos tipados.

La generación Spring también cruza una frontera explícita:

```text
modelo canónico -> validación de generación -> modelo Spring -> plantillas
```

El mapeador es la única capa que conoce tipos y convenciones Java. Las
plantillas reciben un modelo intermedio ya validado, sin interpretar el JSON
canónico. `GeneratedProject` mantiene el resultado en memoria y permite
materializar exactamente los mismos archivos en un directorio o un ZIP.

La metadata de la fase 12 se deriva del mismo `SpringProject` que alimenta las
plantillas, por lo que no analiza código Java ya renderizado:

```text
SpringProject -> plantillas Java
              -> openapi/openapi.json
              -> metadata/domain-model.json
```

Springdoc observa los controladores y DTOs en ejecución para publicar
`/v3/api-docs`; las pruebas generadas verifican que sus paths y esquemas
fundamentales coincidan con el contrato estático.

La configuración de datos del resultado separa ejecución y pruebas:

```text
ejecución normal -> application.yml      -> variables de entorno -> PostgreSQL
mvn test         -> perfil test explícito -> H2 en memoria
```

La contraseña no tiene valor por defecto. El perfil de pruebas evita depender
de infraestructura externa, pero no modifica el comportamiento productivo. La
instalación objetivo usa PostgreSQL local; no existe una ruta Docker paralela.

Las asociaciones se convierten en dos campos JPA coordinados. La dirección del
modelo canónico determina el propietario en relaciones simétricas; en una
relación uno-a-muchos, el extremo `ManyToOne` es siempre propietario de la FK.
El extremo inverso referencia exactamente ese campo con `mappedBy`. Para
muchos-a-muchos, el origen posee una tabla de unión con nombres estables.

```text
sourceMultiplicity + targetMultiplicity
                    |
                    v
         kind, owner, mappedBy, join metadata
                    |
                    v
         dos JavaAssociation coordinadas
```

La fase 11 establece una frontera DTO explícita:

```text
HTTP -> Request DTO -> Bean Validation -> Service -> Entity / Repository
HTTP <- Response DTO <- Mapper <---------+
```

El API representa asociaciones mediante IDs; el servicio resuelve únicamente
los IDs del lado propietario y el mapper proyecta ambos lados a `rolId` o
`rolIds`. Así, el contrato JSON no depende de la forma ni de los ciclos del
grafo de persistencia. Un advice global traduce validación, ausencia de recursos
y restricciones de integridad a un único esquema `ApiError`.

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
- Cada proyecto nace con un snapshot vacío en revisión 0. Un cambio aceptado
  produce exactamente un evento y un snapshot en la revisión siguiente.
- Los snapshots son inmutables; eliminar el proyecto borra snapshots y eventos
  mediante claves foráneas con `ON DELETE CASCADE`.
- El parser de texto resuelve nombres a IDs, pero delega todas las reglas de
  negocio a `CommandValidator` y la ejecución a `CommandHistory`.
- El generador ordena rutas y entidades, y fija la metadata temporal del ZIP
  para producir artefactos reproducibles a partir de la misma entrada.
- Cada entidad generada incluye cobertura HTTP CRUD contra el mismo controlador,
  servicio, repositorio y mapeo JPA que usa la aplicación.
- Los controladores generados dependen de DTOs, nunca de entidades; la clave
  primaria y las relaciones se resuelven dentro de la capa de servicio.
- OpenAPI y metadata se construyen desde el modelo Spring intermedio para
  preservar determinismo y evitar dependencias del código renderizado.
