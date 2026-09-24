import json
import re
import unicodedata
from dataclasses import dataclass, replace
from typing import Any

JAVA_TYPE_MAPPING = {
    "String": ("String", None),
    "Integer": ("Integer", None),
    "Long": ("Long", None),
    "Double": ("Double", None),
    "Decimal": ("BigDecimal", "java.math.BigDecimal"),
    "Boolean": ("Boolean", None),
    "Date": ("LocalDate", "java.time.LocalDate"),
    "DateTime": ("LocalDateTime", "java.time.LocalDateTime"),
    "UUID": ("UUID", "java.util.UUID"),
}

JSON_TEST_VALUE_MAPPING: dict[str, object] = {
    "String": "example",
    "Integer": 7,
    "Long": 7,
    "Double": 7.5,
    "Decimal": 7.5,
    "Boolean": True,
    "Date": "2026-01-15",
    "DateTime": "2026-01-15T10:30:00",
    "UUID": "00000000-0000-0000-0000-000000000001",
}

JAVA_TEST_VALUE_MAPPING = {
    "String": '"example"',
    "Integer": "7",
    "Long": "7L",
    "Double": "7.5",
    "Decimal": 'new BigDecimal("7.5")',
    "Boolean": "true",
    "Date": "LocalDate.of(2026, 1, 15)",
    "DateTime": "LocalDateTime.of(2026, 1, 15, 10, 30)",
    "UUID": 'UUID.fromString("00000000-0000-0000-0000-000000000001")',
}


def ascii_text(value: str) -> str:
    return unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")


def words(value: str) -> list[str]:
    expanded = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", ascii_text(value))
    return [part for part in re.split(r"[^A-Za-z0-9]+", expanded) if part]


def pascal_case(value: str) -> str:
    return "".join(part[:1].upper() + part[1:] for part in words(value))


def camel_case(value: str) -> str:
    converted = pascal_case(value)
    return converted[:1].lower() + converted[1:]


def kebab_case(value: str) -> str:
    return "-".join(part.lower() for part in words(value))


def snake_case(value: str) -> str:
    return "_".join(part.lower() for part in words(value))


def pluralize(value: str) -> str:
    if value.endswith("z"):
        return f"{value[:-1]}ces"
    if value.endswith(("a", "e", "i", "o", "u")):
        return f"{value}s"
    return f"{value}es"


@dataclass(frozen=True)
class JavaField:
    name: str
    canonical_type: str
    java_type: str
    import_name: str | None
    nullable: bool
    unique: bool
    primary_key: bool
    json_test_value: object
    java_test_value: str

    @property
    def capitalized_name(self) -> str:
        return self.name[:1].upper() + self.name[1:]


@dataclass(frozen=True)
class JavaAssociation:
    name: str
    target_class_name: str
    target_variable_name: str
    target_id_field_name: str
    target_id_java_type: str
    kind: str
    collection: bool
    owning: bool
    required: bool
    opposite_name: str
    mapped_by: str | None = None
    optional: bool | None = None
    join_column_name: str | None = None
    join_table_name: str | None = None
    join_table_column: str | None = None
    inverse_join_table_column: str | None = None

    @property
    def capitalized_name(self) -> str:
        return self.name[:1].upper() + self.name[1:]

    @property
    def java_type(self) -> str:
        if self.collection:
            return f"Set<{self.target_class_name}>"
        return self.target_class_name

    @property
    def request_name(self) -> str:
        suffix = "Ids" if self.collection else "Id"
        return f"{self.name}{suffix}"

    @property
    def capitalized_request_name(self) -> str:
        return self.request_name[:1].upper() + self.request_name[1:]

    @property
    def request_java_type(self) -> str:
        if self.collection:
            return f"Set<{self.target_id_java_type}>"
        return self.target_id_java_type

    @property
    def target_repository_variable_name(self) -> str:
        return f"{self.target_variable_name}Repository"

    @property
    def target_id_capitalized_name(self) -> str:
        return self.target_id_field_name[:1].upper() + self.target_id_field_name[1:]


