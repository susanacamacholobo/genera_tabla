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

`RuleBasedCommandParser` reconoce una gramática explícita y permanece como valor
predeterminado. `LocalLLMCommandParser` satisface la misma interfaz asíncrona y
acepta un `LocalLLMProvider` intercambiable. Convierte una única acción JSON de
una lista permitida, resuelve nombres a IDs internos y nunca modifica el modelo
directamente.

```text
runtime local CASE -> LocalLLMProvider -> LocalLLMCommandParser -> Command
                                                              -> validación
                                                              -> ejecución
```

La frontera CASE anterior es independiente del futuro `LocalAIProvider` de
Flutter. Ese segundo proveedor y su modelo se ejecutarán en Android para que el
asistente móvil funcione sin Internet.

La base Flutter de la fase 16 también usa puertos inyectables:

```text
pantalla de dominio / asistente
              |
              v
          ApiClient -> http.Client -> Spring Boot por LAN
              ^
              |
      AppConfiguration(API_BASE_URL)
```

`AppDependencies` entrega configuración y cliente sin variables globales. El
router y `AssistantPanel` no conocen entidades concretas; podrán reutilizarse
con el contrato de dominio cargado en la fase 17. Los errores de
configuración, transporte, estado HTTP y decodificación cruzan una frontera
tipada antes de convertirse en mensajes para el usuario.

```text
SpringProject -> metadata/domain-model.json
                            |
                            v
                 DomainModelLoader
                            |
                  validación sintáctica
                    y semántica 1.0.0
                            |
                            v
                     DomainModel Dart
```

El cargador no analiza OpenAPI ni código Java. Consume el contrato reducido que
ya se deriva del mismo modelo intermedio del generador. Sus colecciones son
inmutables y ofrecen búsquedas de entidades, campos y relaciones sin distinguir
mayúsculas, preparadas para el validador de intenciones de la fase 18.

La fase 18 mantiene al modelo local fuera de la frontera de confianza:

```text
instrucción + DomainModel -> LocalAIProvider -> JSON
                                         |
                                         v
                    StructuredIntentParser -> IntentValidator
                                         |
                                         v
                         ApiOperationResolver -> ApiClient -> Spring Boot
```

El parser acepta sólo un objeto JSON y seis operaciones enumeradas. El
validador vuelve a resolver nombres contra `DomainModel` y rechaza entidades,
campos, IDs, tipos o escrituras no autorizadas antes de construir una petición.
El LLM nunca controla el método ni la URL directamente. `SEARCH_ENTITY` se
resuelve como lectura de colección y filtrado local para conservar el contrato
REST existente.

La voz de la fase 19 usa otra frontera inyectable:

```text
AssistantPanel -> SpeechToTextProvider -> MethodChannel
                                      -> Android SpeechRecognizer on-device
```

El host Kotlin exige API 31 y consulta
`isOnDeviceRecognitionAvailable` antes de crear el reconocedor específico del
dispositivo. No llama `createSpeechRecognizer` y por tanto no cae en una
implementación remota. El canal conserva una sola sesión activa, traduce los
callbacks nativos a un resultado tipado y destruye el reconocedor con la
actividad.

La fase 20 concreta el puerto de IA móvil sin llevar el SDK nativo al dominio
Dart:

```text
LiteRtLocalAIProvider -> MethodChannel -> LocalLlmController
                                         |
                                         v
                         LiteRT-LM Engine (CPU, on-device)
                                         |
                              ResponseFormat + JSON Schema
                                         |
                                         v
                              objeto StructuredIntent
```

El selector de documentos entrega un `.litertlm`, que el host copia al
almacenamiento privado con reemplazo seguro. Inicialización e inferencia se
serializan en un ejecutor dedicado para no bloquear Flutter. El motor permanece
cargado, pero cada solicitud usa una conversación de vida corta para impedir
que instrucciones anteriores contaminen el resultado. El JSON restringido aún
atraviesa el parser y validador de la fase 18; el runtime nativo nunca recibe
autoridad para construir URLs o ejecutar HTTP.

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

