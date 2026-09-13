from typing import Any

import pytest

from spring_generator.mapping import SpringModelMapper


def test_maps_canonical_names_and_types(simple_entity_model: dict[str, Any]) -> None:
    project = SpringModelMapper().map(simple_entity_model)

    assert project.artifact_id == "veterinaria"
    assert project.database_name == "veterinaria"
    assert project.package_name == "com.example.veterinaria"
    assert project.application_class == "VeterinariaApplication"
    entity = project.entities[0]
    assert entity.class_name == "Cliente"
    assert entity.table_name == "clientes"
    assert entity.endpoint_name == "clientes"
    assert entity.id_field.java_type == "Long"
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


def test_required_many_to_one_is_not_standalone_creatable(
    association_model: dict[str, Any],
) -> None:
    project = SpringModelMapper().map(association_model)

    if association_model["name"] == "Veterinaria Relaciones":
        mascota = next(item for item in project.entities if item.class_name == "Mascota")
        assert not mascota.standalone_creatable
