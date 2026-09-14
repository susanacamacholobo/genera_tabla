# IA local

El proyecto contiene dos fronteras de IA relacionadas pero independientes.

## Herramienta CASE

La fase 15 implementa `LocalLLMCommandParser` en TypeScript. Su único trabajo es
convertir instrucciones de edición UML en comandos canónicos. Depende de la
interfaz `LocalLLMProvider`, por lo que un runtime local de escritorio puede
conectarse después sin cambiar el dominio ni la interfaz visual.

No se incluye todavía un modelo concreto. Las pruebas usan un proveedor fake y
demuestran que el parser:

- construye el prompt con el contexto UML;
- acepta únicamente una acción JSON permitida;
- resuelve nombres de clases sin confiar en IDs generados por el modelo;
- normaliza tipos de datos;
- encapsula fallos del runtime;
- produce comandos aceptados por el ejecutor canónico.

## Asistente Flutter Android

El requisito offline principal pertenece al cliente móvil. Las fases 18 a 22
incorporarán `StructuredIntent`, voz local y un `LocalAIProvider` cuyo runtime y
modelo se ejecuten dentro del teléfono Android. No dependerá del proveedor CASE
ni de servicios cloud.

```text
Android: texto/voz -> modelo local -> StructuredIntent -> REST por LAN
CASE:    texto     -> LLM local    -> Command          -> modelo UML
```

El teléfono podrá usar la API Spring Boot de la laptop mediante la red local sin
tener salida a Internet. La validación en modo avión y la detección de intentos
de conexión externa corresponden a la fase 22.
