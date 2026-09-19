# Intenciones del asistente Flutter

La fase 18 define una frontera segura entre el futuro LLM local de Android y la
API Spring Boot. El LLM interpreta lenguaje natural, pero no elige URLs ni
ejecuta peticiones. Su única salida admitida es un objeto JSON:

```json
{
  "operation": "CREATE_ENTITY",
  "entity": "Cliente",
  "parameters": {
    "nombre": "Ana",
    "fechaRegistro": "2026-09-14T10:30:00-04:00"
  }
}
```

Las únicas propiedades raíz son `operation`, `entity`, `identifier` y
`parameters`. Los parámetros aceptan valores escalares o listas de escalares;
se rechazan Markdown, JSON mal formado, objetos anidados, operaciones y
propiedades adicionales.

## Operaciones

| Intención | Requisitos | Operación resuelta |
| --- | --- | --- |
| `CREATE_ENTITY` | cuerpo completo sin ID generado | `POST {endpoint}` |
| `GET_ENTITY` | identificador | `GET {endpoint}/{id}` |
| `LIST_ENTITIES` | sin identificador ni parámetros | `GET {endpoint}` |
| `UPDATE_ENTITY` | identificador y cuerpo completo | `PUT {endpoint}/{id}` |
| `DELETE_ENTITY` | identificador | `DELETE {endpoint}/{id}` |
| `SEARCH_ENTITY` | al menos un filtro | `GET {endpoint}` y filtro local |

La actualización requiere un cuerpo completo porque los DTOs `PUT` generados
usan el mismo contrato obligatorio que la creación. Una relación múltiple puede
buscarse por un único ID; el filtro comprueba si ese ID está contenido en la
lista devuelta por la API. El texto se compara sin distinguir mayúsculas y por
coincidencia parcial.

## Validación

Antes de usar `ApiClient`, `IntentValidator` comprueba:

- que la entidad y cada campo o relación existan en `domain-model.json`;
- que las operaciones sobre un elemento incluyan un ID del tipo correcto;
- que no se escriban IDs generados ni relaciones de sólo lectura;
- que estén presentes los campos y relaciones obligatorios;
- que los valores correspondan a `String`, `Integer`, `Long`, `Double`,
  `Decimal`, `Boolean`, `Date`, `DateTime` o `UUID`;
- que cada operación utilice únicamente los parámetros que admite.

`ApiOperationResolver` toma el endpoint exclusivamente de la metadata validada.
El modelo no puede inyectar un método, host o ruta. Los errores de formato,
validación y runtime local son tipados y muestran mensajes seguros.

## Alcance actual

`FakeLocalAIProvider` verifica el flujo completo en pruebas sin red de IA. La
fase 19 añade reconocimiento de voz local, la fase 20 incorpora LiteRT-LM en
Android y la fase 21 conecta `AssistantPanel` con el modelo, la validación y la
API REST. Para probar este flujo:

```powershell
cd mobile-client/flutter
flutter analyze
flutter test test/ai
```
