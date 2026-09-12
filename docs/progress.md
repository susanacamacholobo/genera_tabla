# Progreso

## DONE

- Fase 0: estructura y proyectos base; tests, lint y builds verificados.
- Fase 1: modelo canónico, validación, ejemplo JSON y tests.
- Fase 2: comandos, validación, ejecutor, undo/redo y tests.
- Fase 2.5: preparación de interoperabilidad XMI con referencias externas,
  packages mínimos, fronteras de adaptadores y contrato de round-trip.

## IN PROGRESS

- Ninguna fase.

## TODO

- Fase 3: editor React con `@xyflow/react`.
- Fases 4 y posteriores según el plan maestro.

## KNOWN ISSUES

- No se conocen defectos en el alcance de las fases 0 a 2.
- La validación previa a generar Spring será deliberadamente más estricta; no es
  una carencia del editor, porque debe admitir modelos parciales mientras se
  construyen.
- La compatibilidad XMI exacta no puede validarse hasta disponer de fixtures
  reales exportados desde la versión de Enterprise Architect del proyecto.
