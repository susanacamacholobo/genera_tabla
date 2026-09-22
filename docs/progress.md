# Progreso

## DONE

- Fase 0: estructura y proyectos base; tests, lint y builds verificados.
- Fase 1: modelo canónico, validación, ejemplo JSON y tests.
- Fase 2: comandos, validación, ejecutor, undo/redo y tests.
- Fase 2.5: preparación de interoperabilidad XMI con referencias externas,
  packages mínimos, fronteras de adaptadores y contrato de round-trip.
- Fase 3: editor UML visual con clases, atributos, enumeraciones básicas,
  asociaciones, generalizaciones, multiplicidades, selección, errores y
  undo/redo.
- Fase 4: CRUD de proyectos, capas API/servicio/repositorio, PostgreSQL local y
  primera migración Alembic. Migración y flujo HTTP verificados contra
  PostgreSQL 17.
- Fase 5: snapshots JSONB del modelo canónico, event log de comandos,
  validación estructural, control de revisión optimista y migración Alembic.
  Flujo completo y conflictos verificados contra PostgreSQL 17.
- Fase 6: `CommandHistory`, undo/redo y UI básica, implementados anticipadamente
  durante las fases 2 y 3.
- Fase 7: interfaz `NaturalLanguageCommandParser`, parser determinista para
  crear/eliminar clases y agregar atributos, barra de texto, errores tipados e
  integración con el historial existente.
- Fase 8: generador determinista de proyectos Spring Boot para entidades
  simples, con validación previa, mapeo intermedio, plantillas Jinja2, salida a
  directorio/ZIP y CRUD JPA probado sobre H2.
- Fase 9: proyectos generados configurados para PostgreSQL local mediante
  variables de entorno, `.env.example`, perfil H2 aislado para tests y pruebas
  CRUD MockMvc por entidad. Compilación, CRUD y persistencia tras reinicio
  verificados contra PostgreSQL 17.6 sin Docker.
- Fase 10: asociaciones bidireccionales `OneToOne`, `OneToMany`/`ManyToOne` y
  `ManyToMany`, con propietario determinista, `mappedBy`, columnas/tablas de
  unión, control de ciclos JSON y pruebas generadas de metadata, persistencia y
  serialización. Cliente–Mascota verificado también contra PostgreSQL 17.6.
- Fase 11: DTOs de solicitud/respuesta, mapeadores, Bean Validation, relaciones
  expresadas por IDs y respuestas de error uniformes para 400, 404 y 409. Los
  fixtures simple, uno-a-uno, uno-a-muchos y muchos-a-muchos compilan y pasan
  sus pruebas Maven generadas.
- Fase 12: `openapi/openapi.json` y `metadata/domain-model.json` deterministas,
  derivados del contrato DTO. El backend generado expone OpenAPI 3.1 en
  `/v3/api-docs` y Swagger UI en `/swagger-ui.html`; ambos se verifican con
  pruebas Maven generadas.
- Fase 13: colaboración WebSocket con una room por proyecto, snapshot inicial,
  eventos persistidos antes del broadcast, revisiones ordenadas, presencia,
  rechazo de conflictos estructurales y rebase *last-write-wins* de movimientos.
- Fase 14: importador y exportador XMI 2.1, API de carga/descarga, persistencia
  del modelo importado, protección XML, fixtures reales de EA 15 y cuatro flujos
  de round-trip verificados directamente con Enterprise Architect 15 build 1514.
- Fase 15: interfaz asíncrona de comandos naturales, `LocalLLMCommandParser`,
  proveedor local intercambiable, contrato JSON restringido, resolución segura
  a IDs internos, manejo de fallos y soporte de espera en la UI. Verificado con
  proveedor fake, sin red ni runtime concreto.
- Fase 16: base Flutter modular con `ApiClient` GET/POST/PUT/DELETE,
  `API_BASE_URL`, errores tipados, dependencias inyectables, navegación y
  `AssistantPanel` asíncrono. Acceso HTTP LAN habilitado en Android y APK
  verificado.
- Fase 17: modelos de contrato Dart, `DomainModelLoader` desde asset/JSON,
  validación sintáctica y semántica de metadata `1.0.0`, búsquedas inmutables e
  integración visual del contrato generado en la pantalla Flutter inicial.
- Fase 18: contrato estricto `StructuredIntent`, contexto derivado de la
  metadata, validación de entidades, campos, relaciones, tipos e IDs,
  resolución de seis operaciones REST y ejecución probada con
  `FakeLocalAIProvider`. `SEARCH_ENTITY` consulta la colección y filtra en el
  teléfono porque el backend generado no publica una ruta de búsqueda.
- Fase 19: interfaz `SpeechToTextProvider`, adaptador Flutter por
  `MethodChannel`, runtime nativo `SpeechRecognizer` exclusivamente on-device,
  permiso de micrófono, ciclo de vida, errores seguros e integración del
  dictado con `AssistantPanel`. Probado con canal y proveedor fake, además de
  compilar el APK.
