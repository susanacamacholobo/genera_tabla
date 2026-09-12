# Software 1 Project

Monorepo para una herramienta CASE colaborativa, un generador determinista de
Spring Boot y un cliente móvil Flutter reutilizable.

## Estado actual

Están implementadas las fases 0, 1, 2, la preparación 2.5 y la fase 3:

- estructura base de los cuatro proyectos;
- modelo UML canónico independiente de cualquier librería visual;
- validación estructural del modelo;
- patrón Command con historial undo/redo;
- contrato de referencias externas para el futuro round-trip XMI 2.1.
- editor UML visual con React Flow, atributos, relaciones y multiplicidades.

Persistencia, colaboración, generación Spring, XMI e IA quedan
deliberadamente fuera de este incremento.

## Estructura

```text
case-tool/frontend/            React + TypeScript + Vite
case-tool/backend/             FastAPI
generators/spring-generator/   Paquete Python reservado para el generador
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

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -e "case-tool/backend[dev]"
.venv/Scripts/python -m pytest case-tool/backend
.venv/Scripts/python -m ruff check case-tool/backend
```

Flutter:

```bash
cd mobile-client/flutter
flutter test
flutter analyze
flutter build apk --debug
```

Los contratos y decisiones están descritos en [docs/](docs/).
