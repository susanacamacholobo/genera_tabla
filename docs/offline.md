# Operación offline

La fase 22 permite que el asistente Flutter Android siga trabajando cuando el
backend Spring Boot no está disponible. Voz, interpretación con Gemma y datos
locales permanecen dentro del dispositivo; no dependen de servicios cloud.

## Estrategia local-first

`OfflineDataCoordinator` intenta primero la operación REST. Si hay un error de
red:

- las consultas leen la última copia SQLite guardada;
- crear, editar y eliminar modifica inmediatamente la copia local;
- cada escritura se añade a una cola persistente en orden FIFO;
- la interfaz muestra modo sin conexión y el total pendiente.

Las respuestas HTTP de error (por ejemplo 400 o 409) no se confunden con una
desconexión. Cuando el servidor vuelve a estar disponible, el siguiente comando
intenta sincronizar automáticamente. También aparece un botón para hacerlo de
forma manual. Los identificadores temporales negativos se reemplazan por el ID
asignado por PostgreSQL, incluso en cambios posteriores que dependan del
registro recién creado.

## Prueba física recomendada

1. Con Spring Boot activo, consulta `lista los clientes` para llenar la copia
   local.
2. Detén Spring Boot o desconecta el teléfono de la computadora.
3. Repite la consulta: debe aparecer `Modo sin conexión` y `datos locales`.
4. Dicta o escribe una creación válida. Debe indicarse `Cambio guardado sin
   conexión` y mostrarse un cambio pendiente.
5. Reconecta el teléfono, restablece `adb reverse tcp:8080 tcp:8080` y arranca
   Spring Boot.
6. Pulsa el icono de sincronización. El estado debe cambiar a `Conectado al
   servidor` y el contador pendiente desaparecer.

Este recorrido se verificó en un Xiaomi Android: el dictado y Gemma funcionaron
en modo avión, la consulta leyó SQLite y una creación pendiente se confirmó en
PostgreSQL local tras restablecer la conexión.

La herramienta CASE web tiene otra frontera: puede utilizar proveedores de voz
o IA remotos y no tiene el requisito de funcionar sin Internet.