La colaboración reutiliza la misma frontera de persistencia del historial. El
servidor nunca difunde un cambio tentativo:

```text
WebSocket room -> validar base_revision -> transacción PostgreSQL
                                      commit -> broadcast change.applied
```

`CollaborationManager` mantiene únicamente sockets y presencia efímera por
`project_id`. `ModelHistoryService` sigue siendo responsable de bloquear el
proyecto, ordenar la revisión y confirmar evento más snapshot. Una interfaz de
resolución de conflictos permite reemplazar la estrategia MVP: actualmente
rebasa sólo `MOVE_CLASS` con *last-write-wins* y rechaza cambios estructurales
atrasados.

La fase 14 implementa las dos fronteras XMI preparadas en la fase 2.5:

```text
EA XMI 2.1 -> XMIImporter -> CanonicalProjectModel -> snapshot 0
snapshot actual -> CanonicalProjectModel -> XMIExporter -> EA XMI 2.1
```

El importador usa un parser XML endurecido y separa siempre el ID interno del
`xmi:id` y GUID externos. Interpreta el UML estándar y la extensión real de EA
15 para recuperar tipos, claves, roles, multiplicidades, packages y geometría.
El exportador reutiliza esas identidades; para elementos nacidos en GeneraTabla
deriva GUIDs deterministas de sus IDs internos. Así, exportar otra vez el mismo
modelo actualiza elementos en EA en vez de duplicarlos.

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
- La salida del LLM CASE es no confiable: sólo se admite JSON estricto, una
  acción permitida y IDs creados o resueltos por la aplicación.
- Flutter recibe la URL del backend en compilación mediante `API_BASE_URL`; el
  emulador usa `10.0.2.2` y un teléfono físico usa la IP LAN de la laptop.
- `ApiClient` recibe su transporte HTTP por constructor para mantener las
  pruebas locales y permitir cambiar la implementación sin afectar features.
- `DomainModelLoader` sólo acepta la versión `1.0.0` y rechaza referencias,
  cardinalidades o rutas inconsistentes antes de exponer el modelo a la UI o IA.
- La salida del LLM móvil tampoco es confiable: debe cumplir `StructuredIntent`,
  pasar `IntentValidator` y resolverse desde endpoints de la metadata; nunca
  aporta una URL ni ejecuta HTTP directamente.
- La voz móvil admite sólo el reconocedor Android creado explícitamente como
  on-device; la ausencia del motor o paquete de idioma produce un error visible,
  nunca un fallback con red.
- El generador ordena rutas y entidades, y fija la metadata temporal del ZIP
  para producir artefactos reproducibles a partir de la misma entrada.
- Cada entidad generada incluye cobertura HTTP CRUD contra el mismo controlador,
  servicio, repositorio y mapeo JPA que usa la aplicación.
- Los controladores generados dependen de DTOs, nunca de entidades; la clave
  primaria y las relaciones se resuelven dentro de la capa de servicio.
- OpenAPI y metadata se construyen desde el modelo Spring intermedio para
  preservar determinismo y evitar dependencias del código renderizado.
- La presencia se agrega por usuario dentro de cada room y no se persiste; los
  snapshots y eventos colaborativos sí se conservan en PostgreSQL.
- Un cambio WebSocket se publica sólo después del commit. Los movimientos
  atrasados se rebasan sobre el snapshot vigente sin reemplazar su estructura.
- XMI es un adaptador externo: ninguna clase propia de Sparx Systems entra al
  modelo canónico y los IDs de EA nunca sustituyen los IDs internos.
- El dialecto de salida se prueba importándolo en EA 15; el XML conserva un
  package raíz, el subconjunto UML soportado y un diagrama de clases.
