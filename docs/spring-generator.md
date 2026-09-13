# Generador Spring

La fase 8 implementa un generador determinista para entidades simples. Consume
el mismo JSON canónico que utiliza el editor y no depende de React Flow ni de
las tablas del backend CASE.

```text
Canonical Model
      |
      v
ModelValidator -> SpringModelMapper -> plantillas Jinja2 -> GeneratedProject
                                                               |          |
                                                               v          v
                                                          directorio     ZIP
```

## Validación previa

`ModelValidator` rechaza el modelo completo antes de crear archivos cuando:

- no hay clases o una clase carece de atributos;
- una entidad no tiene exactamente una clave primaria numérica;
- un nombre no es un identificador Java válido;
- aparece un tipo canónico no soportado;
- existen relaciones o enumeraciones, reservadas para fases posteriores.

Esta validación es deliberadamente más estricta que la del editor: un diagrama
parcial es válido durante el diseño, pero no necesariamente es generable.

## Salida

Para cada clase se generan:

- entidad JPA con tabla, columnas y estrategia de ID;
- `JpaRepository`;
- servicio CRUD con error 404;
- controlador REST con `GET`, `POST`, `PUT` y `DELETE`.

El proyecto también incluye `pom.xml`, clase `Application`, `.gitignore` y una
prueba que inicia el contexto de Spring. Los archivos se ordenan antes de
escribirlos y el ZIP usa fechas fijas, por lo que entradas iguales producen
salidas reproducibles.

Desde la fase 9, la ejecución normal usa el driver PostgreSQL y obtiene la
conexión de `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME` y `DB_PASSWORD`.
`application.yml` no contiene secretos y `.env` queda ignorado por Git. Por
decisión del entorno del proyecto se trabaja con PostgreSQL local y no se genera
`docker-compose.yml`.

H2 permanece exclusivamente como dependencia de alcance `test`. El perfil
`test` se activa de forma explícita y cada entidad recibe una prueba CRUD con
MockMvc, por lo que `mvn test` no depende de una base externa. La ejecución
normal nunca cae silenciosamente a H2.

Hibernate utiliza `ddl-auto: update` para materializar el esquema sencillo del
MVP. La administración versionada de esquemas podrá reemplazar esta estrategia
cuando se incorporen relaciones. Las relaciones y los DTO permanecen fuera de
alcance hasta las fases 10 y 11.

Los comandos completos de instalación, generación y prueba están en
[`generators/spring-generator/README.md`](../generators/spring-generator/README.md).
