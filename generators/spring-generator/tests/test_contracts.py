import json
from typing import Any

from spring_generator import SpringGenerator
from spring_generator.mapping import SpringModelMapper


def test_generates_openapi_from_request_and_response_contracts(
    simple_entity_model: dict[str, Any],
) -> None:
    generated = SpringGenerator().generate(simple_entity_model)
    contract = json.loads(generated.files["openapi/openapi.json"])

    assert contract["openapi"] == "3.1.0"
    assert contract["info"]["title"] == "Veterinaria API"
    assert contract["paths"]["/api/clientes"]["get"]["operationId"] == "listCliente"
    assert contract["paths"]["/api/clientes"]["post"]["responses"]["400"] == {
        "description": "Solicitud inválida",
        "content": {
            "application/json": {
                "schema": {"$ref": "#/components/schemas/ApiError"}
            }
        },
    }
    request = contract["components"]["schemas"]["ClienteRequest"]
    response = contract["components"]["schemas"]["ClienteResponse"]
    assert request["required"] == ["nombre", "fechaRegistro"]
    assert request["properties"]["saldo"]["type"] == ["number", "null"]
    assert "id" not in request["properties"]
    assert response["properties"]["id"] == {
        "type": "integer",
        "format": "int64",
        "x-unique": True,
        "readOnly": True,
    }


def test_generates_domain_metadata_for_flutter(
    simple_entity_model: dict[str, Any],
) -> None:
    generated = SpringGenerator().generate(simple_entity_model)
    metadata = json.loads(generated.files["metadata/domain-model.json"])

    assert metadata["schemaVersion"] == "1.0.0"
    assert metadata["application"] == "Veterinaria"
    assert metadata["artifactId"] == "veterinaria"
    assert metadata["entities"][0]["endpoint"] == "/api/clientes"
    assert metadata["entities"][0]["fields"][0] == {
        "name": "id",
        "type": "Long",
        "required": True,
        "generated": True,
        "unique": True,
    }


def test_relationship_contracts_use_ids_without_nested_entities(
    association_model: dict[str, Any],
) -> None:
    generated = SpringGenerator().generate(association_model)
    openapi = json.loads(generated.files["openapi/openapi.json"])
    metadata = json.loads(generated.files["metadata/domain-model.json"])
    project = SpringModelMapper().map(association_model)
    metadata_by_name = {item["name"]: item for item in metadata["entities"]}

    for entity in project.entities:
        request = openapi["components"]["schemas"][f"{entity.class_name}Request"]
        response = openapi["components"]["schemas"][f"{entity.class_name}Response"]
        relationships = {
            item["apiField"]: item
            for item in metadata_by_name[entity.class_name]["relationships"]
        }
        for association in entity.associations:
            assert association.request_name in response["properties"]
            assert (association.request_name in request["properties"]) is association.owning
            assert relationships[association.request_name]["targetEntity"] == (
                association.target_class_name
            )
            assert relationships[association.request_name]["writable"] is association.owning
