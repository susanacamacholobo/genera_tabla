from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

JsonScalar = str | int | float | bool | None
CommandType = Literal[
    "ADD_CLASS",
    "DELETE_CLASS",
    "RENAME_CLASS",
    "MOVE_CLASS",
    "ADD_ATTRIBUTE",
    "UPDATE_ATTRIBUTE",
    "DELETE_ATTRIBUTE",
    "ADD_RELATIONSHIP",
    "UPDATE_RELATIONSHIP",
    "DELETE_RELATIONSHIP",
]


class CanonicalBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")


class ExternalPackageReference(CanonicalBaseModel):
    name: str | None = None
    external_id: str | None = Field(default=None, alias="externalId")
    guid: str | None = None
    xmi_id: str | None = Field(default=None, alias="xmiId")


class ExternalReference(CanonicalBaseModel):
    source: str
    scope: str | None = None
    external_id: str | None = Field(default=None, alias="externalId")
    guid: str | None = None
    xmi_id: str | None = Field(default=None, alias="xmiId")
    package: ExternalPackageReference | None = None


class ExternallyReferenceable(CanonicalBaseModel):
    external_references: list[ExternalReference] | None = Field(
        default=None, alias="externalReferences"
    )


class Position(CanonicalBaseModel):
    x: float
    y: float


class AttributeModel(ExternallyReferenceable):
    id: str
    name: str
    data_type: str = Field(alias="dataType")
    nullable: bool
    unique: bool
    primary_key: bool = Field(alias="primaryKey")
    default_value: JsonScalar = Field(default=None, alias="defaultValue")


class ClassModel(ExternallyReferenceable):
    id: str
    name: str
    position: Position
    attributes: list[AttributeModel]


class RelationshipModel(ExternallyReferenceable):
    id: str
    type: Literal["ASSOCIATION", "GENERALIZATION"]
    source_class_id: str = Field(alias="sourceClassId")
    target_class_id: str = Field(alias="targetClassId")
    source_multiplicity: Literal["0..1", "1", "0..*", "1..*"] = Field(
        alias="sourceMultiplicity"
    )
    target_multiplicity: Literal["0..1", "1", "0..*", "1..*"] = Field(
        alias="targetMultiplicity"
    )
    source_role: str | None = Field(default=None, alias="sourceRole")
    target_role: str | None = Field(default=None, alias="targetRole")


class EnumerationModel(ExternallyReferenceable):
    id: str
    name: str
    values: list[str]


class CanonicalProjectModel(ExternallyReferenceable):
    id: str
    name: str
    revision: int = Field(ge=0)
    classes: list[ClassModel]
    relationships: list[RelationshipModel]
    enumerations: list[EnumerationModel]

    @model_validator(mode="after")
    def validate_identifiers_and_references(self) -> "CanonicalProjectModel":
        identifiers = [self.id]
        class_ids = {item.id for item in self.classes}
        identifiers.extend(item.id for item in self.classes)
        identifiers.extend(attribute.id for item in self.classes for attribute in item.attributes)
        identifiers.extend(item.id for item in self.relationships)
        identifiers.extend(item.id for item in self.enumerations)

        if len(identifiers) != len(set(identifiers)):
            raise ValueError("Los identificadores del modelo canónico deben ser únicos.")

        for relationship in self.relationships:
            if relationship.source_class_id not in class_ids:
                raise ValueError("La clase origen de una relación no existe.")
            if relationship.target_class_id not in class_ids:
                raise ValueError("La clase destino de una relación no existe.")
        return self


class CommandPayload(CanonicalBaseModel):
    id: str = Field(min_length=1, max_length=200)
    type: CommandType
    payload: dict[str, Any]
    target_id: str | None = Field(default=None, alias="targetId")

    @field_validator("id")
    @classmethod
    def command_id_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("El comando debe tener identificador.")
        return value


class ChangeCreate(CanonicalBaseModel):
    base_revision: int = Field(ge=0)
    command: CommandPayload
    model: CanonicalProjectModel


class ProjectSnapshotResponse(CanonicalBaseModel):
    project_id: str
    revision: int
    model: CanonicalProjectModel
    created_at: datetime


class ChangeEventResponse(CanonicalBaseModel):
    id: str
    project_id: str
    base_revision: int
    revision: int
    command: CommandPayload
    created_at: datetime


class ChangeAppliedResponse(CanonicalBaseModel):
    snapshot: ProjectSnapshotResponse
    event: ChangeEventResponse
