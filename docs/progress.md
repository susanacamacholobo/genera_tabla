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

## IN PROGRESS

- Fase 4: CRUD de proyectos, capas API/servicio/repositorio, configuración de
  PostgreSQL y primera migración Alembic implementados. Pendiente ejecutar la
  migración y el CRUD contra la instancia PostgreSQL local configurada por el
  usuario.

## TODO

- Fase 5: persistencia de snapshots del modelo y eventos de cambio.
- Fases posteriores según el plan maestro.

## KNOWN ISSUES

- No se conocen defectos en el alcance de las fases 0 a 3.
- PostgreSQL local exige autenticación SCRAM; la verificación real de la fase 4
  requiere que el usuario complete el archivo privado `case-tool/backend/.env`.
- La validación previa a generar Spring será deliberadamente más estricta; no es
  una carencia del editor, porque debe admitir modelos parciales mientras se
  construyen.
- La compatibilidad XMI exacta no puede validarse hasta disponer de fixtures
  reales exportados desde la versión de Enterprise Architect del proyecto.
- Las enumeraciones se renderizan en modo básico y no se pueden mover ni editar
  porque el modelo y los comandos actuales no definen esas operaciones.
