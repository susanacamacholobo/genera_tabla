import re
from dataclasses import dataclass
from typing import Any
from uuid import uuid4
from xml.etree.ElementTree import Element, ParseError

from defusedxml.common import DefusedXmlException
from defusedxml.ElementTree import fromstring

from case_backend.importers.xmi.errors import XMIImportError
from case_backend.schemas import CanonicalProjectModel

EA_SOURCE = "enterprise-architect"
EA_GUID_PATTERN = re.compile(
    r"^(?:EAID|EAPK)_([0-9A-Fa-f]{8})_([0-9A-Fa-f]{4})_"
    r"([0-9A-Fa-f]{4})_([0-9A-Fa-f]{4})_([0-9A-Fa-f]{12})$"
)


def local_name(value: str) -> str:
    return value.rsplit("}", 1)[-1].split(":")[-1]


def attribute(element: Element, name: str, default: str | None = None) -> str | None:
    for key, value in element.attrib.items():
        if local_name(key) == name:
            return value
    return default


def child(element: Element, name: str) -> Element | None:
    return next((item for item in element if local_name(item.tag) == name), None)


def type_name(element: Element) -> str:
    return local_name(attribute(element, "type", "") or "")


def guid_from_xmi_id(xmi_id: str | None) -> str | None:
    if not xmi_id:
        return None
    match = EA_GUID_PATTERN.fullmatch(xmi_id)
    if match is None:
        return None
    return "{" + "-".join(match.groups()).upper() + "}"


