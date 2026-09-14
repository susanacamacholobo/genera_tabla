from copy import deepcopy
from typing import Any

import pytest

from spring_generator.mapping import SpringModelMapper


def test_maps_canonical_names_and_types(simple_entity_model: dict[str, Any]) -> None:
    project = SpringModelMapper().map(simple_entity_model)

    assert project.artifact_id == "veterinaria"
    assert project.database_name == "veterinaria"
    assert project.package_name == "com.example.veterinaria"
    assert project.application_class == "VeterinariaApplication"
    assert project.springdoc_version == "3.1.1"
    entity = project.entities[0]
    assert entity.class_name == "Cliente"
    assert entity.table_name == "clientes"
    assert entity.endpoint_name == "clientes"
    assert entity.id_field.java_type == "Long"
    assert entity.id_field.canonical_type == "Long"
    assert entity.imports == ("java.math.BigDecimal", "java.time.LocalDateTime")
    assert entity.test_request_body == (
        '{"nombre":"example","saldo":7.5,"fechaRegistro":"2026-01-15T10:30:00"}'
    )


def test_rejects_an_invalid_java_group_id() -> None:
    with pytest.raises(ValueError, match="Group ID inválido"):
        SpringModelMapper(group_id="com.example.invalid-package")


def test_maps_canonical_multiplicities_to_bidirectional_jpa_kinds(
    association_model: dict[str, Any],
) -> None:
    project = SpringModelMapper().map(association_model)
    relationship = project.relationships[0]
    expected = {
        "Identidad": ("ONE_TO_ONE", "ONE_TO_ONE"),
        "Veterinaria Relaciones": ("ONE_TO_MANY", "MANY_TO_ONE"),
        "Academia": ("MANY_TO_MANY", "MANY_TO_MANY"),
    }

    assert (relationship.source_kind, relationship.target_kind) == expected[
        association_model["name"]
    ]
    source = next(item for item in project.entities if item.class_name == relationship.source_class_name)
    target = next(item for item in project.entities if item.class_name == relationship.target_class_name)
    source_field = next(item for item in source.associations if item.name == relationship.source_field_name)
    target_field = next(item for item in target.associations if item.name == relationship.target_field_name)
    assert source_field.opposite_name == target_field.name
    assert target_field.opposite_name == source_field.name
    assert source_field.request_name.endswith("Ids" if source_field.collection else "Id")
    assert target_field.request_name.endswith("Ids" if target_field.collection else "Id")


def test_required_many_to_one_is_not_standalone_creatable(
    association_model: dict[str, Any],
) -> None:
    project = SpringModelMapper().map(association_model)

    if association_model["name"] == "Veterinaria Relaciones":
        mascota = next(item for item in project.entities if item.class_name == "Mascota")
        assert not mascota.standalone_creatable
        cliente = next(item for item in mascota.writable_associations if item.name == "cliente")
        assert cliente.request_name == "clienteId"
        assert cliente.request_java_type == "Long"
        assert cliente.required


def test_maps_many_to_one_when_many_end_is_the_source(
    one_to_many_model: dict[str, Any],
) -> None:
    model = deepcopy(one_to_many_model)
    relationship = model["relationships"][0]
    relationship.update(
        {
            "sourceClassId": "class-mascota",
            "targetClassId": "class-cliente",
            "sourceMultiplicity": "0..*",
            "targetMultiplicity": "1",
            "sourceRole": "mascotas",
            "targetRole": "cliente",
        }
    )

    mapped = SpringModelMapper().map(model).relationships[0]

    assert mapped.source_kind == "MANY_TO_ONE"
    assert mapped.target_kind == "ONE_TO_MANY"
