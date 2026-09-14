# Cliente móvil Flutter

Base Android reutilizable para el frontend que se desarrollará durante la
presentación. Incluye configuración, cliente REST, navegación, manejo de errores
y panel del asistente; todavía no incluye pantallas de un dominio específico ni
un modelo de IA.

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
Internet; las fases 19 a 22 incorporarán y verificarán voz e IA dentro del
dispositivo Android.
