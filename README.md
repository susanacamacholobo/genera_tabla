# Software 1 Project

Monorepo para una herramienta CASE colaborativa, un generador determinista de
Spring Boot y un cliente móvil Flutter reutilizable.

## Estado actual

Están implementadas las fases 0 a 12, además de la preparación 2.5:

- estructura base de los cuatro proyectos;
- modelo UML canónico independiente de cualquier librería visual;
- validación estructural del modelo;
- patrón Command con historial undo/redo;
- contrato de referencias externas para el futuro round-trip XMI 2.1.
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

Colaboración en tiempo real, round-trip XMI e IA quedan deliberadamente fuera
de este incremento. La colaboración por WebSockets corresponde a la fase
siguiente.

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
