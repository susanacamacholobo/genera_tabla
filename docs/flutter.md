# Flutter

La fase 16 reemplaza el contador inicial por una base Android modular y
reutilizable:

```text
lib/
├── core/api/             ApiClient y ApiResponse
├── core/config/          API_BASE_URL
├── core/dependencies/    dependencias compartidas
├── core/errors/          errores tipados y mensajes seguros
├── assistant/            AssistantPanel reutilizable
├── features/             pantallas base
└── navigation/           rutas de la aplicación
```

## Configuración

`AppConfiguration` lee `API_BASE_URL` mediante `--dart-define`. Sólo acepta URL
HTTP(S) absoluta, sin credenciales, query ni fragmento. El valor predeterminado
es `http://10.0.2.2:8080`, que desde el emulador Android apunta a la laptop.

Para un teléfono físico conectado a la misma red Wi-Fi se utiliza la IP local
de la laptop:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

No se debe usar `localhost`: dentro de Android identifica el propio teléfono.
El manifiesto permite acceso de red y tráfico HTTP sin cifrar porque el backend
de demostración se ejecuta en la LAN. Para un despliegue fuera de esa red deberá
usarse HTTPS y retirarse esa excepción.

## Cliente REST

`ApiClient` implementa `GET`, `POST`, `PUT` y `DELETE`, codifica cuerpos JSON en
UTF-8, acepta query parameters, aplica timeout y conserva las respuestas 2xx en
`ApiResponse`. Recibe una instancia de `http.Client`, lo que permite sustituir
el transporte en pruebas.

Los fallos se convierten en errores tipados:

- `ConfigurationException` para una URL insegura o inválida;
- `NetworkException` para timeout o conexión fallida;
- `ResponseDecodingException` para JSON exitoso pero inválido;
- `ApiException` para estados HTTP fuera de 2xx.

## Navegación y asistente

`AppRouter` registra la pantalla inicial, el asistente y una ruta de respaldo.
`AssistantPanel` acepta texto mediante callbacks asíncronos, valida entradas
vacías, evita envíos repetidos, muestra progreso y presenta errores seguros. El
botón de micrófono ejecuta el proveedor de voz local y coloca la transcripción
en el campo para que el usuario pueda revisarla antes de enviarla.

La fase 18 incorpora el servicio que interpreta una respuesta JSON, la valida y
ejecuta el CRUD correspondiente. La fase 20 registra el proveedor LiteRT-LM en
`AppDependencies` y muestra la tarjeta para importar y cargar el modelo. La
fase 21 conecta el envío de `AssistantPanel` con `IntentService` y muestra la
operación ejecutada, el estado HTTP y la respuesta de la API.

## Datos y sincronización offline

La fase 22 añade `OfflineDataCoordinator` y `SqliteOfflineStore`. Toda respuesta
REST válida actualiza una copia SQLite genérica por entidad. Ante un fallo de
conexión, las lecturas utilizan esa copia y las escrituras se aplican localmente
con estado `202`, quedando en una cola persistente.

La cola se reproduce en orden al recuperar el servidor. Una creación offline
usa temporalmente un identificador negativo para claves numéricas; al recibir
el ID real se actualizan el registro y cualquier operación posterior pendiente.
El asistente muestra si el resultado proviene del servidor o del teléfono, el
estado de conexión y el número de cambios pendientes. Consulta
[offline.md](offline.md) para la prueba física.

## Contrato de dominio

La fase 17 incorpora `DomainModelLoader` y modelos Dart inmutables para el
contrato `metadata/domain-model.json` producido por el generador. La aplicación
carga por defecto `assets/domain-model.json` y muestra en la pantalla inicial la
aplicación y cantidad de entidades disponibles.

El contrato reconoce:

- versión de esquema, aplicación, artifact y ruta API base;
- entidades, endpoints y campos identificadores;
- campos con tipo canónico, obligatoriedad, generación y unicidad;
- relaciones, campo usado por la API, entidad destino, cardinalidad y permiso
  de escritura.

Antes de aceptar el contrato se comprueban tipos JSON, versión `1.0.0`, valores
obligatorios, nombres y endpoints únicos, pertenencia al `basePath`, claves
generadas, referencias entre entidades y coherencia entre `kind` y `many`. Las
rutas con query, fragmentos, barras invertidas o segmentos `..` se rechazan.

Durante la presentación, después de generar el backend, se reemplaza el asset:

```powershell
Copy-Item `
  generated\mi-sistema\metadata\domain-model.json `
  mobile-client\flutter\assets\domain-model.json
```

Después se desarrollan manualmente las pantallas específicas y se recompila
Flutter. El cargador también acepta un `String` u objeto JSON en memoria, para
pruebas y futuras fuentes de metadata.

## Sistema de intenciones

`IntentService` implementa el flujo seguro entre el futuro modelo local y el
backend. El modelo sólo podrá proponer un `StructuredIntent`; antes de cualquier
petición, `IntentValidator` comprueba la entidad, identificador, parámetros,
tipos, campos obligatorios y permisos de escritura del contrato cargado.

`ApiOperationResolver` convierte las operaciones permitidas a `GET`, `POST`,
`PUT` o `DELETE`. La búsqueda usa el `GET` de la colección y filtra el resultado
en el dispositivo, ya que el backend generado no define un endpoint especial de
búsqueda. El contrato detallado está en [intents.md](intents.md).

## Voz local Android

La fase 19 añade `SpeechToTextProvider` y
`AndroidSpeechToTextProvider`. Flutter cruza un `MethodChannel` propio hacia
Kotlin; el host comprueba y crea exclusivamente
`SpeechRecognizer.createOnDeviceSpeechRecognizer`. No existe fallback al
reconocedor genérico.

Se requiere Android 12/API 31 o posterior, permiso de micrófono y un idioma de
reconocimiento sin conexión ya instalado en el dispositivo. Si alguno falta,
la aplicación muestra un error seguro. Consulta [speech.md](speech.md) para la
preparación y prueba en modo avión.

## LLM local Android

La fase 20 añade `LiteRtLocalAIProvider` y `ManagedLocalAIProvider`. Flutter
cruza el canal `bo.edu.software1/local_llm`; el host Kotlin importa un archivo
`.litertlm` al almacenamiento privado, inicializa LiteRT-LM fuera del hilo de UI
y conserva el motor hasta cerrar la aplicación.

La generación usa muestreo determinista y `ResponseFormat.json` con el esquema
de `StructuredIntent`. El proveedor Dart exige que la respuesta sea un único
objeto JSON y nunca expone detalles nativos en sus errores. El backend inicial
es CPU; GPU/NPU se evaluarán después de medir el teléfono real. La guía de
instalación del modelo está en [local-llm-android.md](local-llm-android.md).
