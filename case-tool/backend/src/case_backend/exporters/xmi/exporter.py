from dataclasses import dataclass
from pathlib import Path
from uuid import NAMESPACE_URL, UUID, uuid5
from xml.etree.ElementTree import Element, SubElement, indent, register_namespace, tostring

from case_backend.importers.xmi.importer import EA_SOURCE, guid_from_xmi_id
from case_backend.schemas.model_history import (
    AttributeModel,
    CanonicalProjectModel,
    ClassModel,
    EnumerationModel,
    RelationshipModel,
)

XMI_NAMESPACE = "http://schema.omg.org/spec/XMI/2.1"
UML_NAMESPACE = "http://schema.omg.org/spec/UML/2.1"
XMI_TYPE = f"{{{XMI_NAMESPACE}}}type"
XMI_ID = f"{{{XMI_NAMESPACE}}}id"
XMI_IDREF = f"{{{XMI_NAMESPACE}}}idref"

register_namespace("xmi", XMI_NAMESPACE)
register_namespace("uml", UML_NAMESPACE)


@dataclass(frozen=True)
class XMIIdentity:
    xmi_id: str
    guid: str


def generated_uuid(value: str, purpose: str = "element") -> UUID:
    return uuid5(NAMESPACE_URL, f"https://generatabla.local/xmi/{purpose}/{value}")


def identity_from_uuid(value: UUID, prefix: str) -> XMIIdentity:
    guid = "{" + str(value).upper() + "}"
    return XMIIdentity(f"{prefix}_{str(value).replace('-', '_').upper()}", guid)


def xmi_id_from_guid(guid: str, prefix: str) -> str:
    normalized = guid.strip("{}").replace("-", "_")
    return f"{prefix}_{normalized}"


def text_bool(value: bool) -> str:
    return "true" if value else "false"


def bounds(value: str) -> tuple[str, str]:
    if value == "1":
        return "1", "1"
    lower, upper = value.split("..", 1)
    return lower, "-1" if upper == "*" else upper


def literal_type(data_type: str) -> str:
    if data_type in {"Integer", "Long"}:
        return "LiteralInteger"
    if data_type in {"Double", "Decimal"}:
        return "LiteralReal"
    if data_type == "Boolean":
        return "LiteralBoolean"
    return "LiteralString"


def scalar_text(value: object) -> str:
    if isinstance(value, bool):
        return text_bool(value)
    return str(value)


