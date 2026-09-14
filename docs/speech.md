# Reconocimiento de voz local Android

La fase 19 integra voz sin añadir un servicio cloud ni una dependencia de
terceros. Flutter usa un canal de plataforma para invocar la API nativa de
Android. El host acepta únicamente `createOnDeviceSpeechRecognizer`, disponible
desde API 31, y comprueba antes `isOnDeviceRecognitionAvailable`.

Aunque `RecognizerIntent.EXTRA_PREFER_OFFLINE` también se envía, no se usa como
garantía porque Android documenta que algunos reconocedores pueden ignorarlo.
La garantía real es crear específicamente el reconocedor on-device. Referencias:

- [SpeechRecognizer — Android Developers](https://developer.android.com/reference/android/speech/SpeechRecognizer)
- [RecognizerIntent — Android Developers](https://developer.android.com/reference/android/speech/RecognizerIntent)
- [Platform channels — Flutter](https://docs.flutter.dev/platform-integration/platform-channels)

## Requisitos del teléfono

- Android 12/API 31 o posterior;
- un servicio de reconocimiento on-device instalado;
- el paquete local del idioma español disponible;
- permiso de micrófono para la aplicación.

La ruta exacta para descargar idiomas depende del fabricante y motor de voz.
Debe hacerse durante la preparación, cuando haya Internet. El uso normal y la
prueba posterior no lo necesitan. Si Android no reporta un reconocedor local,
la app muestra una explicación y no intenta usar otro motor.

## Flujo

```text
tap en micrófono
 -> solicitar RECORD_AUDIO si hace falta
 -> comprobar reconocedor on-device
 -> escuchar en es-BO
 -> devolver transcripción y confianza opcional
 -> rellenar el campo de AssistantPanel
```

El dictado no se envía automáticamente. El usuario puede revisar o corregir el
texto antes de pulsar **Enviar**. La fase 21 conectará ese envío con el LLM local
y el sistema de intenciones.

## Prueba manual offline

1. Instala previamente el idioma de reconocimiento español.
2. Compila e instala el APK en el teléfono.
3. Abre la app una vez y concede permiso de micrófono.
4. Activa modo avión; Wi-Fi también debe quedar desactivado para esta prueba.
5. Abre **Asistente**, pulsa el micrófono y dicta una instrucción breve.
6. Comprueba que el texto aparezca en el campo.

El backend Spring Boot no participa en esta prueba de voz. Para probar después
REST por LAN sin salida a Internet, puede reactivarse únicamente Wi-Fi y
mantener la red sin acceso WAN.

## Pruebas automatizadas

```powershell
cd mobile-client/flutter
flutter test test/speech test/assistant test/widget_test.dart
flutter analyze
flutter build apk --debug
```

Las pruebas sustituyen tanto el canal nativo como `SpeechToTextProvider`. Cubren
disponibilidad, locale, resultados, sesión única, permisos, errores seguros,
cancelación, liberación e integración con el panel.
