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
el contrato generado se estabilice. Los DTO permanecen fuera de alcance hasta
la fase 11.

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

Las colecciones usan `Set` inicializado y carga eager durante esta etapa para
que los controladores que todavía exponen entidades puedan serializarlas con
`open-in-view: false`. `@JsonIgnoreProperties` omite sólo el enlace de regreso
al anidar una entidad y evita ciclos. La fase 11 reemplazará esta frontera por
DTOs, permitiendo volver a estrategias de carga ajustadas al contrato REST.

El validador rechaza referencias rotas, multiplicidades y roles inválidos,
colisiones con atributos/campos generados, asociaciones reflexivas y
generalizaciones. Estas dos últimas no forman parte del alcance de la fase 10.

Cada proyecto con asociaciones incorpora pruebas de metadata JPA y pruebas que
persisten, recargan y serializan cada relación.

Los comandos completos de instalación, generación y prueba están en
[`generators/spring-generator/README.md`](../generators/spring-generator/README.md).
