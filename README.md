# Software 1 Project

Monorepo para una herramienta CASE colaborativa, un generador determinista de
Spring Boot y un cliente móvil Flutter reutilizable.

## Estado actual

Están implementadas exclusivamente las fases 0, 1 y 2 del plan:

- estructura base de los cuatro proyectos;
- modelo UML canónico independiente de cualquier librería visual;
- validación estructural del modelo;
- patrón Command con historial undo/redo.

React Flow, persistencia, colaboración, generación Spring, XMI e IA quedan
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

