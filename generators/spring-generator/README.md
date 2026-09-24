# Generador Spring Boot

Genera un proyecto CRUD determinista desde el modelo canónico de GeneraTabla.
Las fases 8 a 12 producen `pom.xml`, aplicación, entidades JPA, repositorios,
servicios, controladores REST, DTOs, mapeadores, validación, errores,
configuración PostgreSQL, relaciones y pruebas.

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
aislada. Genera pruebas de contexto, CRUD HTTP, metadata JPA, persistencia de
relaciones, serialización JSON, validación y resolución de relaciones por ID.
También verifica `/v3/api-docs` y Swagger UI.

La salida incluye contratos utilizables sin arrancar el backend:

```text
openapi/openapi.json
metadata/domain-model.json
POSTMAN.md
```

`POSTMAN.md` incluye los comandos completos para configurar y levantar el
backend, el orden recomendado de creación y ejemplos Postman para todo el CRUD,
las validaciones y las relaciones del modelo generado.

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
- Asociaciones bidireccionales `OneToOne`, `OneToMany`/`ManyToOne` y
  `ManyToMany` según las multiplicidades UML.
- Roles de asociación opcionales; cuando faltan se derivan de las clases.
- `mappedBy`, `@JoinColumn` y `@JoinTable` generados de forma determinista.
- Serialización protegida contra ciclos con `@JsonIgnoreProperties`.
- Records `Request` y `Response`; las entidades JPA no forman parte del
  contrato de los controladores.
- Relaciones de entrada mediante `rolId` o `rolIds` en el lado propietario y
  relaciones de salida siempre mediante IDs.
- Bean Validation derivada de nulabilidad y multiplicidad UML.
- Error JSON uniforme para solicitudes inválidas, recursos inexistentes y
  conflictos de integridad.
- OpenAPI 3.1 determinista con paths CRUD y esquemas DTO.
- Metadata compacta del dominio para Flutter, IA local y testing.
- OpenAPI dinámico en `/v3/api-docs` y Swagger UI en `/swagger-ui.html`.
- Guía `POSTMAN.md` generada con preparación, ejemplos CRUD y orden de relaciones.
- PostgreSQL local configurado mediante `DB_HOST`, `DB_PORT`, `DB_NAME`,
  `DB_USERNAME` y `DB_PASSWORD`.
- H2 limitado al alcance `test`; nunca se usa al ejecutar normalmente.
- Sin generalización ni asociaciones reflexivas todavía.

La colaboración en tiempo real de la herramienta CASE pertenece al backend
FastAPI y se documenta en `docs/collaboration.md`; no forma parte del backend
Spring generado.
