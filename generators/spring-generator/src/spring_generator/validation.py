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
        if relationships:
            issues.append(
                issue(
                    "UNSUPPORTED_RELATIONSHIPS",
                    "relationships",
                    "Las relaciones JPA se incorporan en la fase 10.",
                )
            )
        if enumerations:
            issues.append(
                issue(
                    "UNSUPPORTED_ENUMERATIONS",
                    "enumerations",
                    "Las enumeraciones aún no están soportadas por el generador básico.",
                )
            )

        class_names: set[str] = set()
        for class_index, uml_class in enumerate(classes):
            path = f"classes[{class_index}]"
            if not isinstance(uml_class, dict):
                issues.append(issue("INVALID_CLASS", path, "La clase no es un objeto válido."))
                continue
            class_name = uml_class.get("name")
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