- Fase 20: `LiteRtLocalAIProvider`, puente Flutter/Kotlin por `MethodChannel`,
  runtime LiteRT-LM 0.17.0 en CPU, importación privada y reemplazo seguro de
  modelos `.litertlm`, ciclo de vida del motor y salida restringida por JSON
  Schema. Probado en Dart con canal simulado y compilado contra el SDK Android.
- Fase 20.5: dictado web revisable, comandos de clases, atributos y relaciones,
  propuesta confirmable, IA CASE opcional con clave en backend, proyectos web
  persistidos y sincronizados, undo/redo como eventos. Pruebas frontend/backend
  y smoke colaborativo contra PostgreSQL local.
- Fase 21: `AssistantPanel` conectado con `LiteRtLocalAIProvider`, contrato de
  dominio, `IntentService`, API Spring y presentación de resultados. Flujo
  completo voz → IA local → intención validada → REST cubierto por pruebas; APK
  debug compilado para Android arm64.
- Fase 22: almacenamiento SQLite genérico guiado por el contrato de dominio,
  caché de consultas, CRUD local cuando Spring Boot no responde, cola
  persistente FIFO, remapeo de IDs temporales, sincronización automática/manual
  y estado de conexión visible. Cubierto con pruebas unitarias y de interfaz.
  Verificado físicamente en Android: voz e IA en modo avión, lectura SQLite,
  creación offline y sincronización posterior a PostgreSQL local.

## IN PROGRESS

- Fase 23: simulacro Biblioteca. Modelo UML, ida y vuelta XMI, generación
  Spring desde XMI, pruebas Maven, CRUD contra PostgreSQL local y pantalla
  Flutter manual con prueba automatizada. La variante se instaló en Android y
  el usuario confirmó que el registro de ejemplo funcionó, también en modo
  avión. Hotel y Universidad tienen modelos UML, round-trip XMI, backend
  generado y probado con PostgreSQL, pantallas Flutter manuales, asistente
  integrado por metadata y APK compiladas. Hotel ya se instaló y abrió en
  Android; Universidad está compilada. Falta validarlos interactivamente en
  el teléfono.

## TODO

- Completar la prueba física de Hotel y Universidad para cerrar la fase 23.

## KNOWN ISSUES

- No se conocen defectos en el alcance de las fases 0 a 20.
- PostgreSQL local exige autenticación SCRAM; su contraseña permanece únicamente
  en el archivo privado `case-tool/backend/.env`.
- La validación previa a generar Spring será deliberadamente más estricta; no es
  una carencia del editor, porque debe admitir modelos parciales mientras se
  construyen.
- El adaptador XMI cubre el subconjunto UML comprometido y aplana packages
  anidados porque el modelo canónico todavía no representa un árbol de packages.
- La geometría toma el primer diagrama que contenga cada clase; no conserva
  estilos, rutas manuales de conectores ni múltiples vistas del mismo elemento.
- Las enumeraciones se renderizan en modo básico y no se pueden mover ni editar
  porque el modelo y los comandos actuales no definen esas operaciones.
- Sin backend disponible, la web muestra el ejemplo Veterinaria en modo demo:
  permite editar, pero esos cambios no se guardan. Con el backend activo, los
  proyectos creados en PostgreSQL sí se guardan y sincronizan.
- Las rooms y la presencia viven en memoria y requieren un único proceso de
  Uvicorn. Escalar horizontalmente requerirá un bus compartido.
- El parser por reglas sigue siendo predeterminado. La IA CASE requiere un
  endpoint compatible configurado en el backend; la voz web depende del soporte
  del navegador y puede usar un servicio remoto. La IA offline exigida al
  asistente Flutter sigue siendo una frontera distinta.
- El runtime LiteRT-LM y el dictado se validaron físicamente en el Xiaomi
  conectado. La primera inferencia después de cargar Gemma puede tardar más que
  las siguientes por el calentamiento del modelo.
- La sincronización conserva operaciones rechazadas por la API para evitar
  pérdida de datos. La resolución asistida de conflictos 409 y la combinación
  automática de ediciones concurrentes quedan fuera de esta fase.
- El reconocimiento on-device exige Android 12/API 31 o posterior y que el
  dispositivo tenga instalado un motor e idioma local compatible. La app
  rechaza dispositivos sin ese soporte y no usa el reconocedor genérico como
  fallback, porque éste podría enviar audio a servidores externos.
- El tráfico HTTP sin cifrar está permitido en el manifiesto Android para la
  demostración por LAN; un despliegue fuera de la red local deberá usar HTTPS.
- Maven no está instalado globalmente en el equipo; la verificación del backend
  generado se realizó con Maven 3.9.16 descargado y verificado temporalmente.
- La generalización y las asociaciones reflexivas permanecen fuera del alcance
  del generador; se rechazan con errores explícitos.