@dataclass(frozen=True)
class JavaEntity:
    class_name: str
    variable_name: str
    table_name: str
    endpoint_name: str
    fields: tuple[JavaField, ...]
    associations: tuple[JavaAssociation, ...] = ()

    @property
    def id_field(self) -> JavaField:
        return next(field for field in self.fields if field.primary_key)

    @property
    def mutable_fields(self) -> tuple[JavaField, ...]:
        return tuple(field for field in self.fields if not field.primary_key)

    @property
    def writable_associations(self) -> tuple[JavaAssociation, ...]:
        return tuple(association for association in self.associations if association.owning)

    @property
    def owning_repository_associations(self) -> tuple[JavaAssociation, ...]:
        repositories: dict[str, JavaAssociation] = {}
        for association in self.writable_associations:
            repositories.setdefault(association.target_class_name, association)
        return tuple(repositories[class_name] for class_name in sorted(repositories))

    @property
    def request_imports(self) -> tuple[str, ...]:
        imports = {
            field.import_name
            for field in self.mutable_fields
            if field.import_name is not None
        }
        if any(association.collection for association in self.writable_associations):
            imports.add("java.util.Set")
        return tuple(sorted(imports))

    @property
    def response_imports(self) -> tuple[str, ...]:
        imports = {
            field.import_name for field in self.fields if field.import_name is not None
        }
        if any(association.collection for association in self.associations):
            imports.add("java.util.Set")
        return tuple(sorted(imports))

    @property
    def has_required_string(self) -> bool:
        return any(
            not field.nullable and field.java_type == "String"
            for field in self.mutable_fields
        )

    @property
    def has_required_value(self) -> bool:
        return any(
            not field.nullable and field.java_type != "String"
            for field in self.mutable_fields
        ) or any(
            association.required and not association.collection
            for association in self.writable_associations
        )

    @property
    def has_required_collection(self) -> bool:
        return any(
            association.required and association.collection
            for association in self.writable_associations
        )

    @property
    def has_writable_collection(self) -> bool:
        return any(association.collection for association in self.writable_associations)

    @property
    def imports(self) -> tuple[str, ...]:
        return tuple(sorted({field.import_name for field in self.fields if field.import_name}))

    @property
    def test_request_body(self) -> str:
        values = {
            field.name: field.json_test_value
            for field in self.mutable_fields
        }
        return json.dumps(values, ensure_ascii=False, separators=(",", ":"))

    @property
    def postman_request_body(self) -> str:
        values = {
            field.name: field.json_test_value
            for field in self.mutable_fields
        }
        for association in self.writable_associations:
            values[association.request_name] = [1] if association.collection else 1
        return json.dumps(values, ensure_ascii=False, indent=2)

    @property
    def postman_dependencies(self) -> tuple[str, ...]:
        return tuple(
            dict.fromkeys(
                association.target_class_name
                for association in self.writable_associations
                if association.target_class_name != self.class_name
            )
        )

    @property
    def has_required_input(self) -> bool:
        return any(not field.nullable for field in self.mutable_fields) or any(
            association.required for association in self.writable_associations
        )

    @property
    def standalone_creatable(self) -> bool:
        return not any(
            association.owning
            and not association.collection
            and association.optional is False
            for association in self.associations
        )

    @property
    def repository_variable_name(self) -> str:
        return f"{self.variable_name}Repository"


@dataclass(frozen=True)
class JavaRelationship:
    relationship_id: str
    source_class_name: str
    target_class_name: str
    source_field_name: str
    target_field_name: str
    source_kind: str
    target_kind: str
    source_entity: JavaEntity
    target_entity: JavaEntity


@dataclass(frozen=True)
class SpringProject:
    display_name: str
    group_id: str
    artifact_id: str
    database_name: str
    package_name: str
    application_class: str
    boot_version: str
    springdoc_version: str
    java_version: int
    entities: tuple[JavaEntity, ...]
    relationships: tuple[JavaRelationship, ...]

    @property
    def package_path(self) -> str:
        return self.package_name.replace(".", "/")

    @property
    def postman_creation_order(self) -> tuple[JavaEntity, ...]:
        remaining = list(self.entities)
        ordered: list[JavaEntity] = []
        emitted: set[str] = set()
        while remaining:
            ready = [
                entity
                for entity in remaining
                if set(entity.postman_dependencies).issubset(emitted)
            ]
            if not ready:
                # A cycle of required references cannot be created in a strict
                # order. Keep generation deterministic and document the model
                # order so the user can provide existing identifiers.
                ordered.extend(remaining)
                break
            for entity in ready:
                ordered.append(entity)
                emitted.add(entity.class_name)
                remaining.remove(entity)
        return tuple(ordered)


