# Generador Spring Boot

Genera un proyecto CRUD determinista desde el modelo canónico de GeneraTabla.
La fase 8 soporta entidades simples y produce `pom.xml`, aplicación, entidades
JPA, repositorios, servicios, controladores REST y una prueba de contexto.

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
usa Java 21, Spring Boot 4.1.1 y una base H2 temporal para poder ejecutarse sin
configuración adicional en esta fase.

## Compilar y ejecutar el resultado

Requiere Java 21 y Maven 3.6.3 o posterior:

```powershell
Set-Location .\generated\veterinaria
mvn test
mvn spring-boot:run
```

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
- Sin DTO, Bean Validation ni PostgreSQL generado todavía.

La configuración PostgreSQL pertenece a la fase 9, las relaciones a la fase 10
y DTO/validación a la fase 11.
