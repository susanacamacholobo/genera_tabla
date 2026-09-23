# Base de datos de GeneraTabla

`generatabla-schema.sql` crea el esquema PostgreSQL utilizado por el backend
FastAPI de la herramienta CASE. El archivo refleja las migraciones Alembic
hasta la revision `20260912_02` y contiene:

- `projects`: identidad, nombre y revision actual de cada proyecto CASE;
- `project_snapshots`: modelo UML canonico completo almacenado como JSONB;
- `change_events`: bitacora de comandos usada por la colaboracion y el control
  de revisiones;
- `alembic_version`: revision aplicada del esquema.

Las dos tablas dependientes usan `ON DELETE CASCADE`: al eliminar un proyecto
se eliminan sus snapshots y eventos. Las restricciones unicas impiden repetir
una revision o un comando dentro del mismo proyecto.

## Crear la base y aplicar el script en Windows

Desde PowerShell, ajusta la version de PostgreSQL si fuera distinta:

```powershell
& "C:\Program Files\PostgreSQL\17\bin\createdb.exe" `
  --host 127.0.0.1 --port 5432 --username postgres generatabla

& "C:\Program Files\PostgreSQL\17\bin\psql.exe" `
  --host 127.0.0.1 --port 5432 --username postgres `
  --dbname generatabla --set ON_ERROR_STOP=1 `
  --file database/generatabla-schema.sql
```

Los comandos solicitan la contrasena de PostgreSQL de forma interactiva. El
script debe ejecutarse sobre una base vacia; falla de forma segura si las
tablas ya existen.

## Verificar el resultado

```powershell
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" `
  --host 127.0.0.1 --port 5432 --username postgres `
  --dbname generatabla --command "\dt"
```

Para una instalacion normal del proyecto se pueden seguir usando las
migraciones oficiales, que producen el mismo esquema:

```powershell
Set-Location case-tool/backend
& "..\..\.venv\Scripts\python.exe" -m alembic upgrade head
```

## Exportar tambien los datos

El archivo versionado solo contiene la estructura y nunca informacion privada.
Para obtener una copia puntual con los proyectos existentes utiliza `pg_dump`
y guarda el resultado fuera del repositorio si contiene datos sensibles:

```powershell
& "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe" `
  --host 127.0.0.1 --port 5432 --username postgres `
  --dbname generatabla --format plain --no-owner --no-privileges `
  --file generatabla-respaldo.sql
```
