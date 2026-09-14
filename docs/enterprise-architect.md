# Interoperabilidad con Enterprise Architect

## Alcance y frontera arquitectónica

La integración con Sparx Systems Enterprise Architect usa importación y
exportación bidireccional mediante **XMI 2.1**. GeneraTabla no lee ni modifica
directamente archivos `.eap`, `.eapx` o `.qea` y el dominio no contendrá tipos
específicos como `EAClass` o `EAAttribute`.

```text
Enterprise Architect -> XMI -> XMIImporter -> Canonical Model
Canonical Model -> XMIExporter -> XMI -> Enterprise Architect
```

Los adaptadores viven en `importers/xmi` y `exporters/xmi`. La fase 14 implementa
ambas fronteras sin introducir dependencias de Sparx Systems en el modelo
canónico.

## Enterprise Architect → GeneraTabla

1. El usuario crea o abre un modelo en Enterprise Architect.
2. Exporta un Package como XMI 2.1.
3. Sube el archivo `.xmi` a `POST /projects/xmi/import`.
4. `XMIImporter` procesa el archivo.
5. El adaptador lo convierte al modelo canónico y genera IDs internos nuevos.
6. El modelo queda persistido como snapshot 0 y disponible para el editor.
7. Puede editarse y colaborar sobre las revisiones siguientes cuando la UI use
   el adaptador HTTP/WebSocket.

## GeneraTabla → Enterprise Architect

1. El usuario crea o modifica el modelo en GeneraTabla.
2. Descarga `GET /projects/{project_id}/xmi`.
3. `XMIExporter` genera XMI 2.1 determinísticamente.
4. El usuario importa el XMI en Enterprise Architect.
5. Aparecen las clases, atributos, enumeraciones y relaciones.

## Identidad externa y round-trip

Los IDs internos de GeneraTabla siguen siendo opacos, estables y globalmente
únicos dentro del proyecto. Nunca se reemplazan por un GUID o `xmi:id` externo.
`ClassModel`, `AttributeModel`, `RelationshipModel`, `EnumerationModel` y
`ProjectModel` pueden incluir opcionalmente `externalReferences`:

```json
{
  "source": "enterprise-architect",
  "scope": "veterinaria-repository",
  "externalId": "optional-tool-id",
  "guid": "{4F9C6750-6298-4FC8-A312-F71953B10A67}",
  "xmiId": "EAID_4F9C6750_6298_4FC8_A312_F71953B10A67",
  "package": {
    "name": "Modelo de dominio",
    "guid": "{70E3B025-C983-44F4-8AD9-6282E516730F}"
  }
}
```

Es una colección para permitir más de un origen sin añadir propiedades de
Enterprise Architect a cada interfaz. `source` selecciona el adaptador y
`scope` distingue repositorios o documentos cuando el identificador sólo es
único dentro de ellos. Al menos uno de `externalId`, `guid` o `xmiId` debe estar
presente. Los identificadores externos se conservan literalmente y no usan las
reglas sintácticas del ID interno.

En una importación, el adaptador genera el ID interno B y conserva el GUID A. Al
reexportar, busca primero una identidad estable (normalmente GUID)
y después los demás identificadores dentro de su `source` y `scope`. Así podrá
actualizar el elemento original en lugar de duplicarlo. Para elementos creados
en GeneraTabla, el exportador deriva GUID y `xmi:id` estables a partir del ID
interno; al reimportarlos, esas identidades quedan guardadas como referencias
externas.

Los dos objetivos son:

```text
Enterprise Architect -> GeneraTabla -> modificar -> Enterprise Architect
GeneraTabla -> Enterprise Architect -> modificar -> GeneraTabla
```

## Packages y layout

No se introduce todavía un árbol de packages en el dominio. La pertenencia
externa mínima se conserva dentro de la referencia correspondiente mediante
nombre e identificadores opcionales del package. Esto alcanza para reconstruir
o localizar el contenedor durante el round-trip sin imponer la estructura de
Enterprise Architect al editor. Si los requisitos futuros incluyen edición de
packages, se diseñará un concepto UML genérico separado.

