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

## IN PROGRESS

- Ninguna fase.

## TODO

- Fase 17: cargar y validar `metadata/domain-model.json` en Flutter mediante
  `DomainModelLoader`.
- Fases posteriores según el plan maestro.

## KNOWN ISSUES

- No se conocen defectos en el alcance de las fases 0 a 16.
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
- El editor visual todavía utiliza un fixture local; el adaptador HTTP que
  conectará la UI con proyectos, snapshots y el protocolo WebSocket pertenece a
  un incremento posterior. La fase 13 entrega y prueba el servidor colaborativo.
- Las rooms y la presencia viven en memoria y requieren un único proceso de
  Uvicorn. Escalar horizontalmente requerirá un bus compartido.
- La fase 15 define la frontera del LLM CASE, pero conserva el parser por reglas
  como predeterminado hasta conectar un runtime local concreto.
- El tráfico HTTP sin cifrar está permitido en el manifiesto Android para la
  demostración por LAN; un despliegue fuera de la red local deberá usar HTTPS.
- Maven no está instalado globalmente en el equipo; la verificación del backend
  generado se realizó con Maven 3.9.16 descargado y verificado temporalmente.
- La generalización y las asociaciones reflexivas permanecen fuera del alcance
  del generador; se rechazan con errores explícitos.
