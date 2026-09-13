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
- una asociación tiene referencias, multiplicidades o roles inválidos;
- existen enumeraciones, reservadas para una fase posterior.

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

Hibernate utiliza `ddl-auto: update` para materializar el esquema del MVP. La
administración versionada de esquemas podrá reemplazar esta estrategia cuando
el contrato generado se estabilice.

## Contrato REST y validación

Desde la fase 11 los controladores no exponen entidades JPA. Por cada entidad
se generan:

- un record `EntidadRequest`, sin la clave primaria generada;
- un record `EntidadResponse`, con la clave primaria y todos los campos;
- un `EntidadMapper` para aplicar escalares y producir respuestas;
- servicios que resuelven relaciones mediante repositorios.

Los `String` obligatorios usan `@NotBlank`; los otros escalares obligatorios y
las relaciones singulares requeridas usan `@NotNull`; una colección `1..*`
propietaria usa `@NotEmpty`. `POST` y `PUT` reciben el mismo contrato validado.
Como `PUT` reemplaza el estado editable, omitir una relación opcional la deja en
`null` o vacía.

Las relaciones nunca anidan entidades en el API. El lado propietario acepta
`rolId` o `rolIds`; las respuestas de ambos lados contienen esos IDs. El
servicio rechaza con 404 cualquier ID relacionado inexistente.

`GlobalExceptionHandler` devuelve `ApiError` con `timestamp`, `status`,
`error`, `message`, `path` y `fieldErrors`. La validación y el JSON inválido
producen 400, los recursos ausentes 404 y las restricciones de integridad 409.

## Relaciones JPA

La fase 10 interpreta la multiplicidad de cada extremo desde la perspectiva
del extremo opuesto:

| Origen | Destino | Campo origen | Campo destino |
| --- | --- | --- | --- |
| uno | uno | `@OneToOne` propietario | `@OneToOne(mappedBy=...)` |
| uno | muchos | `@OneToMany(mappedBy=...)` | `@ManyToOne` propietario |
| muchos | uno | `@ManyToOne` propietario | `@OneToMany(mappedBy=...)` |
| muchos | muchos | `@ManyToMany` + `@JoinTable` | `@ManyToMany(mappedBy=...)` |

El lado propietario se elige por la dirección canónica, no por el orden en que
se renderizan archivos. Los roles `targetRole` y `sourceRole` nombran,
respectivamente, el campo navegable en la clase origen y en la clase destino.
Si faltan, los nombres se derivan de las clases y de si el extremo es singular
o colección.

Las colecciones usan `Set` inicializado y carga eager durante esta etapa. Los
DTOs eliminan los ciclos en la frontera REST y representan relaciones mediante
IDs. `@JsonIgnoreProperties` se conserva por compatibilidad al manipular una
entidad fuera de esa frontera; una fase posterior podrá ajustar la estrategia
de carga sin cambiar el contrato HTTP.

El validador rechaza referencias rotas, multiplicidades y roles inválidos,
colisiones con atributos/campos generados, asociaciones reflexivas y
generalizaciones. Estas dos últimas no forman parte del alcance de la fase 10.

Cada proyecto con asociaciones incorpora pruebas de metadata JPA, persistencia
y serialización. También prueba que los DTO resuelvan relaciones válidas y
rechacen IDs inexistentes. Los tests de controlador cubren CRUD, validación y
errores 404 estructurados.

Los comandos completos de instalación, generación y prueba están en
[`generators/spring-generator/README.md`](../generators/spring-generator/README.md).
