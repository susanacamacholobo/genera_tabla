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
`AssistantPanel` acepta texto mediante un callback asíncrono, valida entradas
vacías, evita envíos repetidos, muestra progreso y presenta errores seguros. El
botón de micrófono queda deliberadamente desactivado hasta la fase 19.

La fase 18 incorpora el servicio que interpreta una respuesta JSON, la valida y
ejecuta el CRUD correspondiente. La pantalla todavía no lo instancia porque el
proveedor real se incorporará en la fase 20; la conexión final de voz, modelo,
intenciones y panel corresponde a la fase 21.

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