def boolean(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes"}


def multiplicity(lower: str | None, upper: str | None) -> str:
    if lower is None and upper in {"0..1", "1", "0..*", "1..*"}:
        return upper
    normalized_upper = "*" if upper in {"-1", "*"} else (upper or "1")
    normalized_lower = lower or ("0" if normalized_upper == "*" else "1")
    value = normalized_lower if normalized_lower == normalized_upper else (
        f"{normalized_lower}..{normalized_upper}"
    )
    if value not in {"0..1", "1", "0..*", "1..*"}:
        raise XMIImportError(f"La multiplicidad XMI '{value}' no está soportada.")
    return value


def end_multiplicity(end: Element) -> str:
    lower_node = child(end, "lowerValue")
    upper_node = child(end, "upperValue")
    lower = attribute(lower_node, "value") if lower_node is not None else None
    upper = attribute(upper_node, "value") if upper_node is not None else None
    return multiplicity(lower, upper)


def scalar(value: str | None, data_type: str) -> object | None:
    if value in {None, ""}:
        return None
    if data_type in {"Integer", "Long"}:
        try:
            return int(value)
        except ValueError:
            return value
    if data_type in {"Double", "Decimal"}:
        try:
            return float(value)
        except ValueError:
            return value
    if data_type == "Boolean":
        return value.lower() == "true"
    return value


def normalize_data_type(value: str | None) -> str:
    if not value:
        return "String"
    aliases = {
        "string": "String",
        "int": "Integer",
        "integer": "Integer",
        "long": "Long",
        "real": "Double",
        "double": "Double",
        "decimal": "Decimal",
        "boolean": "Boolean",
        "date": "Date",
        "datetime": "DateTime",
        "uuid": "UUID",
    }
    return aliases.get(value.lower(), value)


@dataclass(frozen=True)
class PackageIdentity:
    name: str
    xmi_id: str | None
    guid: str | None

    def json(self) -> dict[str, str]:
        result = {"name": self.name}
        if self.xmi_id:
            result["xmiId"] = self.xmi_id
        if self.guid:
            result["guid"] = self.guid
        return result


@dataclass(frozen=True)
class RawElement:
    node: Element
    kind: str
    package: PackageIdentity


class XMIImporter:
    """Map Enterprise Architect XMI 2.1 into the UI-independent canonical model."""

    def import_bytes(self, content: bytes, *, scope: str | None = None) -> CanonicalProjectModel:
        try:
            root = fromstring(content)
        except (ParseError, DefusedXmlException) as error:
            raise XMIImportError("El archivo no contiene XML seguro y válido.") from error

        if local_name(root.tag) != "XMI":
            raise XMIImportError("El elemento raíz debe ser xmi:XMI.")
        version = attribute(root, "version")
        if version != "2.1":
            raise XMIImportError(f"Se requiere XMI 2.1; se recibió '{version or 'sin versión'}'.")

        model = next((item for item in root if local_name(item.tag) == "Model"), None)
        if model is None:
            raise XMIImportError("El documento XMI no contiene un uml:Model.")

        extension = self._enterprise_architect_extension(root)
        extension_elements, extension_attributes = self._extension_elements(extension)
        extension_connectors = self._extension_connectors(extension)
        positions = self._diagram_positions(extension)

        root_package = next(
            (
                item
                for item in model
                if local_name(item.tag) == "packagedElement" and type_name(item) == "Package"
            ),
            None,
        )
        container = root_package if root_package is not None else model
        package_name = attribute(container, "name", attribute(model, "name", "ImportedModel"))
        package_xmi_id = attribute(container, "id")
        package_identity = PackageIdentity(
            name=package_name or "ImportedModel",
            xmi_id=package_xmi_id,
            guid=self._guid(package_xmi_id, extension_elements),
        )
        document_scope = scope or package_identity.guid or package_xmi_id or str(uuid4())

        raw_elements: list[RawElement] = []
        self._collect_elements(container, package_identity, raw_elements, extension_elements)
        classifiers = [item for item in raw_elements if item.kind in {"Class", "Enumeration"}]
        internal_ids = {
            attribute(item.node, "id"): str(uuid4())
            for item in classifiers
            if attribute(item.node, "id")
        }
        classifier_names = {
            attribute(item.node, "id"): attribute(item.node, "name")
            for item in classifiers
            if attribute(item.node, "id")
        }
        classifier_names.update(self._primitive_types(root))

        classes: list[dict[str, Any]] = []
        enumerations: list[dict[str, Any]] = []
        class_index = 0
        for item in classifiers:
            xmi_id = attribute(item.node, "id")
            name = attribute(item.node, "name")
            if not xmi_id or not name:
                raise XMIImportError("Toda clase y enumeración debe tener xmi:id y nombre.")
            external_references = [
                self._external_reference(
                    xmi_id,
                    document_scope,
                    item.package,
                    extension_elements.get(xmi_id, {}).get("guid"),
                )
            ]
            if item.kind == "Enumeration":
                values = [
                    attribute(value, "name")
                    for value in item.node
                    if local_name(value.tag) in {"ownedLiteral", "ownedAttribute"}
                    and attribute(value, "name")
                ]
                enumerations.append(
                    {
                        "id": internal_ids[xmi_id],
                        "name": name,
                        "values": values,
                        "externalReferences": external_references,
                    }
                )
                continue

            imported_attributes = []
            for owned in item.node:
                if local_name(owned.tag) != "ownedAttribute":
                    continue
                imported = self._import_attribute(
                    owned,
                    document_scope,
                    item.package,
                    classifier_names,
                    extension_attributes,
                )
                imported_attributes.append(imported)

            position = positions.get(xmi_id)
            if position is None:
                position = {
                    "x": 120 + (class_index % 3) * 320,
                    "y": 120 + (class_index // 3) * 240,
                }
            class_index += 1
            classes.append(
                {
                    "id": internal_ids[xmi_id],
                    "name": name,
                    "position": position,
                    "attributes": imported_attributes,
                    "externalReferences": external_references,
                }
            )

        relationships = self._relationships(
            raw_elements,
            internal_ids,
            document_scope,
            extension_elements,
            extension_connectors,
        )
        project_id = str(uuid4())
        project_reference = self._external_reference(
            package_xmi_id,
            document_scope,
            package_identity,
            package_identity.guid,
        )
        return CanonicalProjectModel.model_validate(
            {
                "id": project_id,
                "name": package_identity.name,
                "revision": 0,
                "classes": classes,
                "relationships": relationships,
                "enumerations": enumerations,
                "externalReferences": [project_reference],
            }
        )

    @staticmethod
    def _enterprise_architect_extension(root: Element) -> Element | None:
        return next(
            (
                item
                for item in root
                if local_name(item.tag) == "Extension"
                and (attribute(item, "extender", "") or "").lower() == "enterprise architect"
            ),
            None,
        )

    @staticmethod
    def _extension_elements(
        extension: Element | None,
    ) -> tuple[dict[str, dict[str, str]], dict[str, dict[str, str]]]:
        elements: dict[str, dict[str, str]] = {}
        attributes: dict[str, dict[str, str]] = {}
        if extension is None:
            return elements, attributes
        container = child(extension, "elements")
        if container is None:
            return elements, attributes
        for element in container:
            if local_name(element.tag) != "element":
                continue
            xmi_id = attribute(element, "idref")
            if not xmi_id:
                continue
            elements[xmi_id] = {"guid": guid_from_xmi_id(xmi_id) or ""}
            attributes_node = child(element, "attributes")
            if attributes_node is None:
                continue
            for item in attributes_node:
                attribute_id = attribute(item, "idref")
                if not attribute_id:
                    continue
                model = child(item, "model")
                properties = child(item, "properties")
                initial = child(item, "initial")
                xrefs = child(item, "xrefs")
                attributes[attribute_id] = {
                    "guid": (
                        attribute(model, "ea_guid") if model is not None else None
                    )
                    or guid_from_xmi_id(attribute_id)
                    or "",
                    "type": (
                        attribute(properties, "type") if properties is not None else None
                    )
                    or "",
                    "initial": (
                        attribute(initial, "value") if initial is not None else None
                    )
                    or "",
                    "xrefs": (attribute(xrefs, "value") if xrefs is not None else None)
                    or "",
                }
        return elements, attributes

    @staticmethod
    def _extension_connectors(extension: Element | None) -> dict[str, Element]:
        if extension is None:
            return {}
        container = child(extension, "connectors")
        if container is None:
            return {}
        return {
            xmi_id: item
            for item in container
            if local_name(item.tag) == "connector"
            and (xmi_id := attribute(item, "idref")) is not None
        }

    @staticmethod
    def _diagram_positions(extension: Element | None) -> dict[str, dict[str, float]]:
        positions: dict[str, dict[str, float]] = {}
        if extension is None:
            return positions
        diagrams = child(extension, "diagrams")
        if diagrams is None:
            return positions
        for diagram in diagrams:
            elements = child(diagram, "elements")
            if elements is None:
                continue
            for item in elements:
                subject = attribute(item, "subject")
                geometry = attribute(item, "geometry", "") or ""
                values = dict(re.findall(r"(Left|Top|Right|Bottom)=(-?\d+(?:\.\d+)?)", geometry))
                if subject and "Left" in values and "Top" in values and subject not in positions:
                    positions[subject] = {"x": float(values["Left"]), "y": float(values["Top"])}
        return positions

    def _collect_elements(
        self,
        container: Element,
        package: PackageIdentity,
        result: list[RawElement],
        extension_elements: dict[str, dict[str, str]],
    ) -> None:
        for item in container:
            if local_name(item.tag) != "packagedElement":
                continue
            kind = type_name(item)
            if kind == "Package":
                xmi_id = attribute(item, "id")
                nested_package = PackageIdentity(
                    name=attribute(item, "name", package.name) or package.name,
                    xmi_id=xmi_id,
                    guid=self._guid(xmi_id, extension_elements),
                )
                self._collect_elements(item, nested_package, result, extension_elements)
            elif kind in {"Class", "Enumeration", "Association"}:
                result.append(RawElement(item, kind, package))

    @staticmethod
    def _primitive_types(root: Element) -> dict[str, str]:
        result: dict[str, str] = {}
        for item in root.iter():
            if local_name(item.tag) == "packagedElement" and type_name(item) in {
                "PrimitiveType",
                "DataType",
            }:
                xmi_id = attribute(item, "id")
                name = attribute(item, "name")
                if xmi_id and name:
                    result[xmi_id] = name
        return result

    def _import_attribute(
        self,
        owned: Element,
        scope: str,
        package: PackageIdentity,
        classifier_names: dict[str | None, str | None],
        extension_attributes: dict[str, dict[str, str]],
    ) -> dict[str, Any]:
        xmi_id = attribute(owned, "id")
        name = attribute(owned, "name")
        if not xmi_id or not name:
            raise XMIImportError("Todo atributo debe tener xmi:id y nombre.")
        extension = extension_attributes.get(xmi_id, {})
        type_node = child(owned, "type")
        type_reference = attribute(type_node, "idref") if type_node is not None else None
        raw_type = extension.get("type") or classifier_names.get(type_reference)
        data_type = normalize_data_type(raw_type)
        lower_node = child(owned, "lowerValue")
        lower = attribute(lower_node, "value") if lower_node is not None else "1"
        default_node = child(owned, "defaultValue")
        default = (
            attribute(default_node, "value") if default_node is not None else None
        ) or extension.get("initial")
        result: dict[str, Any] = {
            "id": str(uuid4()),
            "name": name,
            "dataType": data_type,
            "nullable": lower == "0",
            "unique": boolean(attribute(owned, "isUnique")),
            "primaryKey": bool(re.search(r"@NAME=isID.*?@VALU=1", extension.get("xrefs", ""))),
            "externalReferences": [
                self._external_reference(xmi_id, scope, package, extension.get("guid"))
            ],
        }
        default_value = scalar(default, data_type)
        if default_value is not None:
            result["defaultValue"] = default_value
        return result

    def _relationships(
        self,
        raw_elements: list[RawElement],
        internal_ids: dict[str | None, str],
        scope: str,
        extension_elements: dict[str, dict[str, str]],
        extension_connectors: dict[str, Element],
    ) -> list[dict[str, Any]]:
        relationships: list[dict[str, Any]] = []
        for item in raw_elements:
            if item.kind == "Association":
                relationships.append(
                    self._association(
                        item,
                        internal_ids,
                        scope,
                        extension_elements,
                        extension_connectors,
                    )
                )
            if item.kind != "Class":
                continue
            source_xmi_id = attribute(item.node, "id")
            for generalization in item.node:
                if local_name(generalization.tag) != "generalization":
                    continue
                target_xmi_id = attribute(generalization, "general")
                relationship_xmi_id = attribute(generalization, "id")
                if source_xmi_id not in internal_ids or target_xmi_id not in internal_ids:
                    raise XMIImportError("Una generalización referencia una clase externa.")
                relationships.append(
                    {
                        "id": str(uuid4()),
                        "type": "GENERALIZATION",
                        "sourceClassId": internal_ids[source_xmi_id],
                        "targetClassId": internal_ids[target_xmi_id],
                        "sourceMultiplicity": "1",
                        "targetMultiplicity": "1",
                        "externalReferences": [
                            self._external_reference(
                                relationship_xmi_id,
                                scope,
                                item.package,
                                self._guid(relationship_xmi_id, extension_elements),
                            )
                        ],
                    }
                )
        return relationships

    def _association(
        self,
        item: RawElement,
        internal_ids: dict[str | None, str],
        scope: str,
        extension_elements: dict[str, dict[str, str]],
        extension_connectors: dict[str, Element],
    ) -> dict[str, Any]:
        xmi_id = attribute(item.node, "id")
        connector = extension_connectors.get(xmi_id or "")
        source_xmi_id: str | None = None
        target_xmi_id: str | None = None
        source_multiplicity = "1"
        target_multiplicity = "1"
        source_role: str | None = None
        target_role: str | None = None
        if connector is not None:
            source = child(connector, "source")
            target = child(connector, "target")
            if source is not None and target is not None:
                source_xmi_id = attribute(source, "idref")
                target_xmi_id = attribute(target, "idref")
                source_type = child(source, "type")
                target_type = child(target, "type")
                source_role_node = child(source, "role")
                target_role_node = child(target, "role")
                source_multiplicity = multiplicity(
                    None,
                    attribute(source_type, "multiplicity") if source_type is not None else "1",
                )
                target_multiplicity = multiplicity(
                    None,
                    attribute(target_type, "multiplicity") if target_type is not None else "1",
                )
                source_role = (
                    attribute(source_role_node, "name") if source_role_node is not None else None
                )
                target_role = (
                    attribute(target_role_node, "name") if target_role_node is not None else None
                )
        if source_xmi_id is None or target_xmi_id is None:
            ends = [end for end in item.node if local_name(end.tag) == "ownedEnd"]
            if len(ends) != 2:
                raise XMIImportError("Una asociación debe contener exactamente dos extremos.")
            target_end, source_end = ends
            source_type = child(source_end, "type")
            target_type = child(target_end, "type")
            source_xmi_id = attribute(source_type, "idref") if source_type is not None else None
            target_xmi_id = attribute(target_type, "idref") if target_type is not None else None
            source_multiplicity = end_multiplicity(source_end)
            target_multiplicity = end_multiplicity(target_end)
            source_role = attribute(source_end, "name")
            target_role = attribute(target_end, "name")
        if source_xmi_id not in internal_ids or target_xmi_id not in internal_ids:
            raise XMIImportError("Una asociación referencia una clase externa.")
        result: dict[str, Any] = {
            "id": str(uuid4()),
            "type": "ASSOCIATION",
            "sourceClassId": internal_ids[source_xmi_id],
            "targetClassId": internal_ids[target_xmi_id],
            "sourceMultiplicity": source_multiplicity,
            "targetMultiplicity": target_multiplicity,
            "externalReferences": [
                self._external_reference(
                    xmi_id,
                    scope,
                    item.package,
                    self._guid(xmi_id, extension_elements),
                )
            ],
        }
        if source_role:
            result["sourceRole"] = source_role
        if target_role:
            result["targetRole"] = target_role
        return result

    @staticmethod
    def _guid(
        xmi_id: str | None, extension_elements: dict[str, dict[str, str]]
    ) -> str | None:
        return extension_elements.get(xmi_id or "", {}).get("guid") or guid_from_xmi_id(xmi_id)

    @staticmethod
    def _external_reference(
        xmi_id: str | None,
        scope: str,
        package: PackageIdentity,
        guid: str | None,
    ) -> dict[str, Any]:
        result: dict[str, Any] = {
            "source": EA_SOURCE,
            "scope": scope,
            "package": package.json(),
        }
        if xmi_id:
            result["xmiId"] = xmi_id
        if guid:
            result["guid"] = guid
        return result