`Position {x, y}` ya pertenece al modelo canónico y no depende de React Flow.
Permitirá el mapeo:

```text
Enterprise Architect diagram coordinates
                 <-> Position <-> React Flow coordinates
```

El importador toma `Left` y `Top` del primer diagrama que contiene cada clase. El
exportador escribe una geometría determinista y EA restaura el diagrama. La
posición geométrica no conserva estilos, rutas de conectores ni múltiples
diagramas.

## Alcance implementado

- UML Class.
- UML Property / Attribute.
- UML Enumeration.
- UML Association.
- UML Generalization.
- Multiplicidades `0..1`, `1`, `0..*` y `1..*`.
- Posiciones, pertenencia mínima a package e identificadores externos.

No se promete soporte para toda la especificación UML ni para todas las
extensiones propietarias de Enterprise Architect.

## Acceptance tests ejecutados

### Test A — Enterprise Architect → GeneraTabla

Superado con los seis fixtures reales: se verificaron clases, atributos, tipos,
relaciones y multiplicidades.

### Test B — GeneraTabla → Enterprise Architect

Superado con `docs/examples/veterinaria.json`: EA importó 2 clases, 6 atributos,
1 asociación y 1 diagrama.

### Test C — Enterprise Architect → GeneraTabla → Enterprise Architect

Superado: una segunda importación en EA mantuvo 1 package, 4 clasificadores y 1
diagrama, reutilizando las identidades externas sin duplicados.

### Test D — GeneraTabla → Enterprise Architect → GeneraTabla

Superado: EA reexportó el ejemplo de GeneraTabla y el importador recuperó 2
clases, 6 atributos y 1 relación con equivalencia semántica.

## Fixtures reales

Los tests se basan en archivos exportados por Enterprise Architect 15.0 build
1514, almacenados en
`case-tool/backend/tests/fixtures/enterprise-architect/`:

```text
01-single-class.xmi
02-class-attributes.xmi
03-one-to-many.xmi
04-inheritance.xmi
05-enum.xmi
06-complete-veterinaria.xmi
```

Los seis archivos se generaron en una copia descartable de `EABase.eap` y no se
editaron después. Además de las pruebas automatizadas, el XMI producido por
GeneraTabla se importó directamente en EA 15: se verificaron GUIDs, tipos, clave
primaria, asociación, generalización, multiplicidades, roles y diagrama. Una
segunda importación conservó un solo package y cuatro elementos, sin duplicados.

## API y seguridad

`POST /projects/xmi/import` recibe `multipart/form-data`, crea un proyecto nuevo
y guarda el modelo importado como snapshot 0. El parámetro opcional `scope`
distingue el repositorio/documento de origen. `GET /projects/{id}/xmi` exporta
la revisión actual con nombre de descarga UTF-8.

La carga máxima es 5 MiB. `defusedxml` rechaza DTDs y expansiones de entidades;
un documento inválido responde `422` y uno demasiado grande responde `413`.

## Riesgos conocidos

- Enterprise Architect puede agregar extensiones propietarias y variar su XMI
  según versión, perfil y opciones de exportación.
- `xmi:id` puede ser local al documento; por eso existe `scope` y se prefiere un
  GUID estable cuando esté disponible.
- La preservación de layout depende de datos reales presentes en los fixtures y
  puede no incluir estilos, rutas de conectores o múltiples diagramas.
- Renombrar no rompe identidad, pero borrar y recrear un elemento externamente
  puede producir una identidad nueva que requerirá una política de merge.
- El mapeo de tipos UML deberá distinguir tipos primitivos, enumeraciones y
  nombres calificados no observados todavía en los fixtures.
- Los packages anidados se importan conservando metadata de pertenencia, pero se
  aplanan al exportar porque el modelo canónico no contiene un árbol editable.

## Extensión fuera del MVP

Enterprise Architect ofrece una Automation Interface. En el futuro podría
existir un adaptador Windows para sincronización directa, pero no forma parte
del MVP: el requisito actual se satisface con XMI 2.1 bidireccional.
