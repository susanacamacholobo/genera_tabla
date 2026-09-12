# CASE backend

API FastAPI de la herramienta CASE. La fase 4 incorpora persistencia de
proyectos mediante SQLAlchemy, PostgreSQL y migraciones Alembic.

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

## Verificación

```powershell
& "..\..\.venv\Scripts\python.exe" -m pytest
& "..\..\.venv\Scripts\python.exe" -m ruff check .
```

Las pruebas automatizadas usan una base SQLite efímera para aislar cada caso.
La configuración de ejecución y las migraciones apuntan exclusivamente a
PostgreSQL.

El contrato de los endpoints se describe en
[docs/projects-api.md](../../docs/projects-api.md).
