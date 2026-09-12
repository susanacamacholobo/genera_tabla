# Modelo canónico

El modelo se define en `case-tool/frontend/src/domain/model/types.ts` y no tiene
dependencias de UI.

## ProjectModel

Contiene `id`, `name`, `revision`, `classes`, `relationships` y `enumerations`.
La revisión inicia en cero y aumenta con cada comando ejecutado.

## ClassModel y Position

Una clase tiene identificador, nombre, posición `{x, y}` y atributos. La
posición forma parte del modelo porque debe persistirse y colaborar, aunque su
interpretación visual corresponda al adaptador.

## AttributeModel

Define nombre, tipo, nulabilidad, unicidad, clave primaria y valor por defecto
opcional. Tipos incorporados:

`String`, `Integer`, `Long`, `Double`, `Decimal`, `Boolean`, `Date`, `DateTime`
y `UUID`. El nombre de una `EnumerationModel` también puede usarse como tipo.

## RelationshipModel

Soporta `ASSOCIATION` y `GENERALIZATION`, referencias por ID, roles opcionales y
multiplicidades `0..1`, `1`, `0..*` y `1..*`. La multiplicidad se nombra desde
el extremo donde aparece: `sourceMultiplicity` y `targetMultiplicity`.

## Validación

`validateProject` devuelve todas las incidencias encontradas, con código, ruta
y mensaje legible. Comprueba:

- IDs vacíos, inválidos o repetidos;
- nombres vacíos o repetidos sin distinguir mayúsculas;
- coordenadas y revisión válidas;
- tipos de atributo conocidos;
- enumeraciones no vacías y sin valores duplicados;
- claves primarias no anulables;
- extremos, tipo y multiplicidad de relaciones;
- autorreferencias y ciclos de generalización.

La validación para generar Spring será más estricta y se agregará en su fase.
Un ejemplo serializado está en `docs/examples/veterinaria.json`.

