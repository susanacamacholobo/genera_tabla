# IA en CASE y Android

El proyecto contiene dos fronteras de IA relacionadas pero independientes.

## Herramienta CASE

La fase 15 implementa `LocalLLMCommandParser` en TypeScript. Su único trabajo es
convertir instrucciones de edición UML en comandos canónicos. Depende de la
interfaz `LocalLLMProvider`, que permite inyectar un proveedor. Pese al nombre
actual de la interfaz, CASE no necesita un modelo local ni funcionamiento
offline: la fase 20.5 permite IA CASE remota o local configurable y dictado
mediante el navegador. La interfaz advierte si el audio o el contexto UML
pueden enviarse fuera del equipo y mantiene una ruta escrita por reglas. La IA
propone cambios concretos en clases, atributos y relaciones para que el usuario
los confirme; no genera un diagrama completo. Consulta
[case-voice.md](case-voice.md).

No se incluye todavía un modelo concreto. Las pruebas usan un proveedor fake y
demuestran que el parser:

- construye el prompt con el contexto UML;
- acepta únicamente una acción JSON permitida;
- resuelve nombres de clases sin confiar en IDs generados por el modelo;
- normaliza tipos de datos;
- encapsula fallos del runtime;
- produce comandos aceptados por el ejecutor canónico.

## Asistente Flutter Android

El requisito offline principal pertenece al cliente móvil. La fase 18 define
`LocalAIProvider`, `StructuredIntent`, su parser estricto, el validador y la
resolución REST. La fase 19 incorpora reconocimiento de voz mediante el servicio
estrictamente on-device de Android, sin fallback remoto. La fase 20 implementa
`LiteRtLocalAIProvider` y ejecuta LiteRT-LM en el host Kotlin del teléfono. El
usuario importa un archivo `.litertlm` con licencia propia; el binario del
modelo no forma parte del repositorio. Las fases 21 y 22 unirán el flujo y
verificarán el modo offline completo.

```text
Android: texto/voz -> modelo local -> StructuredIntent -> REST por LAN
CASE:    texto/voz -> IA configurable -> propuesta confirmada -> Command -> UML
```

El puente Android arranca inicialmente con backend CPU para maximizar
compatibilidad. La inferencia se ejecuta en un hilo dedicado, conserva un solo
motor cargado y crea una conversación por instrucción. `ResponseFormat.json`
aplica un JSON Schema al decodificador; Dart decodifica y valida nuevamente el
objeto antes de sacarlo de la frontera de confianza. Consulta
[local-llm-android.md](local-llm-android.md) para preparar el modelo.

El teléfono podrá usar la API Spring Boot de la laptop mediante la red local sin
tener salida a Internet. La validación en modo avión y la detección de intentos
de conexión externa corresponden a la fase 22.
