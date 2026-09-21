import json
from pathlib import Path

from case_backend.exporters.xmi import XMIExporter
from case_backend.importers.xmi import XMIImporter
from case_backend.schemas import CanonicalProjectModel

ROOT = Path(__file__).parents[3]
FIXTURES = Path(__file__).parent / "fixtures" / "enterprise-architect"


def by_name(items: list[object], name: str):
    return next(item for item in items if item.name == name)


def semantic_model(model: CanonicalProjectModel) -> dict[str, object]:
    class_names = {item.id: item.name for item in model.classes}
    return {
        "name": model.name,
        "classes": sorted(
            (
                item.name,
                item.position.x,
                item.position.y,
                sorted(
                    (
                        attribute.name,
                        attribute.data_type,
                        attribute.nullable,
                        attribute.unique,
                        attribute.primary_key,
                        attribute.default_value,
                    )
                    for attribute in item.attributes
                ),
            )
            for item in model.classes
        ),
        "enumerations": sorted((item.name, tuple(item.values)) for item in model.enumerations),
        "relationships": sorted(
            (
                item.type,
                class_names[item.source_class_id],
                class_names[item.target_class_id],
                item.source_multiplicity,
                item.target_multiplicity,
                item.source_role,
                item.target_role,
            )
            for item in model.relationships
        ),
    }


def test_export_is_deterministic_and_contains_ea_extension() -> None:
    source = CanonicalProjectModel.model_validate(
        json.loads((ROOT / "docs" / "examples" / "veterinaria.json").read_text())
    )
    exporter = XMIExporter()

    first = exporter.export_bytes(source)
    second = exporter.export_bytes(source)

    assert first == second
    assert b'xmi:version="2.1"' in first
    assert b'extender="Enterprise Architect"' in first
    assert b"project-veterinaria" not in first
    assert b"EAPK_" in first
    assert b"EAID_" in first


def test_generatabla_to_xmi_to_generatabla_is_semantically_equivalent() -> None:
    source = CanonicalProjectModel.model_validate(
        json.loads((ROOT / "docs" / "examples" / "veterinaria.json").read_text())
    )

    imported = XMIImporter().import_bytes(XMIExporter().export_bytes(source))

    assert semantic_model(imported) == semantic_model(source)


def test_biblioteca_demo_round_trip_preserves_domain_and_relationships() -> None:
    source = CanonicalProjectModel.model_validate(
        json.loads((ROOT / "docs" / "examples" / "biblioteca.json").read_text(encoding="utf-8"))
    )

    imported = XMIImporter().import_bytes(XMIExporter().export_bytes(source))

    assert semantic_model(imported) == semantic_model(source)
    assert {item.name for item in imported.classes} == {"Socio", "Libro", "Prestamo"}
    assert len(imported.relationships) == 2


def test_ea_to_generatabla_to_xmi_to_generatabla_preserves_meaning_and_identity() -> None:
    importer = XMIImporter()
    source = importer.import_bytes(
        (FIXTURES / "06-complete-veterinaria.xmi").read_bytes(), scope="ea15-fixture"
    )

    exported = XMIExporter().export_bytes(source, scope="ea15-fixture")
    round_trip = importer.import_bytes(exported, scope="ea15-fixture")

    assert semantic_model(round_trip) == semantic_model(source)
    for original in [*source.classes, *source.enumerations, *source.relationships]:
        if hasattr(original, "name"):
            restored = by_name(
                [*round_trip.classes, *round_trip.enumerations], original.name
            )
        else:
            original_reference = original.external_references[0]
            restored = next(
                item
                for item in round_trip.relationships
                if item.external_references[0].xmi_id == original_reference.xmi_id
            )
        assert restored.external_references[0].xmi_id == original.external_references[0].xmi_id
        assert restored.external_references[0].guid == original.external_references[0].guid


def test_export_preserves_default_values() -> None:
    source = XMIImporter().import_bytes(
        XMIExporter().export_bytes(
            CanonicalProjectModel.model_validate(
                {
                    "id": "defaults",
                    "name": "Defaults",
                    "revision": 0,
                    "classes": [
                        {
                            "id": "settings",
                            "name": "Settings",
                            "position": {"x": 10, "y": 20},
                            "attributes": [
                                {
                                    "id": "enabled",
                                    "name": "enabled",
                                    "dataType": "Boolean",
                                    "nullable": False,
                                    "unique": False,
                                    "primaryKey": False,
                                    "defaultValue": True,
                                }
                            ],
                        }
                    ],
                    "relationships": [],
                    "enumerations": [],
                }
            )
        )
    )

    assert source.classes[0].attributes[0].default_value is True
