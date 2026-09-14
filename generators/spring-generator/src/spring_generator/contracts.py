import json
from typing import Any

from spring_generator.mapping import JavaAssociation, JavaEntity, JavaField, SpringProject

OPENAPI_TYPES: dict[str, tuple[str, str | None]] = {
    "String": ("string", None),
    "Integer": ("integer", "int32"),
    "Long": ("integer", "int64"),
    "Double": ("number", "double"),
    "Decimal": ("number", None),
    "Boolean": ("boolean", None),
    "Date": ("string", "date"),
    "DateTime": ("string", "date-time"),
    "UUID": ("string", "uuid"),
}


def json_document(value: dict[str, Any]) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def build_domain_model(project: SpringProject) -> dict[str, Any]:
    return {
        "schemaVersion": "1.0.0",
        "application": project.display_name,
        "artifactId": project.artifact_id,
        "basePath": "/api",
        "entities": [_domain_entity(entity) for entity in project.entities],
    }


def build_openapi(project: SpringProject) -> dict[str, Any]:
    paths: dict[str, Any] = {}
    schemas: dict[str, Any] = {}
    for entity in project.entities:
        collection_path = f"/api/{entity.endpoint_name}"
        item_path = f"{collection_path}/{{id}}"
        paths[collection_path] = _collection_operations(entity)
        paths[item_path] = _item_operations(entity)
        schemas[f"{entity.class_name}Request"] = _request_schema(entity)
        schemas[f"{entity.class_name}Response"] = _response_schema(entity)
    schemas["ApiError"] = _error_schema()
    return {
        "openapi": "3.1.0",
        "info": {
            "title": f"{project.display_name} API",
            "version": "0.0.1",
            "description": "API REST generada de forma determinista por GeneraTabla.",
        },
        "servers": [{"url": "http://localhost:8080"}],
        "tags": [
            {"name": entity.class_name, "description": f"CRUD de {entity.class_name}"}
            for entity in project.entities
        ],
        "paths": paths,
        "components": {"schemas": schemas},
    }


def _domain_entity(entity: JavaEntity) -> dict[str, Any]:
    return {
        "name": entity.class_name,
        "endpoint": f"/api/{entity.endpoint_name}",
        "idField": entity.id_field.name,
        "fields": [
            {
                "name": field.name,
                "type": field.canonical_type,
                "required": not field.nullable,
                "generated": field.primary_key,
                "unique": field.unique,
            }
            for field in entity.fields
        ],
        "relationships": [_domain_relationship(item) for item in entity.associations],
    }


def _domain_relationship(association: JavaAssociation) -> dict[str, Any]:
    return {
        "name": association.name,
        "apiField": association.request_name,
        "targetEntity": association.target_class_name,
        "kind": association.kind,
        "many": association.collection,
        "required": association.required,
        "writable": association.owning,
    }


def _collection_operations(entity: JavaEntity) -> dict[str, Any]:
    return {
        "get": {
            "tags": [entity.class_name],
            "operationId": f"list{entity.class_name}",
            "summary": f"Listar {entity.class_name}",
            "responses": {
                "200": _json_response(
                    "Listado obtenido",
                    {
                        "type": "array",
                        "items": _reference(f"{entity.class_name}Response"),
                    },
                )
            },
        },
        "post": {
            "tags": [entity.class_name],
            "operationId": f"create{entity.class_name}",
            "summary": f"Crear {entity.class_name}",
            "requestBody": _request_body(entity),
            "responses": {
                "201": _json_response(
                    "Recurso creado", _reference(f"{entity.class_name}Response")
                ),
                "400": _error_response("Solicitud inválida"),
                "404": _error_response("ID relacionado inexistente"),
                "409": _error_response("Conflicto de integridad"),
            },
        },
    }


