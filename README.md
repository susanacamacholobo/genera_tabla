# Software 1 Project

Monorepo para una herramienta CASE colaborativa, un generador determinista de
Spring Boot y un cliente móvil Flutter reutilizable.

## Estado actual

Están implementadas las fases 0 a 15, además de la preparación 2.5:

- estructura base de los cuatro proyectos;
- modelo UML canónico independiente de cualquier librería visual;
- validación estructural del modelo;
- patrón Command con historial undo/redo;
- contrato de referencias externas usado por el round-trip XMI 2.1.
- editor UML visual con React Flow, atributos, relaciones y multiplicidades.
- API CRUD de proyectos con FastAPI, SQLAlchemy, PostgreSQL y Alembic.
- snapshots JSONB del modelo canónico y bitácora de comandos con control de
  revisión optimista.
- parser determinista de comandos escritos y barra de ejecución integrada al
  editor.
- generador Spring Boot para entidades simples, con CRUD JPA, salida
  reproducible y verificación Maven.
- configuración PostgreSQL local y pruebas CRUD en los proyectos generados.
- generación bidireccional de relaciones JPA a partir de multiplicidades UML.
- API generada con DTOs, mapeadores, Bean Validation y errores JSON uniformes.
- contratos OpenAPI 3.1 y metadata de dominio generados para Flutter y tooling.
- colaboración WebSocket por proyecto, con persistencia de eventos, revisión
  optimista, presencia y movimientos concurrentes *last-write-wins*.
- importación y exportación XMI 2.1 compatible con Enterprise Architect, con
  round-trip de identidad, tipos, relaciones, herencia, enumeraciones y layout.
- abstracción asíncrona para interpretar comandos CASE con un LLM local, salida
  JSON restringida, resolución segura de nombres y proveedor intercambiable.

La integración del runtime y modelo dentro de Android continúa separada: se
realizará en las fases 19 a 22 después de construir la base Flutter.

## Estructura

```text
case-tool/frontend/            React + TypeScript + Vite
case-tool/backend/             FastAPI
generators/spring-generator/   Generador determinista de Spring Boot
mobile-client/flutter/         Flutter (Android)
docs/                          Arquitectura y contratos
```

## Comandos de verificación

Desde la raíz:

```bash
npm install
npm test
npm run lint
npm run build
```

Backend FastAPI:

```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -e "case-tool/backend[dev]"
.venv/Scripts/python -m pytest case-tool/backend
.venv/Scripts/python -m ruff check case-tool/backend
```

Para ejecutar la API con PostgreSQL local, consulta
[case-tool/backend/README.md](case-tool/backend/README.md). No se requiere
Docker.

Generador Spring:

```powershell
.venv/Scripts/python -m pip install -e "generators/spring-generator[dev]"
.venv/Scripts/spring-generator `
  generators/spring-generator/tests/fixtures/simple_entity.json `
  generated/veterinaria
```

Consulta [su guía](generators/spring-generator/README.md) para compilar y probar
el backend generado.

Flutter:

```bash
cd mobile-client/flutter
flutter test
flutter analyze
flutter build apk --debug
```

Los contratos y decisiones están descritos en [docs/](docs/).
