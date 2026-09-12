# Interoperabilidad con Enterprise Architect

## Alcance y frontera arquitectónica

La primera integración con Sparx Systems Enterprise Architect será importación y
exportación bidireccional mediante **XMI 2.1**. GeneraTabla no leerá ni modificará
directamente archivos `.eap`, `.eapx` o `.qea` y el dominio no contendrá tipos
específicos como `EAClass` o `EAAttribute`.

```text
Enterprise Architect -> XMI -> XMIImporter -> Canonical Model
Canonical Model -> XMIExporter -> XMI -> Enterprise Architect
```

Los adaptadores futuros vivirán en las fronteras `importers/xmi` y
`exporters/xmi`. En la fase 2.5 sólo se preparan esas fronteras; todavía no hay
parser ni serializador XMI.

## Enterprise Architect → GeneraTabla

1. El usuario crea o abre un modelo en Enterprise Architect.
2. Exporta un Package como XMI 2.1.
3. Sube el archivo `.xmi` a GeneraTabla.
4. `XMIImporter` procesa el archivo.
5. El adaptador lo convierte al modelo canónico y genera IDs internos nuevos.
6. El modelo aparece en el editor.
7. Puede editarse colaborativamente.

## GeneraTabla → Enterprise Architect

1. El usuario crea o modifica el modelo en GeneraTabla.
2. Selecciona la futura acción **Export to Enterprise Architect**.
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

En una importación futura, el adaptador generará el ID interno B y conservará el
GUID A. Al reexportar, buscará primero una identidad estable (normalmente GUID)
y después los demás identificadores dentro de su `source` y `scope`. Así podrá
actualizar el elemento original en lugar de duplicarlo. Los elementos creados
en GeneraTabla no necesitan metadata; el exportador generará su identidad XMI y
la persistirá cuando se implemente esa fase.

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

La conversión de coordenadas, orientación de ejes, tamaño y unidades queda en
el adaptador XMI futuro. La posición geométrica por sí sola no promete conservar
todo el estilo visual de un diagrama de Enterprise Architect.

## Alcance mínimo de la fase XMI

- UML Class.
- UML Property / Attribute.
- UML Enumeration.
- UML Association.
- UML Generalization.
- Multiplicidades `0..1`, `1`, `0..*` y `1..*`.
- Cuando el dialecto real lo permita: posiciones, pertenencia a packages e
  identificadores externos.

No se promete soporte para toda la especificación UML ni para todas las
extensiones propietarias de Enterprise Architect.

## Acceptance tests futuros

### Test A — Enterprise Architect → GeneraTabla

Importar XMI real y verificar clases, atributos, tipos, relaciones y
multiplicidades.

### Test B — GeneraTabla → Enterprise Architect

Exportar e importar en Enterprise Architect y verificar los mismos elementos.

### Test C — Enterprise Architect → GeneraTabla → Enterprise Architect

Verificar que no aparezcan clases duplicadas, que se reutilicen las identidades
externas y que el modelo conserve su significado.

### Test D — GeneraTabla → Enterprise Architect → GeneraTabla

Verificar equivalencia semántica, ignorando diferencias de orden o presentación
que no pertenezcan al contrato soportado.

## Fixtures reales

Los tests se basarán en archivos exportados por la versión concreta de
Enterprise Architect utilizada en el proyecto, almacenados en
`case-tool/backend/tests/fixtures/enterprise-architect/`:

```text
01-single-class.xmi
02-class-attributes.xmi
03-one-to-many.xmi
04-inheritance.xmi
05-enum.xmi
06-complete-veterinaria.xmi
```

No se inventará un dialecto XMI a partir de la especificación general.

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
  nombres calificados observados en XMI real.

## Extensión fuera del MVP

Enterprise Architect ofrece una Automation Interface. En el futuro podría
existir un adaptador Windows para sincronización directa, pero no forma parte
del MVP: el requisito actual se satisface con XMI 2.1 bidireccional.

