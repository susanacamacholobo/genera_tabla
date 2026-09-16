# Comandos de texto para el editor CASE

La fase 7 incorpora `NaturalLanguageCommandParser` como interfaz estable y
`RuleBasedCommandParser` como su primera implementación. El parser no usa IA,
red ni heurísticas probabilísticas: una misma entrada y un mismo proyecto
producen el mismo tipo de comando o el mismo error.

## Gramática

| Intención | Formas aceptadas | Comando |
| --- | --- | --- |
| Crear clase | `crea clase Cliente`, `crear una clase Cliente` | `ADD_CLASS` |
| Agregar atributo | `agrega nombre String a Cliente` | `ADD_ATTRIBUTE` |
| Eliminar clase | `elimina Cliente`, `borra la clase Cliente` | `DELETE_CLASS` |
| Renombrar clase | `renombra clase Cliente a Persona` | `RENAME_CLASS` |
| Renombrar atributo | `renombra atributo nombre de Cliente a nombreCompleto` | `UPDATE_ATTRIBUTE` |
| Cambiar tipo | `cambia tipo del atributo edad de Cliente a Integer` | `UPDATE_ATTRIBUTE` |
| Eliminar atributo | `elimina atributo nombre de Cliente` | `DELETE_ATTRIBUTE` |
| Crear relación | `relaciona Cliente con Pedido uno a muchos` | `ADD_RELATIONSHIP` |
| Cambiar multiplicidad | `cambia multiplicidad de Cliente con Pedido a uno a uno` | `UPDATE_RELATIONSHIP` |
| Cambiar extremo | `cambia destino de relación Cliente con Pedido a Factura` | `UPDATE_RELATIONSHIP` |
| Cambiar tipo de relación | `cambia tipo de relación Cliente con Pedido a generalización` | `UPDATE_RELATIONSHIP` |
| Eliminar relación | `elimina relación entre Cliente con Pedido` | `DELETE_RELATIONSHIP` |

También se aceptan `añade`/`añadir`, la preposición `en`, diferencias de
mayúsculas y espacios adicionales. Los nombres con espacios pueden escribirse
entre comillas, por ejemplo:

```text
añade "fecha entrega" Date a "Orden de compra"
```

Los tipos incorporados se normalizan a su escritura canónica: `string` se
convierte en `String`, `decimal` en `Decimal`, etc. También pueden utilizarse
nombres de clases, enumeraciones o tipos personalizados.

## Resolución y ejecución

Para agregar atributos o eliminar clases, el parser busca el nombre de clase
sin distinguir mayúsculas. El resultado contiene el ID interno estable; los
nombres nunca reemplazan las identidades del modelo.

```text
texto
  -> RuleBasedCommandParser
  -> Command
  -> CommandValidator
  -> CommandHistory
  -> ProjectModel
```

Por eso los comandos escritos participan automáticamente en undo/redo y en el
contador de revisión. Las validaciones de nombres duplicados, referencias y
estructura siguen perteneciendo al dominio.

## Errores

El resultado distingue `EMPTY_INPUT`, `UNKNOWN_COMMAND`, `INVALID_NAME` y
`CLASS_NOT_FOUND`. Los errores del parser no cambian el proyecto. Si el texto
produce un comando válido sintácticamente pero el dominio lo rechaza, la UI
muestra el `CommandValidationError` existente.

## Parser con LLM local

La fase 15 añade `LocalLLMCommandParser`. Recibe un `LocalLLMProvider`
intercambiable y convierte su texto de salida en el mismo `CommandParseResult`
asíncrono que usa el parser por reglas. Pese a los nombres actuales, CASE no
requiere un runtime local: la fase 20.5 conectó un proveedor remoto o local
compatible con Chat Completions desde el backend. Las pruebas usan un proveedor
fake y no hacen llamadas externas.

El prompt incluye sólo el contexto UML necesario y exige exactamente una acción
JSON. Se permite una sola acción acotada entre:

```text
ADD_CLASS
ADD_ATTRIBUTE
DELETE_CLASS
RENAME_CLASS
UPDATE_ATTRIBUTE
DELETE_ATTRIBUTE
ADD_RELATIONSHIP
UPDATE_RELATIONSHIP
DELETE_RELATIONSHIP
```

La respuesta se considera entrada no confiable. El adaptador rechaza JSON
inválido, Markdown, múltiples acciones, operaciones fuera de la lista y tipos
incorrectos. Además, ignora cualquier ID propuesto por el modelo: resuelve los
nombres contra el proyecto y genera los IDs internamente.

```text
texto
  -> LocalLLMProvider
  -> JSON restringido
  -> LocalLLMCommandParser
  -> CommandValidator
  -> CommandHistory
  -> ProjectModel
```

`DiagramEditor.commandParser` permite inyectar esta implementación. Mientras
espera una respuesta asíncrona, la barra desactiva la entrada y evita envíos
duplicados. El parser por reglas sigue siendo el valor predeterminado, de modo
que ejecutar el editor no requiere tener un modelo instalado.

Esta IA pertenece a la herramienta CASE web/de escritorio y puede requerir
Internet. Es distinta del asistente Flutter: el modelo que debe ejecutarse
localmente en el teléfono Android se integra mediante `LocalAIProvider` en la
fase 20.
