# Demostración

El recorrido principal de aceptación ya puede hacerse desde la web CASE:

1. Inicia PostgreSQL local, el backend CASE y Vite según sus README.
2. Crea un proyecto `Veterinaria` y dibuja `Cliente`, `Mascota` y su relación
   `Cliente 1 — 0..* Mascota`. Cada clase necesita un `id: Long` como PK para
   poder generar Spring.
3. Con el proyecto seleccionado, pulsa **Generar backend ZIP**. Si falta algún
   dato, el editor muestra la ruta y el motivo; corrige el modelo y repite.
4. Extrae el ZIP, configura PostgreSQL local en su `.env`, ejecuta `mvn test`
   y luego `mvn spring-boot:run`. Prueba `POST` y `GET` de clientes y mascotas.
5. Usa `metadata/domain-model.json` en Flutter, configura `API_BASE_URL` y
   prueba una orden como «lista los clientes» en el asistente Android.

La [guía de Biblioteca](demo-biblioteca.md) y la de
[Hotel/Universidad](demo-hotel-universidad.md) contienen simulacros concretos.
Enterprise Architect intercambia XMI 2.1 en ambos sentidos, no archivos de
repositorio `.qea/.eap` directamente. Para demostrar desconexión real con ADB,
quita el túnel USB o desconecta el cable antes de activar modo avión. Se usa
PostgreSQL local; Docker no forma parte de este entorno.
