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

En la fase 8 se incluye H2 en memoria solamente para ejecutar el resultado sin
infraestructura. La fase 9 sustituirá esa configuración por PostgreSQL local.
Las relaciones y los DTO permanecen fuera de alcance hasta las fases 10 y 11.

Los comandos completos de instalación, generación y prueba están en
[`generators/spring-generator/README.md`](../generators/spring-generator/README.md).
