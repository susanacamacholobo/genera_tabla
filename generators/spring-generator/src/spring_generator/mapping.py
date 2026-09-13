import re
import unicodedata
from dataclasses import dataclass
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
    java_type: str
    import_name: str | None
    nullable: bool
    unique: bool
    primary_key: bool

    @property
    def capitalized_name(self) -> str:
        return self.name[:1].upper() + self.name[1:]


@dataclass(frozen=True)
class JavaEntity:
    class_name: str
    variable_name: str
    table_name: str
    endpoint_name: str
    fields: tuple[JavaField, ...]

    @property
    def id_field(self) -> JavaField:
        return next(field for field in self.fields if field.primary_key)

    @property
    def mutable_fields(self) -> tuple[JavaField, ...]:
        return tuple(field for field in self.fields if not field.primary_key)

    @property
    def imports(self) -> tuple[str, ...]:
        return tuple(sorted({field.import_name for field in self.fields if field.import_name}))


@dataclass(frozen=True)
class SpringProject:
    group_id: str
    artifact_id: str
    package_name: str
    application_class: str
    boot_version: str
    java_version: int
    entities: tuple[JavaEntity, ...]

    @property
    def package_path(self) -> str:
        return self.package_name.replace(".", "/")


class SpringModelMapper:
    def __init__(
        self,
        group_id: str = "com.example",
        boot_version: str = "4.1.1",
        java_version: int = 21,
    ) -> None:
        if not all(part.isascii() and part.isidentifier() for part in group_id.split(".")):
            raise ValueError(f"Group ID inválido: {group_id}")
        self.group_id = group_id
        self.boot_version = boot_version
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
        entities = tuple(self._map_entity(item) for item in project["classes"])
        return SpringProject(
            group_id=self.group_id,
            artifact_id=artifact_id,
            package_name=f"{self.group_id}.{package_segment}",
            application_class=f"{application_name}Application",
            boot_version=self.boot_version,
            java_version=self.java_version,
            entities=entities,
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
            java_type=java_type,
            import_name=import_name,
            nullable=bool(attribute.get("nullable", True)),
            unique=bool(attribute.get("unique", False)),
            primary_key=bool(attribute.get("primaryKey", False)),
        )