class XMIExporter:
    """Serialize the canonical model as deterministic EA-compatible XMI 2.1."""

    def export_file(
        self,
        model: CanonicalProjectModel,
        path: str | Path,
        *,
        scope: str | None = None,
    ) -> None:
        Path(path).write_bytes(self.export_bytes(model, scope=scope))

    def export_bytes(
        self, model: CanonicalProjectModel, *, scope: str | None = None
    ) -> bytes:
        self._scope = scope
        self._identities: dict[str, XMIIdentity] = {}
        project_identity = self._identity(model, "EAPK", "package")
        for uml_class in model.classes:
            self._identity(uml_class, "EAID")
            for attribute in uml_class.attributes:
                self._identity(attribute, "EAID")
        for enumeration in model.enumerations:
            self._identity(enumeration, "EAID")
        for relationship in model.relationships:
            self._identity(relationship, "EAID")

        root = Element(
            f"{{{XMI_NAMESPACE}}}XMI",
            {f"{{{XMI_NAMESPACE}}}version": "2.1"},
        )
        SubElement(
            root,
            f"{{{XMI_NAMESPACE}}}Documentation",
            {"exporter": "Enterprise Architect", "exporterVersion": "6.5"},
        )
        uml_model = SubElement(
            root,
            f"{{{UML_NAMESPACE}}}Model",
            {XMI_TYPE: "uml:Model", "name": "EA_Model", "visibility": "public"},
        )
        package = SubElement(
            uml_model,
            "packagedElement",
            {
                XMI_TYPE: "uml:Package",
                XMI_ID: project_identity.xmi_id,
                "name": model.name,
                "visibility": "public",
            },
        )
        self._standard_model(package, model)

        extension = SubElement(
            root,
            f"{{{XMI_NAMESPACE}}}Extension",
            {"extender": "Enterprise Architect", "extenderID": "6.5"},
        )
        self._extension(extension, model, project_identity)
        indent(root, space="\t")
        return tostring(root, encoding="utf-8", xml_declaration=True)

    def _standard_model(self, package: Element, model: CanonicalProjectModel) -> None:
        relationships_by_source: dict[str, list[RelationshipModel]] = {}
        for relationship in model.relationships:
            relationships_by_source.setdefault(relationship.source_class_id, []).append(relationship)

        for uml_class in sorted(model.classes, key=lambda item: (item.name.casefold(), item.id)):
            class_identity = self._identities[uml_class.id]
            node = SubElement(
                package,
                "packagedElement",
                {
                    XMI_TYPE: "uml:Class",
                    XMI_ID: class_identity.xmi_id,
                    "name": uml_class.name,
                    "visibility": "public",
                },
            )
            for attribute in sorted(
                uml_class.attributes, key=lambda item: (item.name.casefold(), item.id)
            ):
                self._standard_attribute(node, attribute, model)
            for relationship in sorted(
                relationships_by_source.get(uml_class.id, []), key=lambda item: item.id
            ):
                if relationship.type != "GENERALIZATION":
                    continue
                relationship_identity = self._identities[relationship.id]
                target_identity = self._identities[relationship.target_class_id]
                SubElement(
                    node,
                    "generalization",
                    {
                        XMI_TYPE: "uml:Generalization",
                        XMI_ID: relationship_identity.xmi_id,
                        "general": target_identity.xmi_id,
                    },
                )

        for relationship in sorted(model.relationships, key=lambda item: item.id):
            if relationship.type == "ASSOCIATION":
                self._standard_association(package, relationship)

        for enumeration in sorted(
            model.enumerations, key=lambda item: (item.name.casefold(), item.id)
        ):
            identity = self._identities[enumeration.id]
            node = SubElement(
                package,
                "packagedElement",
                {
                    XMI_TYPE: "uml:Enumeration",
                    XMI_ID: identity.xmi_id,
                    "name": enumeration.name,
                    "visibility": "public",
                },
            )
            for index, value in enumerate(enumeration.values):
                literal_identity = identity_from_uuid(
                    generated_uuid(enumeration.id, f"literal/{index}/{value}"), "EAID"
                )
                literal = SubElement(
                    node,
                    "ownedAttribute",
                    {
                        XMI_TYPE: "uml:Property",
                        XMI_ID: literal_identity.xmi_id,
                        "name": value,
                        "visibility": "public",
                        "isStatic": "false",
                        "isReadOnly": "false",
                        "isDerived": "false",
                        "isOrdered": "false",
                        "isUnique": "true",
                        "isDerivedUnion": "false",
                    },
                )
                self._add_bounds(literal, "1")

    def _standard_attribute(
        self, parent: Element, attribute: AttributeModel, model: CanonicalProjectModel
    ) -> None:
        identity = self._identities[attribute.id]
        node = SubElement(
            parent,
            "ownedAttribute",
            {
                XMI_TYPE: "uml:Property",
                XMI_ID: identity.xmi_id,
                "name": attribute.name,
                "visibility": "public",
                "isStatic": "false",
                "isReadOnly": "false",
                "isDerived": "false",
                "isOrdered": "false",
                "isUnique": text_bool(attribute.unique),
                "isDerivedUnion": "false",
            },
        )
        classifier = next(
            (item for item in model.enumerations if item.name == attribute.data_type), None
        )
        type_reference = (
            self._identities[classifier.id].xmi_id
            if classifier is not None
            else f"EAJava_{attribute.data_type}"
        )
        SubElement(node, "type", {XMI_IDREF: type_reference})
        self._add_bounds(node, "0..1" if attribute.nullable else "1")
        if attribute.default_value is not None:
            default_identity = identity_from_uuid(
                generated_uuid(attribute.id, "default"), "EAID"
            )
            SubElement(
                node,
                "defaultValue",
                {
                    XMI_TYPE: f"uml:{literal_type(attribute.data_type)}",
                    XMI_ID: default_identity.xmi_id,
                    "value": scalar_text(attribute.default_value),
                },
            )

    def _standard_association(self, package: Element, relationship: RelationshipModel) -> None:
        identity = self._identities[relationship.id]
        source = self._identities[relationship.source_class_id]
        target = self._identities[relationship.target_class_id]
        source_end = self._end_identity(relationship.id, "source")
        target_end = self._end_identity(relationship.id, "target")
        name = relationship.target_role or relationship.source_role or ""
        association = SubElement(
            package,
            "packagedElement",
            {
                XMI_TYPE: "uml:Association",
                XMI_ID: identity.xmi_id,
                "name": name,
                "visibility": "public",
            },
        )
        SubElement(association, "memberEnd", {XMI_IDREF: target_end.xmi_id})
        target_node = SubElement(
            association,
            "ownedEnd",
            self._end_attributes(target_end, identity, relationship.target_role),
        )
        SubElement(target_node, "type", {XMI_IDREF: target.xmi_id})
        self._add_bounds(target_node, relationship.target_multiplicity)
        SubElement(association, "memberEnd", {XMI_IDREF: source_end.xmi_id})
        source_node = SubElement(
            association,
            "ownedEnd",
            self._end_attributes(source_end, identity, relationship.source_role),
        )
        SubElement(source_node, "type", {XMI_IDREF: source.xmi_id})
        self._add_bounds(source_node, relationship.source_multiplicity)

    @staticmethod
    def _end_attributes(
        end: XMIIdentity, association: XMIIdentity, role: str | None
    ) -> dict[str, str]:
        result = {
            XMI_TYPE: "uml:Property",
            XMI_ID: end.xmi_id,
            "visibility": "public",
            "association": association.xmi_id,
            "isStatic": "false",
            "isReadOnly": "true",
            "isDerived": "false",
            "isOrdered": "false",
            "isUnique": "true",
            "isDerivedUnion": "false",
            "aggregation": "none",
        }
        if role:
            result["name"] = role
        return result

    def _add_bounds(self, node: Element, value: str) -> None:
        lower, upper = bounds(value)
        node_identity = node.attrib[XMI_ID]
        lower_identity = identity_from_uuid(generated_uuid(node_identity, "lower"), "EAID")
        upper_identity = identity_from_uuid(generated_uuid(node_identity, "upper"), "EAID")
        SubElement(
            node,
            "lowerValue",
            {
                XMI_TYPE: "uml:LiteralInteger",
                XMI_ID: lower_identity.xmi_id,
                "value": lower,
            },
        )
        SubElement(
            node,
            "upperValue",
            {
                XMI_TYPE: (
                    "uml:LiteralUnlimitedNatural" if upper == "-1" else "uml:LiteralInteger"
                ),
                XMI_ID: upper_identity.xmi_id,
                "value": upper,
            },
        )

    def _extension(
        self,
        extension: Element,
        model: CanonicalProjectModel,
        project_identity: XMIIdentity,
    ) -> None:
        elements = SubElement(extension, "elements")
        self._extension_package(elements, model, project_identity)
        for uml_class in sorted(model.classes, key=lambda item: (item.name.casefold(), item.id)):
            self._extension_classifier(elements, uml_class, model, project_identity, "Class")
        for enumeration in sorted(
            model.enumerations, key=lambda item: (item.name.casefold(), item.id)
        ):
            self._extension_classifier(
                elements, enumeration, model, project_identity, "Enumeration"
            )
        connectors = SubElement(extension, "connectors")
        for relationship in sorted(model.relationships, key=lambda item: item.id):
            self._extension_connector(connectors, relationship, model)
        self._primitive_types(extension, model)
        SubElement(extension, "profiles")
        self._diagram(extension, model, project_identity)

    @staticmethod
    def _extension_package(
        elements: Element, model: CanonicalProjectModel, identity: XMIIdentity
    ) -> None:
        node = SubElement(
            elements,
            "element",
            {XMI_IDREF: identity.xmi_id, XMI_TYPE: "uml:Package", "name": model.name},
        )
        SubElement(node, "model", {"package2": identity.xmi_id, "ea_eleType": "package"})
        SubElement(node, "properties", {"sType": "Package", "scope": "public"})
        SubElement(node, "extendedProperties", {"package_name": model.name})

    def _extension_classifier(
        self,
        elements: Element,
        classifier: ClassModel | EnumerationModel,
        model: CanonicalProjectModel,
        package_identity: XMIIdentity,
        kind: str,
    ) -> None:
        identity = self._identities[classifier.id]
        node = SubElement(
            elements,
            "element",
            {
                XMI_IDREF: identity.xmi_id,
                XMI_TYPE: f"uml:{kind}",
                "name": classifier.name,
                "scope": "public",
            },
        )
        SubElement(node, "model", {"package": package_identity.xmi_id, "ea_eleType": "element"})
        SubElement(node, "properties", {"sType": kind, "scope": "public"})
        SubElement(node, "extendedProperties", {"package_name": model.name})
        attributes = SubElement(node, "attributes")
        if isinstance(classifier, ClassModel):
            for attribute in sorted(
                classifier.attributes, key=lambda item: (item.name.casefold(), item.id)
            ):
                self._extension_attribute(attributes, attribute)
        else:
            for index, value in enumerate(classifier.values):
                literal_identity = identity_from_uuid(
                    generated_uuid(classifier.id, f"literal/{index}/{value}"), "EAID"
                )
                literal = SubElement(
                    attributes,
                    "attribute",
                    {XMI_IDREF: literal_identity.xmi_id, "name": value, "scope": "Public"},
                )
                SubElement(literal, "model", {"ea_guid": literal_identity.guid})
                SubElement(literal, "properties", {"duplicates": "0"})
                SubElement(literal, "bounds", {"lower": "1", "upper": "1"})
        links = SubElement(node, "links")
        for relationship in sorted(model.relationships, key=lambda item: item.id):
            if classifier.id not in {
                relationship.source_class_id,
                relationship.target_class_id,
            }:
                continue
            relation_identity = self._identities[relationship.id]
            source = self._identities[relationship.source_class_id]
            target = self._identities[relationship.target_class_id]
            SubElement(
                links,
                "Generalization" if relationship.type == "GENERALIZATION" else "Association",
                {XMI_ID: relation_identity.xmi_id, "start": source.xmi_id, "end": target.xmi_id},
            )

    def _extension_attribute(self, parent: Element, attribute: AttributeModel) -> None:
        identity = self._identities[attribute.id]
        node = SubElement(
            parent,
            "attribute",
            {XMI_IDREF: identity.xmi_id, "name": attribute.name, "scope": "Public"},
        )
        if attribute.default_value is None:
            SubElement(node, "initial")
        else:
            SubElement(node, "initial", {"value": scalar_text(attribute.default_value)})
        SubElement(node, "model", {"ea_guid": identity.guid})
        SubElement(
            node,
            "properties",
            {
                "type": attribute.data_type,
                "duplicates": "0" if attribute.unique else "1",
                "collection": "false",
            },
        )
        lower = "0" if attribute.nullable else "1"
        SubElement(node, "bounds", {"lower": lower, "upper": "1"})
        SubElement(
            node,
            "xrefs",
            {
                "value": (
                    "$XREFPROP="
                    f"$XID={identity_from_uuid(generated_uuid(attribute.id, 'is-id-xref'), 'EAID').guid}$XID;"
                    "$NAM=CustomProperties$NAM;$TYP=attribute property$TYP;"
                    "$VIS=Public$VIS;$PAR=0$PAR;"
                    f"$DES=@PROP=@NAME=isID@ENDNAME;@TYPE=Boolean@ENDTYPE;@VALU={int(attribute.primary_key)}@ENDVALU;@PRMT=@ENDPRMT;@ENDPROP;$DES;"
                    f"$CLT={identity.guid}$CLT;$SUP=<none>$SUP;$ENDXREF;"
                )
            },
        )

    def _extension_connector(
        self, parent: Element, relationship: RelationshipModel, model: CanonicalProjectModel
    ) -> None:
        identity = self._identities[relationship.id]
        source_identity = self._identities[relationship.source_class_id]
        target_identity = self._identities[relationship.target_class_id]
        class_names = {item.id: item.name for item in model.classes}
        attributes = {XMI_IDREF: identity.xmi_id}
        connector_name = relationship.target_role or relationship.source_role
        if connector_name:
            attributes["name"] = connector_name
        node = SubElement(parent, "connector", attributes)
        source = SubElement(node, "source", {XMI_IDREF: source_identity.xmi_id})
        SubElement(source, "model", {"type": "Class", "name": class_names[relationship.source_class_id]})
        source_role = {"visibility": "Public"}
        if relationship.source_role:
            source_role["name"] = relationship.source_role
        SubElement(source, "role", source_role)
        SubElement(
            source,
            "type",
            {"multiplicity": relationship.source_multiplicity, "aggregation": "none"},
        )
        target = SubElement(node, "target", {XMI_IDREF: target_identity.xmi_id})
        SubElement(target, "model", {"type": "Class", "name": class_names[relationship.target_class_id]})
        target_role = {"visibility": "Public"}
        if relationship.target_role:
            target_role["name"] = relationship.target_role
        SubElement(target, "role", target_role)
        SubElement(
            target,
            "type",
            {"multiplicity": relationship.target_multiplicity, "aggregation": "none"},
        )
        SubElement(
            node,
            "properties",
            {
                "ea_type": (
                    "Generalization" if relationship.type == "GENERALIZATION" else "Association"
                ),
                "direction": (
                    "Source -> Destination"
                    if relationship.type == "GENERALIZATION"
                    else "Unspecified"
                ),
            },
        )

    def _primitive_types(self, extension: Element, model: CanonicalProjectModel) -> None:
        built_in = sorted(
            {
                attribute.data_type
                for uml_class in model.classes
                for attribute in uml_class.attributes
                if attribute.data_type not in {item.name for item in model.enumerations}
            }
        )
        primitive_types = SubElement(extension, "primitivetypes")
        package = SubElement(
            primitive_types,
            "packagedElement",
            {
                XMI_TYPE: "uml:Package",
                XMI_ID: "EAPrimitiveTypesPackage",
                "name": "EA_PrimitiveTypes_Package",
            },
        )
        java_package = SubElement(
            package,
            "packagedElement",
            {
                XMI_TYPE: "uml:Package",
                XMI_ID: "EAJavaTypesPackage",
                "name": "EA_Java_Types_Package",
            },
        )
        for name in built_in:
            SubElement(
                java_package,
                "packagedElement",
                {XMI_TYPE: "uml:PrimitiveType", XMI_ID: f"EAJava_{name}", "name": name},
            )

    def _diagram(
        self, extension: Element, model: CanonicalProjectModel, package: XMIIdentity
    ) -> None:
        diagrams = SubElement(extension, "diagrams")
        diagram_identity = identity_from_uuid(generated_uuid(model.id, "diagram"), "EAID")
        diagram = SubElement(diagrams, "diagram", {XMI_ID: diagram_identity.xmi_id})
        SubElement(diagram, "model", {"package": package.xmi_id, "owner": package.xmi_id})
        SubElement(diagram, "properties", {"name": model.name, "type": "Class"})
        elements = SubElement(diagram, "elements")
        for uml_class in sorted(model.classes, key=lambda item: (item.name.casefold(), item.id)):
            identity = self._identities[uml_class.id]
            left = round(uml_class.position.x)
            top = round(uml_class.position.y)
            SubElement(
                elements,
                "element",
                {
                    "geometry": (
                        f"Left={left};Top={top};Right={left + 220};Bottom={top + 140};"
                    ),
                    "subject": identity.xmi_id,
                },
            )
        for relationship in sorted(model.relationships, key=lambda item: item.id):
            SubElement(
                elements,
                "element",
                {
                    "geometry": "SX=0;SY=0;EX=0;EY=0;Path=;",
                    "subject": self._identities[relationship.id].xmi_id,
                },
            )

    def _identity(
        self,
        item: CanonicalProjectModel
        | ClassModel
        | AttributeModel
        | EnumerationModel
        | RelationshipModel,
        prefix: str,
        purpose: str = "element",
    ) -> XMIIdentity:
        item_id = item.id
        if item_id in self._identities:
            return self._identities[item_id]
        candidates = [
            reference
            for reference in item.external_references or []
            if reference.source == EA_SOURCE
        ]
        reference = next(
            (candidate for candidate in candidates if candidate.scope == self._scope),
            candidates[0] if candidates else None,
        )
        xmi_id = reference.xmi_id if reference is not None else None
        guid = reference.guid if reference is not None else None
        if xmi_id is None and guid is not None:
            xmi_id = xmi_id_from_guid(guid, prefix)
        if guid is None and xmi_id is not None:
            guid = guid_from_xmi_id(xmi_id)
        if xmi_id is None or guid is None:
            generated = identity_from_uuid(generated_uuid(item_id, purpose), prefix)
            xmi_id = xmi_id or generated.xmi_id
            guid = guid or generated.guid
        identity = XMIIdentity(xmi_id, guid)
        self._identities[item_id] = identity
        return identity

    @staticmethod
    def _end_identity(relationship_id: str, end: str) -> XMIIdentity:
        return identity_from_uuid(generated_uuid(relationship_id, f"association-{end}"), "EAID")
