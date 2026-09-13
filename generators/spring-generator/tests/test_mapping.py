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


def test_rejects_an_invalid_java_group_id() -> None:
    with pytest.raises(ValueError, match="Group ID inválido"):
        SpringModelMapper(group_id="com.example.invalid-package")