def _item_operations(entity: JavaEntity) -> dict[str, Any]:
    parameter = {
        "name": "id",
        "in": "path",
        "required": True,
        "description": f"Identificador de {entity.class_name}",
        "schema": _field_schema(entity.id_field, nullable=False),
    }
    return {
        "get": {
            "tags": [entity.class_name],
            "operationId": f"get{entity.class_name}",
            "summary": f"Obtener {entity.class_name}",
            "parameters": [parameter],
            "responses": {
                "200": _json_response(
                    "Recurso encontrado", _reference(f"{entity.class_name}Response")
                ),
                "404": _error_response("Recurso inexistente"),
            },
        },
        "put": {
            "tags": [entity.class_name],
            "operationId": f"update{entity.class_name}",
            "summary": f"Actualizar {entity.class_name}",
            "parameters": [parameter],
            "requestBody": _request_body(entity),
            "responses": {
                "200": _json_response(
                    "Recurso actualizado", _reference(f"{entity.class_name}Response")
                ),
                "400": _error_response("Solicitud inválida"),
                "404": _error_response("Recurso o relación inexistente"),
                "409": _error_response("Conflicto de integridad"),
            },
        },
        "delete": {
            "tags": [entity.class_name],
            "operationId": f"delete{entity.class_name}",
            "summary": f"Eliminar {entity.class_name}",
            "parameters": [parameter],
            "responses": {
                "204": {"description": "Recurso eliminado"},
                "404": _error_response("Recurso inexistente"),
                "409": _error_response("Conflicto de integridad"),
            },
        },
    }


def _request_schema(entity: JavaEntity) -> dict[str, Any]:
    properties: dict[str, Any] = {}
    required: list[str] = []
    for field in entity.mutable_fields:
        properties[field.name] = _field_schema(field, nullable=field.nullable)
        if not field.nullable:
            required.append(field.name)
    for association in entity.writable_associations:
        properties[association.request_name] = _association_schema(
            association, nullable=not association.required
        )
        if association.required:
            required.append(association.request_name)
    schema: dict[str, Any] = {
        "type": "object",
        "additionalProperties": False,
        "properties": properties,
    }
    if required:
        schema["required"] = required
    return schema


def _response_schema(entity: JavaEntity) -> dict[str, Any]:
    properties: dict[str, Any] = {
        field.name: _field_schema(
            field, nullable=field.nullable and not field.primary_key
        )
        for field in entity.fields
    }
    properties.update(
        {
            association.request_name: _association_schema(
                association, nullable=not association.collection and not association.required
            )
            for association in entity.associations
        }
    )
    return {
        "type": "object",
        "additionalProperties": False,
        "properties": properties,
        "required": list(properties),
    }


def _field_schema(field: JavaField, nullable: bool) -> dict[str, Any]:
    openapi_type, openapi_format = OPENAPI_TYPES[field.canonical_type]
    schema: dict[str, Any] = {
        "type": [openapi_type, "null"] if nullable else openapi_type
    }
    if openapi_format is not None:
        schema["format"] = openapi_format
    if field.unique:
        schema["x-unique"] = True
    if field.primary_key:
        schema["readOnly"] = True
    return schema


def _association_schema(
    association: JavaAssociation, nullable: bool
) -> dict[str, Any]:
    openapi_type, openapi_format = OPENAPI_TYPES[
        "Integer" if association.target_id_java_type == "Integer" else "Long"
    ]
    item_schema: dict[str, Any] = {"type": openapi_type, "format": openapi_format}
    if association.collection:
        schema: dict[str, Any] = {
            "type": "array",
            "uniqueItems": True,
            "items": item_schema,
        }
        if association.required:
            schema["minItems"] = 1
        return schema
    return {
        "type": [openapi_type, "null"] if nullable else openapi_type,
        "format": openapi_format,
    }


def _request_body(entity: JavaEntity) -> dict[str, Any]:
    return {
        "required": True,
        "content": {
            "application/json": {
                "schema": _reference(f"{entity.class_name}Request")
            }
        },
    }


def _json_response(description: str, schema: dict[str, Any]) -> dict[str, Any]:
    return {
        "description": description,
        "content": {"application/json": {"schema": schema}},
    }


def _error_response(description: str) -> dict[str, Any]:
    return _json_response(description, _reference("ApiError"))


def _reference(schema_name: str) -> dict[str, str]:
    return {"$ref": f"#/components/schemas/{schema_name}"}


def _error_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time"},
            "status": {"type": "integer", "format": "int32"},
            "error": {"type": "string"},
            "message": {"type": "string"},
            "path": {"type": "string"},
            "fieldErrors": {
                "type": "object",
                "additionalProperties": {"type": "string"},
            },
        },
        "required": [
            "timestamp",
            "status",
            "error",
            "message",
            "path",
            "fieldErrors",
        ],
    }
