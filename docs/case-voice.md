# Probar la edición UML por voz en CASE

La herramienta CASE web permite dictar o escribir una petición específica,
revisar una propuesta y confirmarla. La IA sólo ayuda a interpretar una acción
acotada; no genera ni modifica un diagrama completo de forma autónoma. Esta IA
CASE es independiente de la IA local/offline del asistente Flutter Android.

## Arranque local (sin Docker)

Desde la raíz del repositorio, instala las dependencias si todavía no están:

```powershell
npm install
python -m venv .venv
& .\.venv\Scripts\python.exe -m pip install -e "case-tool/backend[dev]"
```

Configura `case-tool/backend/.env` con tu usuario y contraseña de PostgreSQL
local. No compartas ese archivo. La base `generatabla` debe existir. En una
terminal ejecuta:

```powershell
Set-Location case-tool/backend
& "..\..\.venv\Scripts\python.exe" -m alembic upgrade head
& "..\..\.venv\Scripts\python.exe" -m uvicorn case_backend.main:app --reload
```

En otra terminal, desde la raíz:

```powershell
npm run dev --workspace @software1/case-frontend
```

Abre la dirección que muestre Vite (normalmente `http://localhost:5173`). La
barra superior permite crear o seleccionar un proyecto. Espera a que el editor
indique **Sincronizado** antes de editar. Si el backend no responde, la página
ofrece el ejemplo Veterinaria como demo, pero sus cambios no se guardan.

## Probar voz, texto y colaboración

1. Crea un proyecto y pulsa **🎤 Dictar**. Concede permiso de micrófono al
   navegador, di «crea clase Cliente» y revisa la transcripción en **Comando**.
   Puedes corregir el texto antes de enviarlo.
2. Pulsa **Revisar propuesta**. Nada cambia todavía. Pulsa **Confirmar cambio**;
   espera a **Sincronizado**. Si no quieres el cambio, pulsa **Cancelar**.
3. Prueba «agrega nombre String a Cliente», «crea clase Pedido» y «relaciona
   Cliente con Pedido uno a muchos». También puedes escribir esas frases sin
   micrófono. Para eliminar: «elimina Cliente» muestra cuántos atributos y
   relaciones desaparecerán antes de confirmar.
4. Usa **Deshacer** y **Rehacer**. Recarga la página o abre el mismo proyecto
   en otra pestaña: la revisión confirmada debe conservarse y aparecer allí.

El parser por reglas reconoce además renombrar clases o atributos, cambiar el
tipo de un atributo, eliminar atributos y cambiar los extremos, tipo o
multiplicidad de una relación, además de eliminarla. Por ejemplo: «cambia
destino de relación Cliente con Pedido a Factura». Si
hay dos relaciones entre las mismas clases, pedirá seleccionar una en el
diagrama en lugar de adivinar.

El dictado usa el reconocimiento disponible en el navegador. Puede no existir
en algunos navegadores y puede enviar audio a un servicio del proveedor del
navegador; la página lo advierte. Escribir comandos siempre sigue disponible.

## IA CASE opcional

Para interpretar peticiones menos rígidas o pedir una mejora concreta, configura
estas variables en el archivo privado `case-tool/backend/.env` y reinicia la
API:

```dotenv
CASE_AI_CHAT_URL=https://tu-proveedor/v1/chat/completions
CASE_AI_MODEL=tu-modelo
CASE_AI_API_KEY=tu-clave
```

Se admite un endpoint compatible con Chat Completions. Para un servicio local,
se permite HTTP sólo en `localhost`, `127.0.0.1` o `::1`; para un proveedor
remoto se exige HTTPS. La clave queda en el backend. Al estar configurado,
aparece **IA asistida** junto a **Reglas**. Elegir IA y revisar una propuesta
envía la instrucción y el contexto UML del proyecto al proveedor configurado.
La UI advierte si éste es remoto. La respuesta debe ser JSON con exactamente
una acción; el usuario siempre confirma antes de ejecutar. Una sugerencia puede
incluir un motivo y suposiciones visibles. Si la solicitud es ambigua, se pide
aclaración y no se crea una revisión.

No se necesita IA para los comandos de ejemplo: **Reglas** es el modo
predeterminado. La IA local obligatoria para el producto móvil es otra
integración y no se configura aquí.

## Verificación automática

```powershell
npm test --workspace @software1/case-frontend
npm run lint --workspace @software1/case-frontend
npm run build --workspace @software1/case-frontend
& .\.venv\Scripts\python.exe -m pytest case-tool/backend
& .\.venv\Scripts\python.exe -m ruff check case-tool/backend
```

Con la API levantada, `case-tool/backend/scripts/smoke_collaboration.py`
comprueba dos participantes y una revisión persistida contra PostgreSQL local.
La prueba crea y elimina sólo su propio proyecto temporal.
