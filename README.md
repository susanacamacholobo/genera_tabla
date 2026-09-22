# Software 1 Project

Monorepo para una herramienta CASE colaborativa, un generador determinista de
Spring Boot y un cliente móvil Flutter reutilizable.

## Estado actual

Están implementadas las fases 0 a 23, incluida la fase 20.5, además de la preparación 2.5:

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
- descarga del backend Spring como ZIP desde el proyecto UML seleccionado en
  la web CASE, con validación previa del modelo.
- abstracción asíncrona para interpretar comandos CASE con IA intercambiable,
  salida JSON restringida y resolución segura de nombres. Su implementación
  actual se llama `LocalLLMCommandParser`, pero CASE no exige IA local.
- base Flutter modular con configuración por entorno, cliente REST, errores
  tipados, navegación y panel reutilizable para el asistente.
- contrato de dominio Flutter y cargador validado para consumir
  `metadata/domain-model.json` generado por la herramienta.
- sistema de intenciones Flutter con JSON estricto, validación contra el
  contrato de dominio y resolución segura de operaciones REST.
- reconocimiento de voz Android estrictamente local, integrado al panel del
  asistente mediante una frontera Dart reemplazable.
- runtime LiteRT-LM dentro de Android, importación privada de modelos
  `.litertlm`, ciclo de vida, errores seguros y salida restringida mediante JSON
  Schema.
- edición UML web por voz o texto con propuesta confirmable, IA CASE opcional y
  proyectos persistidos y sincronizados con PostgreSQL local.
- asistente Flutter conectado de extremo a extremo: voz local, LiteRT-LM,
  intención validada, operación REST y resultado visible.
- persistencia SQLite en Android, consultas locales, cola de escrituras y
  sincronización con Spring Boot al recuperar la conexión.

El [simulacro Biblioteca](docs/demo-biblioteca.md) documenta el recorrido
CASE ↔ Enterprise Architect mediante XMI, Spring y Flutter. Los
[simulacros Hotel y Universidad](docs/demo-hotel-universidad.md) completan la
fase 23; sus APK y backends también se probaron en Android y PostgreSQL local.

La [edición UML asistida por voz en CASE](docs/roadmap-case-voice.md) ya está
implementada. Para ponerla en marcha, véase [la guía de prueba](docs/case-voice.md).
La conexión del panel Flutter y su capa de datos offline están completas. La
guía de prueba está en [docs/offline.md](docs/offline.md).

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

```powershell
cd mobile-client/flutter
flutter test
flutter analyze
flutter build apk --debug

# Emulador Android: la laptop se alcanza mediante 10.0.2.2
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Los contratos y decisiones están descritos en [docs/](docs/).
La preparación del modelo Android está en
[docs/local-llm-android.md](docs/local-llm-android.md).
