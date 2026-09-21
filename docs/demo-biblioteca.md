# Simulacro Biblioteca (fase 23)

El ejemplo [biblioteca.json](examples/biblioteca.json) modela `Socio`, `Libro` y
`Prestamo`, con dos relaciones obligatorias de muchos a uno. La pantalla Flutter
de este dominio está escrita a mano; el generador no crea la interfaz móvil.

## CASE y Enterprise Architect

Con PostgreSQL local y el backend CASE iniciados según
[su guía](../case-tool/backend/README.md), ejecuta la web con
`npm run dev --workspace @software1/case-frontend`. Para cargar rápidamente el
modelo de ejemplo desde la raíz del repositorio:

```powershell
& .\.venv\Scripts\python.exe scripts/export-example-xmi.py `
  docs/examples/biblioteca.json generated/Biblioteca.xmi
```

En la web, pulsa **Importar XMI** y elige `generated/Biblioteca.xmi`. Podrás
editar el diagrama, sus atributos y relaciones. Pulsa **Exportar XMI** para
descargar la revisión actual. En Enterprise Architect importa ese archivo como
XMI 2.1 dentro de un package. En sentido contrario, exporta un package desde EA
como XMI 2.1 y selecciónalo en **Importar XMI** de la web. No se abren archivos
`.eap`, `.eapx` o `.qea` directamente. Véase el [alcance verificado](enterprise-architect.md).

## Generar y probar Spring Boot

Tras descargar el XMI actualizado desde CASE, genera el backend desde ese
archivo (elige un directorio de salida vacío):

```powershell
& .\.venv\Scripts\python.exe scripts/generate-from-xmi.py `
  .\Biblioteca.xmi generated/biblioteca-desde-case
```

También puedes generar directamente el fixture JSON con `spring-generator`.
El backend generado usa PostgreSQL local, base `biblioteca`. Configura su
`.env` privado según el README generado, ejecuta `mvn test` y luego
`mvn spring-boot:run`. Si Veterinaria ocupa 8080, define `SERVER_PORT=8081`.
La prueba CRUD real se ejecuta con:

```powershell
& scripts/demo-biblioteca-smoke.ps1
```

La prueba crea un socio, un libro y un préstamo, verifica listado y actualización,
y elimina únicamente esos tres registros al finalizar. Se verificó en PostgreSQL
local y también con los tests H2 generados.

## Probar Flutter y el asistente

El build de Biblioteca selecciona su propia metadata generada y revela la
pantalla manual de Socios, Libros y Préstamos. El asistente usa ese mismo contrato
para interpretar las entidades; el reconocimiento y Gemma siguen siendo locales
en Android. Para el teléfono conectado por USB:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8081 tcp:8081
Set-Location mobile-client/flutter
flutter run `
  --dart-define=DEMO_DOMAIN=biblioteca `
  --dart-define=API_BASE_URL=http://127.0.0.1:8081
```

`flutter run` instalará esta variante sobre la app de desarrollo existente;
para volver a Veterinaria, compila sin `DEMO_DOMAIN` y con la URL de su backend.
Si Xiaomi cancela la instalación *streaming* pese a tener la opción USB activada,
usa `adb install -r --no-streaming build/app/outputs/flutter-apk/app-debug.apk`
después de compilar; esta variante se instaló correctamente así, conservando
los datos privados de la app.
Primero crea un socio y un libro, luego usa sus IDs al crear un préstamo. En el
asistente prueba «lista los socios» y «lista los libros». Para verificarlo sin
Internet, carga antes el modelo local y una consulta, activa modo avión y repite
la consulta; la sincronización offline usa la capa SQLite existente.

## Estado del simulacro

Verificados: ida y vuelta XMI, importación/exportación por API, backend generado
desde XMI, tests Maven, CRUD real en PostgreSQL, pantalla Flutter con prueba de
crear/editar/eliminar socio, suite Flutter, instalación y apertura en el Xiaomi.
Pendiente: probar manualmente CRUD y asistente Biblioteca en el teléfono, y los
simulacros Hotel/Universidad. No se afirma soporte
directo para archivos de repositorio EA ni equivalencia de todas las extensiones
propietarias de XMI.
