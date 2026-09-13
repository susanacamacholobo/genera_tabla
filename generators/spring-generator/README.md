# Generador Spring Boot

Genera un proyecto CRUD determinista desde el modelo canónico de GeneraTabla.
Las fases 8 y 9 soportan entidades simples y producen `pom.xml`, aplicación,
entidades JPA, repositorios, servicios, controladores REST, configuración
PostgreSQL y pruebas CRUD.

## Instalar

Desde la raíz del monorepo:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".\generators\spring-generator[dev]"
```

## Generar el ejemplo

El directorio de salida debe ser nuevo o estar vacío:

```powershell
.\.venv\Scripts\spring-generator.exe `
  .\generators\spring-generator\tests\fixtures\simple_entity.json `
  .\generated\veterinaria
```

Se puede cambiar el paquete base con `--group-id com.miempresa`. El resultado
usa Java 21 y Spring Boot 4.1.1.

## Configurar PostgreSQL local

El proyecto generado contiene `.env.example`. Desde su directorio:

```powershell
createdb --host 127.0.0.1 --port 5432 --username postgres veterinaria
Copy-Item .env.example .env
notepad .env

Get-Content .env | ForEach-Object {
  if ($_ -match '^([^#=]+)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
  }
}
```

La contraseña permanece en `.env`, archivo ignorado por Git. No se requiere
Docker.

## Compilar y ejecutar el resultado

Requiere Java 21, Maven 3.6.3 o posterior y PostgreSQL local para ejecutar la
aplicación:

```powershell
Set-Location .\generated\veterinaria
mvn test
mvn spring-boot:run
```

`mvn test` no necesita PostgreSQL: activa el perfil `test` y usa una base H2
aislada. Genera una prueba de contexto y una prueba CRUD HTTP por entidad.

La API queda disponible en `http://localhost:8080/api/clientes`. En otra
terminal se puede crear y consultar un registro:

```powershell
$body = '{"nombre":"Ana","saldo":12.50,"fechaRegistro":"2026-09-13T10:00:00"}'
$cliente = Invoke-RestMethod -Method Post `
  -Uri http://localhost:8080/api/clientes `
  -ContentType application/json `
  -Body $body

Invoke-RestMethod -Method Get -Uri http://localhost:8080/api/clientes
Invoke-RestMethod -Method Get -Uri "http://localhost:8080/api/clientes/$($cliente.id)"
```

Detén la aplicación con `Ctrl+C`.

## Verificar el generador

```powershell
.\.venv\Scripts\python.exe -m pytest .\generators\spring-generator
.\.venv\Scripts\python.exe -m ruff check .\generators\spring-generator
.\.venv\Scripts\python.exe -m build .\generators\spring-generator
```

## Alcance de esta fase

- Una clave primaria numérica (`Integer` o `Long`) por entidad.
- Tipos escalares canónicos soportados por el mapeador.
- Sin relaciones ni enumeraciones; se rechazan antes de renderizar.
- PostgreSQL local configurado mediante `DB_HOST`, `DB_PORT`, `DB_NAME`,
  `DB_USERNAME` y `DB_PASSWORD`.
- H2 limitado al alcance `test`; nunca se usa al ejecutar normalmente.
- Sin DTO ni Bean Validation todavía.

Las relaciones pertenecen a la fase 10 y DTO/validación a la fase 11.
