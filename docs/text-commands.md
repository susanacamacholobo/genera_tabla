# Comandos de texto deterministas

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

La interfaz está preparada para una implementación futura
`LocalLLMCommandParser`, que deberá devolver exactamente los mismos comandos y
no acceder directamente al estado del editor.
