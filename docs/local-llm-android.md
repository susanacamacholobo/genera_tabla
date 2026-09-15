# Modelo LLM local en Android

La fase 20 integra LiteRT-LM 0.17.0 directamente en el host Kotlin de Flutter.
El modelo se carga y ejecuta dentro del teléfono con backend CPU; no existe una
API de inferencia remota ni una descarga automática del modelo.

## Modelo recomendado

Para la primera prueba se recomienda el paquete genérico cuantizado
`gemma3-1b-it-int4.litertlm` de
[Gemma3-1B-IT](https://huggingface.co/litert-community/Gemma3-1B-IT/tree/main).
Ocupa aproximadamente 584 MB. El repositorio es público, pero Hugging Face
exige iniciar sesión y aceptar la licencia de Gemma antes de descargar sus
archivos; por eso el binario no se incluye ni se descarga desde la aplicación.

No elijas inicialmente los archivos que terminan en nombres de chipset como
`sm8650` o `mt6991`: están optimizados para hardware concreto. Tampoco uses los
archivos `.task`, porque el selector de esta aplicación acepta `.litertlm`.

## Importar y cargar

1. Descarga `gemma3-1b-it-int4.litertlm` y cópialo a **Descargas** del teléfono.
2. Ejecuta la aplicación Android y abre **Asistente**.
3. Pulsa **Importar .litertlm** y selecciona el archivo.
4. Cuando la tarjeta muestre el tamaño, pulsa **Cargar modelo**.
5. Espera hasta ver **cargado y listo sin Internet**. La primera carga puede
   tardar varios segundos.

La importación copia el archivo a almacenamiento privado de la aplicación con
el nombre `assistant.litertlm`. Se conservan al menos 100 MB libres adicionales
y el modelo anterior no se reemplaza si la activación del archivo nuevo falla.
Desinstalar la aplicación elimina también esa copia privada.

La fase 20 permite importar y cargar el runtime. La fase 21 conectará el botón
**Enviar** con `IntentService` para que una instrucción atraviese el modelo, la
validación y la API Spring Boot.

## Contrato de salida

Cada inferencia crea una conversación aislada y usa decodificación restringida
por un JSON Schema. LiteRT-LM sólo puede producir un objeto con:

- una de las seis operaciones CRUD admitidas;
- una entidad;
- un identificador opcional;
- parámetros escalares o listas de escalares.

Aunque el runtime restringe los tokens, Dart vuelve a decodificar el resultado
y la fase 18 lo valida contra `domain-model.json` antes de permitir cualquier
petición REST. El modelo nunca decide el método HTTP, host ni URL.

## Verificación de desarrollo

```powershell
cd mobile-client/flutter
flutter analyze
flutter test
flutter build apk --debug `
  --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

El APK queda en `build/app/outputs/flutter-apk/app-debug.apk`. Para probar sólo
la importación y carga del modelo no es necesario iniciar Spring Boot. La prueba
de una instrucción completa estará disponible en la fase 21.

La guía oficial de la API Kotlin está en
[LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM/blob/main/docs/api/kotlin/getting_started.md).