class SpringModelMapper:
    def __init__(
        self,
        group_id: str = "com.example",
        boot_version: str = "4.1.1",
        springdoc_version: str = "3.1.1",
        java_version: int = 21,
    ) -> None:
        if not all(part.isascii() and part.isidentifier() for part in group_id.split(".")):
            raise ValueError(f"Group ID inválido: {group_id}")
        self.group_id = group_id
        self.boot_version = boot_version
        self.springdoc_version = springdoc_version
        self.java_version = java_version

    def map(self, project: dict[str, Any]) -> SpringProject:
        project_name = str(project["name"])
        artifact_id = kebab_case(project_name) or "generated-application"
        package_segment = artifact_id.replace("-", "")
        if package_segment[0].isdigit():
            package_segment = f"app{package_segment}"
        application_name = pascal_case(project_name) or "Generated"
        if application_name[0].isdigit():
            application_name = f"App{application_name}"
        entity_order = [str(item["id"]) for item in project["classes"]]
        entities_by_id = {
            str(item["id"]): self._map_entity(item) for item in project["classes"]
        }
        relationship_fields: dict[str, list[JavaAssociation]] = {
            entity_id: [] for entity_id in entity_order
        }
        relationships: list[JavaRelationship] = []
        for relationship in sorted(project.get("relationships", []), key=lambda item: item["id"]):
            mapped, source_field, target_field = self._map_relationship(
                relationship,
                entities_by_id,
            )
            relationships.append(mapped)
            relationship_fields[str(relationship["sourceClassId"])].append(source_field)
            relationship_fields[str(relationship["targetClassId"])].append(target_field)
        entities = tuple(
            replace(
                entities_by_id[entity_id],
                associations=tuple(
                    sorted(relationship_fields[entity_id], key=lambda item: item.name)
                ),
            )
            for entity_id in entity_order
        )
        return SpringProject(
            display_name=project_name,
            group_id=self.group_id,
            artifact_id=artifact_id,
            database_name=snake_case(project_name) or "generated_application",
            package_name=f"{self.group_id}.{package_segment}",
            application_class=f"{application_name}Application",
            boot_version=self.boot_version,
            springdoc_version=self.springdoc_version,
            java_version=self.java_version,
            entities=entities,
            relationships=tuple(relationships),
        )

    def _map_entity(self, uml_class: dict[str, Any]) -> JavaEntity:
        class_name = pascal_case(uml_class["name"])
        singular_path = kebab_case(uml_class["name"])
        plural_path = pluralize(singular_path)
        fields = tuple(self._map_field(attribute) for attribute in uml_class["attributes"])
        return JavaEntity(
            class_name=class_name,
            variable_name=camel_case(class_name),
            table_name=pluralize(snake_case(uml_class["name"])),
            endpoint_name=plural_path,
            fields=fields,
        )

    def _map_field(self, attribute: dict[str, Any]) -> JavaField:
        java_type, import_name = JAVA_TYPE_MAPPING[attribute["dataType"]]
        return JavaField(
            name=camel_case(attribute["name"]),
            canonical_type=str(attribute["dataType"]),
            java_type=java_type,
            import_name=import_name,
            nullable=bool(attribute.get("nullable", True)),
            unique=bool(attribute.get("unique", False)),
            primary_key=bool(attribute.get("primaryKey", False)),
            json_test_value=JSON_TEST_VALUE_MAPPING[attribute["dataType"]],
            java_test_value=JAVA_TEST_VALUE_MAPPING[attribute["dataType"]],
        )

    def _map_relationship(
        self,
        relationship: dict[str, Any],
        entities_by_id: dict[str, JavaEntity],
    ) -> tuple[JavaRelationship, JavaAssociation, JavaAssociation]:
        source = entities_by_id[str(relationship["sourceClassId"])]
        target = entities_by_id[str(relationship["targetClassId"])]
        source_multiplicity = str(relationship["sourceMultiplicity"])
        target_multiplicity = str(relationship["targetMultiplicity"])
        source_many = source_multiplicity.endswith("*")
        target_many = target_multiplicity.endswith("*")
        source_field_name = camel_case(
            relationship.get("targetRole")
            or self._default_role_name(target, target_many)
        )
        target_field_name = camel_case(
            relationship.get("sourceRole")
            or self._default_role_name(source, source_many)
        )

        if not source_many and not target_many:
            source_field = JavaAssociation(
                name=source_field_name,
                target_class_name=target.class_name,
                target_variable_name=target.variable_name,
                target_id_field_name=target.id_field.name,
                target_id_java_type=target.id_field.java_type,
                kind="ONE_TO_ONE",
                collection=False,
                owning=True,
                required=target_multiplicity == "1",
                opposite_name=target_field_name,
                optional=target_multiplicity == "0..1",
                join_column_name=f"{snake_case(source_field_name)}_id",
            )
            target_field = JavaAssociation(
                name=target_field_name,
                target_class_name=source.class_name,
                target_variable_name=source.variable_name,
                target_id_field_name=source.id_field.name,
                target_id_java_type=source.id_field.java_type,
                kind="ONE_TO_ONE",
                collection=False,
                owning=False,
                required=source_multiplicity == "1",
                opposite_name=source_field_name,
                mapped_by=source_field_name,
                optional=source_multiplicity == "0..1",
            )
        elif not source_many and target_many:
            source_field = JavaAssociation(
                name=source_field_name,
                target_class_name=target.class_name,
                target_variable_name=target.variable_name,
                target_id_field_name=target.id_field.name,
                target_id_java_type=target.id_field.java_type,
                kind="ONE_TO_MANY",
                collection=True,
                owning=False,
                required=target_multiplicity == "1..*",
                opposite_name=target_field_name,
                mapped_by=target_field_name,
            )
            target_field = JavaAssociation(
                name=target_field_name,
                target_class_name=source.class_name,
                target_variable_name=source.variable_name,
                target_id_field_name=source.id_field.name,
                target_id_java_type=source.id_field.java_type,
                kind="MANY_TO_ONE",
                collection=False,
                owning=True,
                required=source_multiplicity == "1",
                opposite_name=source_field_name,
                optional=source_multiplicity == "0..1",
                join_column_name=f"{snake_case(target_field_name)}_id",
            )
        elif source_many and not target_many:
            source_field = JavaAssociation(
                name=source_field_name,
                target_class_name=target.class_name,
                target_variable_name=target.variable_name,
                target_id_field_name=target.id_field.name,
                target_id_java_type=target.id_field.java_type,
                kind="MANY_TO_ONE",
                collection=False,
                owning=True,
                required=target_multiplicity == "1",
                opposite_name=target_field_name,
                optional=target_multiplicity == "0..1",
                join_column_name=f"{snake_case(source_field_name)}_id",
            )
            target_field = JavaAssociation(
                name=target_field_name,
                target_class_name=source.class_name,
                target_variable_name=source.variable_name,
                target_id_field_name=source.id_field.name,
                target_id_java_type=source.id_field.java_type,
                kind="ONE_TO_MANY",
                collection=True,
                owning=False,
                required=source_multiplicity == "1..*",
                opposite_name=source_field_name,
                mapped_by=source_field_name,
            )
        else:
            source_field = JavaAssociation(
                name=source_field_name,
                target_class_name=target.class_name,
                target_variable_name=target.variable_name,
                target_id_field_name=target.id_field.name,
                target_id_java_type=target.id_field.java_type,
                kind="MANY_TO_MANY",
                collection=True,
                owning=True,
                required=target_multiplicity == "1..*",
                opposite_name=target_field_name,
                join_table_name=f"{source.table_name}_{target.table_name}",
                join_table_column=f"{snake_case(source.variable_name)}_id",
                inverse_join_table_column=f"{snake_case(target.variable_name)}_id",
            )
            target_field = JavaAssociation(
                name=target_field_name,
                target_class_name=source.class_name,
                target_variable_name=source.variable_name,
                target_id_field_name=source.id_field.name,
                target_id_java_type=source.id_field.java_type,
                kind="MANY_TO_MANY",
                collection=True,
                owning=False,
                required=source_multiplicity == "1..*",
                opposite_name=source_field_name,
                mapped_by=source_field_name,
            )

        mapped = JavaRelationship(
            relationship_id=str(relationship["id"]),
            source_class_name=source.class_name,
            target_class_name=target.class_name,
            source_field_name=source_field_name,
            target_field_name=target_field_name,
            source_kind=source_field.kind,
            target_kind=target_field.kind,
            source_entity=source,
            target_entity=target,
        )
        return mapped, source_field, target_field

    def _default_role_name(self, entity: JavaEntity, collection: bool) -> str:
        if collection:
            return pluralize(entity.variable_name)
        return entity.variable_name
