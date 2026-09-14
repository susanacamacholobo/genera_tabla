from pathlib import Path

import pytest

from case_backend.importers.xmi import XMIImporter, XMIImportError

FIXTURES = Path(__file__).parent / "fixtures" / "enterprise-architect"


def import_fixture(name: str):
    return XMIImporter().import_bytes((FIXTURES / name).read_bytes(), scope="ea15-fixtures")


def by_name(items: list[object], name: str):
    return next(item for item in items if item.name == name)


def assert_ea_identity(item: object) -> None:
    reference = item.external_references[0]
    assert reference.source == "enterprise-architect"
    assert reference.scope == "ea15-fixtures"
    assert reference.xmi_id.startswith(("EAID_", "EAPK_"))
    assert reference.guid.startswith("{")
    assert reference.package.name


def test_imports_real_single_class_fixture() -> None:
    model = import_fixture("01-single-class.xmi")

    assert model.name == "SingleClass"
    assert model.revision == 0
    assert [item.name for item in model.classes] == ["Cliente"]
    assert model.relationships == []
    assert model.enumerations == []
    assert_ea_identity(model)
    assert_ea_identity(model.classes[0])


def test_imports_attributes_types_nullability_and_primary_key() -> None:
    model = import_fixture("02-class-attributes.xmi")
    attributes = {item.name: item for item in model.classes[0].attributes}

    assert list(attributes) == ["id", "nombre", "telefono"]
    assert attributes["id"].data_type == "Long"
    assert attributes["id"].primary_key is True
    assert attributes["id"].nullable is False
    assert attributes["telefono"].nullable is True
    assert_ea_identity(attributes["id"])


def test_imports_one_to_many_association() -> None:
    model = import_fixture("03-one-to-many.xmi")
    relationship = model.relationships[0]
    names = {item.id: item.name for item in model.classes}

    assert relationship.type == "ASSOCIATION"
    assert names[relationship.source_class_id] == "Cliente"
    assert names[relationship.target_class_id] == "Mascota"
    assert relationship.source_multiplicity == "1"
    assert relationship.target_multiplicity == "0..*"
    assert relationship.target_role == "mascotas"
    assert_ea_identity(relationship)


def test_imports_generalization() -> None:
    model = import_fixture("04-inheritance.xmi")
    relationship = model.relationships[0]
    names = {item.id: item.name for item in model.classes}

    assert relationship.type == "GENERALIZATION"
    assert names[relationship.source_class_id] == "Cliente"
    assert names[relationship.target_class_id] == "Persona"
    assert relationship.source_multiplicity == "1"
    assert relationship.target_multiplicity == "1"


def test_imports_enumeration_and_classifier_type() -> None:
    model = import_fixture("05-enum.xmi")
    enumeration = model.enumerations[0]
    cliente = by_name(model.classes, "Cliente")

    assert enumeration.name == "EstadoCliente"
    assert enumeration.values == ["ACTIVO", "INACTIVO"]
    assert cliente.attributes[0].data_type == "EstadoCliente"
    assert_ea_identity(enumeration)


def test_imports_complete_fixture_and_diagram_positions() -> None:
    model = import_fixture("06-complete-veterinaria.xmi")
    cliente = by_name(model.classes, "Cliente")
    persona = by_name(model.classes, "Persona")

    assert len(model.classes) == 3
    assert len(model.enumerations) == 1
    assert len(model.relationships) == 2
    assert cliente.position.x == 320
    assert cliente.position.y == 50
    assert persona.position.x == 50
    assert persona.attributes[0].primary_key is True


@pytest.mark.parametrize(
    "content",
    [
        b"<root />",
        b'<xmi:XMI xmlns:xmi="urn:xmi" xmi:version="2.0" />',
        b'<!DOCTYPE x [<!ENTITY x "boom">]><x>&x;</x>',
    ],
)
def test_rejects_invalid_or_unsafe_xml(content: bytes) -> None:
    with pytest.raises(XMIImportError):
        XMIImporter().import_bytes(content)
