# Simulacros Hotel y Universidad (fase 23)

Son dos dominios de prueba independientes. Sus clases, atributos y relaciones
están en [hotel.json](examples/hotel.json) y
[universidad.json](examples/universidad.json). Las pantallas Flutter se definieron
a mano; solo la infraestructura REST, el asistente y el almacenamiento offline
se reutilizan. No se genera la interfaz automáticamente desde UML.

## Intercambio CASE ↔ Enterprise Architect

La web permite importar y exportar XMI 2.1. Para cargar cualquiera de los
ejemplos, desde la raíz del repositorio:

```powershell
& .\.venv\Scripts\python.exe scripts/export-example-xmi.py docs/examples/hotel.json generated/hotel.xmi
& .\.venv\Scripts\python.exe scripts/export-example-xmi.py docs/examples/universidad.json generated/universidad.xmi
```

En la web pulsa **Importar XMI**. Después de editar, pulsa **Generar backend ZIP**
para descargar Spring desde la revisión guardada. También puedes exportar el
XMI y generar desde él mediante `scripts/generate-from-xmi.py`.
Enterprise Architect importa/exporta ese mismo formato; no se abren
directamente `.eap`, `.eapx` ni `.qea`. Los round-trips de ambos ejemplos están
cubiertos por pruebas de API y modelo.

## Backends y datos de ejemplo

Los backends generados están en `generated/hotel-demo` y
`generated/universidad-demo`. Usan las bases PostgreSQL locales `hotel` y
`universidad`, respectivamente, sin Docker. Las pruebas Maven y CRUD reales
pasaron en los puertos 8082 y 8083:

```powershell
& scripts/demo-hotel-smoke.ps1
& scripts/demo-universidad-smoke.ps1
```

Cada script crea sus propios registros, comprueba alta, listado y actualización,
y elimina únicamente esos registros. Para mantener el backend activo más tarde,
configura `DB_PASSWORD`, `DB_NAME` y `SERVER_PORT` según el README del proyecto
generado y ejecuta `mvn spring-boot:run` en su directorio.

## Probar Hotel en Android

Con el teléfono conectado por USB y el backend Hotel activo:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8082 tcp:8082
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r --no-streaming generated/hotel-demo.apk
```

Abre la app y pulsa **Abrir Hotel**. Crea un huésped `Ana Pérez`; después una
habitación `101` con precio por noche `120,50`. En **Reservas**, deja la
entrada vacía para usar hoy, escribe una fecha de salida posterior en formato
`AAAA-MM-DD` y usa los IDs que realmente aparezcan para el huésped y la
habitación. También puedes probar en el asistente «lista los
huéspedes» o «lista las reservas».

## Probar Universidad en Android

Esta APK reemplaza temporalmente la variante Hotel sin borrar los datos
privados de la app:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8083 tcp:8083
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r --no-streaming generated/universidad-demo.apk
```

Abre **Universidad**. Crea un estudiante `Luis Flores`, código `E-001`, y un
curso `Programación I`, código `C-001`. En **Matrículas**, usa los IDs mostrados
para estudiante y curso; la fecha puede quedar vacía para usar hoy. En el
asistente prueba «lista los estudiantes» o «lista las matrículas».

Las pantallas manuales llaman directamente a Spring y necesitan conexión con
el backend. Para comprobar el modo avión, usa el **asistente**: haz una consulta
con conexión para guardar la copia, desconecta el USB o retira el túnel ADB,
activa modo avión y repítela. Modo avión por sí solo no corta `adb reverse`.
El modelo de
IA y el reconocimiento de voz siguen en el teléfono; las escrituras offline
del asistente usan SQLite y se sincronizan al recuperar conexión.

## Estado

Completados: modelos UML, round-trip XMI/API, generación Spring desde XMI,
pruebas Maven, CRUD con PostgreSQL, pantallas móviles manuales, pruebas del
asistente con ambas metadata y compilación de las dos APK. La variante Hotel se
instaló y abrió en el Xiaomi con túnel USB a 8082; el usuario confirmó que
funcionó tanto conectado como después de desconectar el USB, sin acceso al
backend mediante ADB. Universidad se instaló y abrió en el mismo Xiaomi con
túnel USB a 8083. El usuario confirmó que el recorrido de prueba propuesto
para Universidad funcionó correctamente. Ambos simulacros quedan cerrados.
