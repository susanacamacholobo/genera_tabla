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

## IN PROGRESS

- Ninguna fase.

## TODO

- Fase 14: importación y exportación XMI con pruebas contra Enterprise Architect.
- Fases posteriores según el plan maestro.

## KNOWN ISSUES

- No se conocen defectos en el alcance de las fases 0 a 13.
- PostgreSQL local exige autenticación SCRAM; su contraseña permanece únicamente
  en el archivo privado `case-tool/backend/.env`.
- La validación previa a generar Spring será deliberadamente más estricta; no es
  una carencia del editor, porque debe admitir modelos parciales mientras se
  construyen.
- La compatibilidad XMI exacta no puede validarse hasta disponer de fixtures
  reales exportados desde la versión de Enterprise Architect del proyecto.
- Las enumeraciones se renderizan en modo básico y no se pueden mover ni editar
  porque el modelo y los comandos actuales no definen esas operaciones.
- El editor visual todavía utiliza un fixture local; el adaptador HTTP que
  conectará la UI con proyectos, snapshots y el protocolo WebSocket pertenece a
  un incremento posterior. La fase 13 entrega y prueba el servidor colaborativo.
- Las rooms y la presencia viven en memoria y requieren un único proceso de
  Uvicorn. Escalar horizontalmente requerirá un bus compartido.
- Maven no está instalado globalmente en el equipo; la verificación del backend
  generado se realizó con Maven 3.9.16 descargado y verificado temporalmente.
- La generalización y las asociaciones reflexivas permanecen fuera del alcance
  del generador; se rechazan con errores explícitos.
