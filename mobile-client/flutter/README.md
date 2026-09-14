# Cliente móvil Flutter

Base Android reutilizable para el frontend que se desarrollará durante la
presentación. Incluye configuración, cliente REST, navegación, manejo de
errores, panel del asistente, sistema validado de intenciones y dictado local en
Android. También carga el contrato de dominio generado; todavía no incluye
pantallas de un dominio específico ni un modelo LLM real.

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
Internet. La fase 18 incorpora el contrato de intenciones y su ejecución REST;
la fase 19 añade voz on-device. Las fases 20 a 22 incorporarán el runtime LLM y
endurecerán el flujo completo dentro del dispositivo Android.

## Intenciones disponibles

El proveedor local debe devolver únicamente JSON con `operation`, `entity`, un
`identifier` opcional y `parameters`. Se admiten `CREATE_ENTITY`, `GET_ENTITY`,
`LIST_ENTITIES`, `UPDATE_ENTITY`, `DELETE_ENTITY` y `SEARCH_ENTITY`.

Para ejecutar solamente sus pruebas:

```powershell
flutter test test/ai
```

El texto y el dictado todavía se detienen antes de llamar al sistema de
intenciones. Esa conexión se completa después de incorporar el modelo Android
en las fases 20 y 21.

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
