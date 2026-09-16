# Fase 20.5 — Edición UML asistida por voz en CASE

Esta fase se ejecutará antes de la fase 21 del asistente Flutter. Pertenece a
la herramienta CASE web, no al cliente móvil ni al backend Spring generado.

## Objetivo

Permitir que el usuario pida por voz o texto cambios específicos sobre el
diagrama actual. La IA interpreta, propone y explica; el usuario decide. No
genera un diagrama entero ni realiza cambios autónomos.

```text
voz/texto → transcripción revisable → parser/IA configurable
          → propuesta acotada → validación y vista previa
          → confirmación → comando canónico → persistencia/colaboración
```

## Alcance funcional

- Crear, renombrar y eliminar clases.
- Agregar, editar y eliminar atributos (nombre, tipo y propiedades).
- Crear, editar y eliminar relaciones (extremos, tipo y multiplicidades).
- Sugerir mejoras de nombres, tipos o relaciones sólo a petición del usuario y
  presentarlas como propuestas con sus suposiciones. Pedir aclaración si una
  instrucción es ambigua.
- Mostrar el efecto antes de aplicarlo; confirmar o cancelar explícitamente.
  Las eliminaciones requieren una advertencia clara.
- Aplicar los cambios confirmados mediante `CommandValidator` y
  `CommandHistory`, con deshacer/rehacer.
- Persistir los comandos en el backend CASE y propagar el resultado a otras
  sesiones con las reglas existentes de revisión y conflictos.

## Restricciones

La voz y la IA de CASE podrán usar un proveedor remoto o local; CASE no necesita
funcionar sin Internet. La UI debe indicar si el audio o el contexto UML se
enviarán fuera del equipo. Las credenciales de un proveedor remoto quedan en
el backend o una configuración privada, nunca en el frontend ni en Git. La
entrada de texto y el parser por reglas seguirán disponibles cuando el
proveedor de IA o de voz no lo esté.

La IA sólo devuelve JSON estructurado con una acción permitida; no controla IDs
internos, método HTTP, rutas ni ejecución. Los nombres y referencias se
resuelven contra el modelo canónico actual y una respuesta inválida nunca
modifica el diagrama. La IA de Flutter Android sí requiere funcionamiento local
y offline; es una frontera distinta.

## Criterios de aceptación

1. Se pueden dictar, revisar, confirmar y deshacer instrucciones como «crea la
   clase Cliente», «agrega nombre String a Cliente», «relaciona Cliente con
   Pedido uno a muchos» y «elimina Cliente».
2. Voz y texto producen el mismo comando canónico para una misma instrucción.
3. El cambio confirmado se conserva tras recargar y aparece en otra sesión.
4. Ambigüedad, referencias inexistentes, JSON inválido o un proveedor no
   disponible producen una explicación sin crear revisiones ni eventos.
5. Pruebas automatizadas cubren transcripción, interpretación, vista previa,
   confirmación, validación, undo/redo, persistencia y colaboración. La ruta
   escrita por reglas se prueba sin depender de servicios externos.

La fase 21 retomará después el flujo de voz → intención REST en Flutter. Son
funciones independientes: los comandos CASE editan UML; el asistente móvil
consulta o modifica datos mediante la API Spring Boot.
