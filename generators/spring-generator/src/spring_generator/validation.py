import re
from dataclasses import dataclass
from typing import Any

SUPPORTED_DATA_TYPES = {
    "String",
    "Integer",
    "Long",
    "Double",
    "Decimal",
    "Boolean",
    "Date",
    "DateTime",
    "UUID",
}
SUPPORTED_ID_TYPES = {"Integer", "Long"}
SUPPORTED_MULTIPLICITIES = {"0..1", "1", "0..*", "1..*"}
JAVA_KEYWORDS = {
    "abstract",
    "assert",
    "boolean",
    "break",
    "byte",
    "case",
    "catch",
    "char",
    "class",
    "const",
    "continue",
    "default",
    "do",
    "double",
    "else",
    "enum",
    "extends",
    "final",
    "finally",
    "float",
    "for",
    "goto",
    "if",
    "implements",
    "import",
    "instanceof",
    "int",
    "interface",
    "long",
    "native",
    "new",
    "package",
    "private",
    "protected",
    "public",
    "return",
    "short",
    "static",
    "strictfp",
    "super",
    "switch",
    "synchronized",
    "this",
    "throw",
    "throws",
    "transient",
    "try",
    "void",
    "volatile",
    "while",
}


@dataclass(frozen=True)
class GenerationIssue:
    code: str
    path: str
    message: str


@dataclass(frozen=True)
class GenerationValidationResult:
    issues: tuple[GenerationIssue, ...]

    @property
    def valid(self) -> bool:
        return not self.issues


class GenerationValidationError(ValueError):
    def __init__(self, issues: tuple[GenerationIssue, ...]) -> None:
        super().__init__("El modelo no se puede generar: " + " ".join(item.message for item in issues))
        self.issues = issues


def issue(code: str, path: str, message: str) -> GenerationIssue:
    return GenerationIssue(code=code, path=path, message=message)


def is_java_identifier(value: object) -> bool:
    if not isinstance(value, str) or not value or value in JAVA_KEYWORDS:
        return False
    return re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", value) is not None


def default_role_name(class_name: str, multiplicity: str) -> str:
    value = class_name[:1].lower() + class_name[1:]
    if multiplicity.endswith("*"):
        if value.endswith("z"):
            return f"{value[:-1]}ces"
        if value.endswith(("a", "e", "i", "o", "u")):
            return f"{value}s"
        return f"{value}es"
    return value


