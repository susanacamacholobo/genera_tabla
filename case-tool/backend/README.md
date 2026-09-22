# CASE backend

API FastAPI de la herramienta CASE. Incorpora persistencia de proyectos,
snapshots UML y eventos de cambio mediante SQLAlchemy, PostgreSQL y migraciones
Alembic.

## Requisitos

- Python 3.12 o superior.
- PostgreSQL local disponible en `127.0.0.1:5432`.
- Una base de datos llamada `generatabla`.

No se usa Docker.

## Configuración local

Desde la raíz del repositorio, instala el backend y crea su archivo privado de
configuración:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e "case-tool/backend[dev]"
.\.venv\Scripts\python.exe -m pip install -e "generators/spring-generator"
Copy-Item case-tool/backend/.env.example case-tool/backend/.env
notepad case-tool/backend/.env
```

Completa `DB_USERNAME` y `DB_PASSWORD` con las credenciales de tu PostgreSQL.
El archivo `.env` está ignorado por Git y no debe compartirse ni subirse al
repositorio.

Si la base todavía no existe, puedes crearla con PostgreSQL 17. El comando
pedirá la contraseña de forma interactiva:

```powershell
& "C:\Program Files\PostgreSQL\17\bin\createdb.exe" `
  --host 127.0.0.1 --port 5432 --username postgres generatabla
```

## Migrar y ejecutar

```powershell
Set-Location case-tool/backend
& "..\..\.venv\Scripts\python.exe" -m alembic upgrade head
& "..\..\.venv\Scripts\python.exe" -m uvicorn case_backend.main:app --reload
```

La documentación interactiva queda disponible en
`http://127.0.0.1:8000/docs` y la comprobación de salud en
`http://127.0.0.1:8000/health`.

## Intercambio XMI con Enterprise Architect

Importa un XMI 2.1 como proyecto nuevo y snapshot inicial:

```powershell
curl.exe -X POST `
  -F "file=@modelo.xmi;type=application/xml" `
  "http://127.0.0.1:8000/projects/xmi/import?scope=mi-repositorio-ea"
```

Exporta la revisión actual de un proyecto:

```powershell
curl.exe -o modelo-exportado.xmi `
  "http://127.0.0.1:8000/projects/{project_id}/xmi"
```

La carga máxima es 5 MiB. El parser bloquea DTDs y entidades XML. El alcance y
las pruebas reales con EA 15 están en
[docs/enterprise-architect.md](../../docs/enterprise-architect.md).

## Generar Spring desde el proyecto CASE

Con el generador instalado en el mismo entorno Python, la web ofrece
**Generar backend ZIP** para el proyecto seleccionado. También está disponible
la API `GET /projects/{project_id}/spring.zip`, que toma la revisión actual
guardada en PostgreSQL. El ZIP incluye código Spring, tests, OpenAPI y
`metadata/domain-model.json`. Un modelo incompleto responde `422` con los
campos que deben corregirse; si falta instalar el paquete del generador,
responde `503`. No se usa Docker.

Con CASE y PostgreSQL activos, la prueba integrada importa un XMI, verifica
el ZIP y elimina exclusivamente el proyecto temporal creado por ella:

```powershell
& .\.venv\Scripts\python.exe scripts/smoke-case-spring.py generated/hotel.xmi
```

La colaboración usa una room por proyecto:

```text
ws://127.0.0.1:8000/ws/projects/{project_id}?userId=ana&displayName=Ana
```

Ejecuta Uvicorn con un solo proceso: las revisiones y eventos se guardan en
PostgreSQL, pero la presencia y las conexiones activas son estado efímero en
memoria.

Con el backend activo, la prueba de red crea y elimina su propio proyecto
temporal:

```powershell
& "..\..\.venv\Scripts\python.exe" scripts/smoke_collaboration.py
```

## Verificación

```powershell
& "..\..\.venv\Scripts\python.exe" -m pytest
& "..\..\.venv\Scripts\python.exe" -m ruff check .
```

Las pruebas automatizadas usan una base SQLite efímera para aislar cada caso.
La configuración de ejecución y las migraciones apuntan exclusivamente a
PostgreSQL.

El contrato de los endpoints se describe en
[docs/projects-api.md](../../docs/projects-api.md) y
[docs/model-history.md](../../docs/model-history.md). El protocolo WebSocket se
documenta en [docs/collaboration.md](../../docs/collaboration.md).

La edición web por voz y texto, la configuración opcional de IA CASE y los
pasos para probar la interfaz están en
[docs/case-voice.md](../../docs/case-voice.md). La clave del proveedor de IA,
si se usa, se guarda sólo en `.env`; nunca en React ni en Git.
