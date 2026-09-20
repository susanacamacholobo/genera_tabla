# Cliente móvil Flutter

Base Android reutilizable para el frontend que se desarrollará durante la
presentación. Incluye configuración, cliente REST, navegación, manejo de
errores, panel del asistente, sistema validado de intenciones, dictado local y
runtime LiteRT-LM en Android. También carga el contrato de dominio generado;
el archivo del modelo se importa en el teléfono y no se versiona en Git.

## Cargar el dominio generado

Copia la metadata del proyecto Spring generado antes de compilar Flutter:

```powershell
Copy-Item `
  ..\..\generated\mi-sistema\metadata\domain-model.json `
  assets\domain-model.json
```

`DomainModelLoader` valida el archivo al iniciar. La pantalla principal muestra
el nombre de la aplicación y la cantidad de entidades si el contrato es válido;
si no lo es, presenta un error y permite reintentar. El asset incluido inicialmente
corresponde al fixture `Veterinaria` del generador.

## Preparación

```powershell
flutter pub get
flutter test
flutter analyze
```

## Ejecutar en el emulador Android

El valor predeterminado de `API_BASE_URL` es `http://10.0.2.2:8080`, la ruta del
emulador hacia el equipo anfitrión:

```powershell
flutter run
```

También puede indicarse explícitamente:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## Ejecutar en un teléfono físico

El teléfono y la laptop deben estar en la misma red Wi-Fi. Sustituye la IP del
ejemplo por la IPv4 de la laptop:

```powershell
ipconfig
flutter run `
  --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

Spring Boot debe estar escuchando en el puerto indicado y el firewall de Windows
debe permitir el acceso desde la red privada. No uses `localhost`, porque desde
la aplicación se refiere al propio teléfono.

Con el teléfono conectado por USB puede evitarse la configuración Wi-Fi usando
un túnel ADB. En este caso sí se compila con `127.0.0.1` porque ADB reenvía el
puerto al equipo:

```powershell
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $adbPath reverse tcp:8080 tcp:8080
flutter build apk --debug `
  --dart-define=API_BASE_URL=http://127.0.0.1:8080
flutter install --debug
```

Algunos teléfonos requieren habilitar **Instalar mediante USB** en las opciones
de desarrollador y aceptar la confirmación en pantalla.

## Compilar el APK

La URL forma parte de la compilación, por lo que también debe proporcionarse al
crear el APK para un teléfono físico:

```powershell
flutter build apk --debug `
  --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

El archivo resultante queda en:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

La comunicación con Spring Boot ocurre por la red local. No necesita acceso a
Internet. La fase 18 incorpora el contrato de intenciones y su ejecución REST,
la fase 19 añade voz on-device, la fase 20 integra LiteRT-LM, la fase 21 conecta
el flujo completo y la fase 22 agrega SQLite y sincronización para continuar
trabajando cuando Spring Boot no está disponible.

## Probar datos sin conexión

Primero ejecuta una consulta con el servidor activo para poblar la copia local.
Después detén Spring Boot y repite la consulta o crea un registro. La pantalla
mostrará `Modo sin conexión`; las escrituras quedarán pendientes con estado
local `202`. Al iniciar nuevamente el backend, pulsa el icono de sincronización
o envía otro comando. Los cambios se enviarán en orden y el contador volverá a
cero. Véase [docs/offline.md](../../docs/offline.md) para el recorrido completo.

## Intenciones disponibles

El proveedor local debe devolver únicamente JSON con `operation`, `entity`, un
`identifier` opcional y `parameters`. Se admiten `CREATE_ENTITY`, `GET_ENTITY`,
`LIST_ENTITIES`, `UPDATE_ENTITY`, `DELETE_ENTITY` y `SEARCH_ENTITY`.

Para ejecutar solamente sus pruebas:

```powershell
flutter test test/ai
```

El texto o dictado revisado se envía al modelo local. La intención resultante se
valida, ejecuta por REST y muestra su estado HTTP y respuesta en el asistente.

## Probar el modelo local

Descarga con tu cuenta y licencia el archivo genérico
`gemma3-1b-it-int4.litertlm`, cópialo al teléfono y abre **Asistente**. Usa
**Importar .litertlm** y después **Cargar modelo**. La tarjeta confirmará cuando
el motor esté listo. El archivo ocupa aproximadamente 584 MB y se copia al
almacenamiento privado de la aplicación.

La guía completa, enlace del modelo y límites de esta fase están en
[docs/local-llm-android.md](../../docs/local-llm-android.md).

## Probar la voz local

Requisitos:

- teléfono con Android 12/API 31 o posterior;
- motor de reconocimiento on-device e idioma español descargado;
- permiso de micrófono concedido a la aplicación.

Ejecuta la app en el teléfono, abre **Asistente** y pulsa el micrófono. La
primera vez Android pedirá permiso. Habla una instrucción breve; la transcripción
aparecerá en el campo de texto y podrás corregirla antes de enviarla.

La implementación no usa el reconocedor Android genérico. Si el motor local no
está disponible, informa el problema en vez de recurrir a un servicio remoto.