class ModelValidator:
    def validate(self, project: dict[str, Any]) -> GenerationValidationResult:
        issues: list[GenerationIssue] = []
        name = project.get("name")
        classes = project.get("classes")
        relationships = project.get("relationships", [])
        enumerations = project.get("enumerations", [])

        if not isinstance(name, str) or not name.strip():
            issues.append(issue("INVALID_PROJECT_NAME", "name", "El proyecto debe tener nombre."))
        if not isinstance(classes, list):
            issues.append(issue("INVALID_CLASSES", "classes", "La colección de clases no es válida."))
            return GenerationValidationResult(tuple(issues))
        if not isinstance(relationships, list):
            issues.append(
                issue(
                    "INVALID_RELATIONSHIPS",
                    "relationships",
                    "La colección de relaciones no es válida.",
                )
            )
            relationships = []
        if enumerations:
            issues.append(
                issue(
                    "UNSUPPORTED_ENUMERATIONS",
                    "enumerations",
                    "Las enumeraciones aún no están soportadas por el generador básico.",
                )
            )

        class_names: set[str] = set()
        class_ids: set[str] = set()
        classes_by_id: dict[str, dict[str, Any]] = {}
        generated_field_names: dict[str, set[str]] = {}
        dto_field_names: dict[str, set[str]] = {}
        for class_index, uml_class in enumerate(classes):
            path = f"classes[{class_index}]"
            if not isinstance(uml_class, dict):
                issues.append(issue("INVALID_CLASS", path, "La clase no es un objeto válido."))
                continue
            class_name = uml_class.get("name")
            class_id = uml_class.get("id")
            if not isinstance(class_id, str) or not class_id:
                issues.append(
                    issue("INVALID_CLASS_ID", f"{path}.id", "La clase debe tener un ID no vacío.")
                )
            elif class_id in class_ids:
                issues.append(issue("DUPLICATE_CLASS_ID", f"{path}.id", "El ID de clase está repetido."))
            else:
                class_ids.add(class_id)
                classes_by_id[class_id] = uml_class
            if not is_java_identifier(class_name):
                issues.append(
                    issue(
                        "INVALID_CLASS_NAME",
                        f"{path}.name",
                        f"'{class_name}' no es un identificador Java válido.",
                    )
                )
            elif class_name.casefold() in class_names:
                issues.append(
                    issue("DUPLICATE_CLASS_NAME", f"{path}.name", "El nombre de clase está repetido.")
                )
            else:
                class_names.add(class_name.casefold())
            self._validate_attributes(uml_class.get("attributes"), path, issues)
            generated_field_names[str(class_id)] = {
                str(attribute.get("name", "")).casefold()
                for attribute in uml_class.get("attributes", [])
                if isinstance(attribute, dict)
            }
            dto_field_names[str(class_id)] = set(generated_field_names[str(class_id)])

        self._validate_relationships(
            relationships,
            classes_by_id,
            generated_field_names,
            dto_field_names,
            issues,
        )

        return GenerationValidationResult(tuple(issues))

    def assert_valid(self, project: dict[str, Any]) -> None:
        result = self.validate(project)
        if not result.valid:
            raise GenerationValidationError(result.issues)

    def _validate_attributes(
        self,
        attributes: object,
        class_path: str,
        issues: list[GenerationIssue],
    ) -> None:
        if not isinstance(attributes, list):
            issues.append(
                issue(
                    "INVALID_ATTRIBUTES",
                    f"{class_path}.attributes",
                    "La colección de atributos no es válida.",
                )
            )
            return

        names: set[str] = set()
        primary_keys: list[dict[str, Any]] = []
        for attribute_index, attribute in enumerate(attributes):
            path = f"{class_path}.attributes[{attribute_index}]"
            if not isinstance(attribute, dict):
                issues.append(issue("INVALID_ATTRIBUTE", path, "El atributo no es un objeto válido."))
                continue
            name = attribute.get("name")
            if not is_java_identifier(name):
                issues.append(
                    issue(
                        "INVALID_ATTRIBUTE_NAME",
                        f"{path}.name",
                        f"'{name}' no es un identificador Java válido.",
                    )
                )
            elif name.casefold() in names:
                issues.append(
                    issue(
                        "DUPLICATE_ATTRIBUTE_NAME",
                        f"{path}.name",
                        "El nombre de atributo está repetido.",
                    )
                )
            else:
                names.add(name.casefold())

            data_type = attribute.get("dataType")
            if data_type not in SUPPORTED_DATA_TYPES:
                issues.append(
                    issue(
                        "UNSUPPORTED_DATA_TYPE",
                        f"{path}.dataType",
                        f"El tipo '{data_type}' no está soportado en la fase 8.",
                    )
                )
            if attribute.get("primaryKey") is True:
                primary_keys.append(attribute)

        if len(primary_keys) != 1:
            issues.append(
                issue(
                    "INVALID_PRIMARY_KEY_COUNT",
                    f"{class_path}.attributes",
                    "Cada entidad simple debe tener exactamente una clave primaria.",
                )
            )
        elif primary_keys[0].get("dataType") not in SUPPORTED_ID_TYPES:
            issues.append(
                issue(
                    "UNSUPPORTED_PRIMARY_KEY_TYPE",
                    f"{class_path}.attributes",
                    "La clave primaria debe ser Integer o Long en la fase 8.",
                )
            )

    def _validate_relationships(
        self,
        relationships: list[object],
        classes_by_id: dict[str, dict[str, Any]],
        generated_field_names: dict[str, set[str]],
        dto_field_names: dict[str, set[str]],
        issues: list[GenerationIssue],
    ) -> None:
        relationship_ids: set[str] = set()
        for relationship_index, relationship in enumerate(relationships):
            path = f"relationships[{relationship_index}]"
            if not isinstance(relationship, dict):
                issues.append(
                    issue("INVALID_RELATIONSHIP", path, "La relación no es un objeto válido.")
                )
                continue

            relationship_id = relationship.get("id")
            if not isinstance(relationship_id, str) or not relationship_id:
                issues.append(
                    issue("INVALID_RELATIONSHIP_ID", f"{path}.id", "La relación debe tener un ID.")
                )
            elif relationship_id in relationship_ids:
                issues.append(
                    issue("DUPLICATE_RELATIONSHIP_ID", f"{path}.id", "El ID de relación está repetido.")
                )
            else:
                relationship_ids.add(relationship_id)

            relationship_type = relationship.get("type")
            if relationship_type == "GENERALIZATION":
                issues.append(
                    issue(
                        "UNSUPPORTED_GENERALIZATION",
                        f"{path}.type",
                        "La herencia JPA no forma parte de la fase 10.",
                    )
                )
            elif relationship_type != "ASSOCIATION":
                issues.append(
                    issue(
                        "INVALID_RELATIONSHIP_TYPE",
                        f"{path}.type",
                        f"El tipo de relación '{relationship_type}' no está soportado.",
                    )
                )

            source_id = relationship.get("sourceClassId")
            target_id = relationship.get("targetClassId")
            source = classes_by_id.get(str(source_id))
            target = classes_by_id.get(str(target_id))
            if source is None:
                issues.append(
                    issue(
                        "MISSING_SOURCE_CLASS",
                        f"{path}.sourceClassId",
                        f"No existe la clase origen '{source_id}'.",
                    )
                )
            if target is None:
                issues.append(
                    issue(
                        "MISSING_TARGET_CLASS",
                        f"{path}.targetClassId",
                        f"No existe la clase destino '{target_id}'.",
                    )
                )
            if source_id == target_id and source is not None:
                issues.append(
                    issue(
                        "UNSUPPORTED_SELF_ASSOCIATION",
                        path,
                        "Las asociaciones reflexivas aún no están soportadas.",
                    )
                )

            source_multiplicity = relationship.get("sourceMultiplicity")
            target_multiplicity = relationship.get("targetMultiplicity")
            for key, value in (
                ("sourceMultiplicity", source_multiplicity),
                ("targetMultiplicity", target_multiplicity),
            ):
                if value not in SUPPORTED_MULTIPLICITIES:
                    issues.append(
                        issue(
                            "INVALID_MULTIPLICITY",
                            f"{path}.{key}",
                            f"La multiplicidad '{value}' no está soportada.",
                        )
                    )

            for key in ("sourceRole", "targetRole"):
                role = relationship.get(key)
                if role is not None and not is_java_identifier(role):
                    issues.append(
                        issue(
                            "INVALID_RELATIONSHIP_ROLE",
                            f"{path}.{key}",
                            f"'{role}' no es un nombre de rol Java válido.",
                        )
                    )

            if (
                source is not None
                and target is not None
                and source_id != target_id
                and source_multiplicity in SUPPORTED_MULTIPLICITIES
                and target_multiplicity in SUPPORTED_MULTIPLICITIES
            ):
                source_field = relationship.get("targetRole") or default_role_name(
                    str(target["name"]), str(target_multiplicity)
                )
                target_field = relationship.get("sourceRole") or default_role_name(
                    str(source["name"]), str(source_multiplicity)
                )
                self._reserve_relationship_field(
                    str(source_id), str(source_field), f"{path}.targetRole", generated_field_names, issues
                )
                self._reserve_relationship_field(
                    str(target_id), str(target_field), f"{path}.sourceRole", generated_field_names, issues
                )
                source_dto_field = f"{source_field}{'Ids' if str(target_multiplicity).endswith('*') else 'Id'}"
                target_dto_field = f"{target_field}{'Ids' if str(source_multiplicity).endswith('*') else 'Id'}"
                self._reserve_dto_field(
                    str(source_id), source_dto_field, f"{path}.targetRole", dto_field_names, issues
                )
                self._reserve_dto_field(
                    str(target_id), target_dto_field, f"{path}.sourceRole", dto_field_names, issues
                )

    def _reserve_relationship_field(
        self,
        class_id: str,
        field_name: str,
        path: str,
        generated_field_names: dict[str, set[str]],
        issues: list[GenerationIssue],
    ) -> None:
        names = generated_field_names.setdefault(class_id, set())
        normalized = field_name.casefold()
        if normalized in names:
            issues.append(
                issue(
                    "DUPLICATE_GENERATED_FIELD",
                    path,
                    f"El campo de relación '{field_name}' colisiona con otro campo generado.",
                )
            )
        else:
            names.add(normalized)

    def _reserve_dto_field(
        self,
        class_id: str,
        field_name: str,
        path: str,
        dto_field_names: dict[str, set[str]],
        issues: list[GenerationIssue],
    ) -> None:
        names = dto_field_names.setdefault(class_id, set())
        normalized = field_name.casefold()
        if normalized in names:
            issues.append(
                issue(
                    "DUPLICATE_DTO_FIELD",
                    path,
                    f"El campo DTO '{field_name}' colisiona con otro campo generado.",
                )
            )
        else:
            names.add(normalized)
