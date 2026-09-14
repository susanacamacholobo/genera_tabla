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

El panel todavía no interpreta intenciones ni ejecuta CRUD. Esos comportamientos
se conectarán después de cargar `domain-model.json` en la fase 17.
