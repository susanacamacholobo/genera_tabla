from collections.abc import Mapping
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path, PurePosixPath
from types import MappingProxyType
from typing import Any
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

from jinja2 import Environment, PackageLoader, StrictUndefined

from spring_generator.mapping import SpringModelMapper, SpringProject
from spring_generator.validation import ModelValidator


@dataclass(frozen=True)
class GeneratedProject:
    files: Mapping[str, str]

    def write_to(self, directory: Path) -> None:
        target = directory.resolve()
        if target.exists() and any(target.iterdir()):
            raise FileExistsError(f"El directorio de salida no está vacío: {target}")
        target.mkdir(parents=True, exist_ok=True)

        for relative_name, content in sorted(self.files.items()):
            relative_path = PurePosixPath(relative_name)
            if relative_path.is_absolute() or ".." in relative_path.parts:
                raise ValueError(f"Ruta generada insegura: {relative_name}")
            destination = target.joinpath(*relative_path.parts)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(content, encoding="utf-8", newline="\n")

    def to_zip_bytes(self) -> bytes:
        output = BytesIO()
        with ZipFile(output, mode="w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
            for relative_name, content in sorted(self.files.items()):
                info = ZipInfo(relative_name, date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, content.encode("utf-8"))
        return output.getvalue()


class SpringGenerator:
    def __init__(
        self,
        validator: ModelValidator | None = None,
        mapper: SpringModelMapper | None = None,
    ) -> None:
        self.validator = validator or ModelValidator()
        self.mapper = mapper or SpringModelMapper()
        self.environment = Environment(
            loader=PackageLoader("spring_generator", "templates"),
            undefined=StrictUndefined,
            autoescape=False,
            keep_trailing_newline=True,
            trim_blocks=True,
            lstrip_blocks=True,
        )

    def generate(self, canonical_model: dict[str, Any]) -> GeneratedProject:
        self.validator.assert_valid(canonical_model)
        project = self.mapper.map(canonical_model)
        files = self._render_project(project)
        return GeneratedProject(files=MappingProxyType(files))

    def _render_project(self, project: SpringProject) -> dict[str, str]:
        source_root = f"src/main/java/{project.package_path}"
        test_root = f"src/test/java/{project.package_path}"
        files = {
            ".gitignore": self._render("gitignore.j2", project=project),
            ".env.example": self._render("env.example.j2", project=project),
            "README.md": self._render("readme.md.j2", project=project),
            "pom.xml": self._render("pom.xml.j2", project=project),
            "src/main/resources/application.yml": self._render(
                "application.yml.j2", project=project
            ),
            f"{source_root}/{project.application_class}.java": self._render(
                "application.java.j2", project=project
            ),
            "src/test/resources/application-test.yml": self._render(
                "application-test.yml.j2", project=project
            ),
            f"{test_root}/{project.application_class}Tests.java": self._render(
                "application_test.java.j2", project=project
            ),
        }
        for entity in project.entities:
            context = {"project": project, "entity": entity}
            files[f"{source_root}/model/{entity.class_name}.java"] = self._render(
                "entity.java.j2", **context
            )
            files[f"{source_root}/repository/{entity.class_name}Repository.java"] = (
                self._render("repository.java.j2", **context)
            )
            files[f"{source_root}/service/{entity.class_name}Service.java"] = self._render(
                "service.java.j2", **context
            )
            files[f"{source_root}/controller/{entity.class_name}Controller.java"] = (
                self._render("controller.java.j2", **context)
            )
            if entity.standalone_creatable:
                files[f"{test_root}/{entity.class_name}ControllerTests.java"] = self._render(
                    "controller_test.java.j2", **context
                )
        if project.relationships:
            files[f"{test_root}/RelationshipMappingTests.java"] = self._render(
                "relationship_mapping_test.java.j2", project=project
            )
            files[f"{test_root}/RelationshipPersistenceTests.java"] = self._render(
                "relationship_persistence_test.java.j2", project=project
            )
        return dict(sorted(files.items()))

    def _render(self, template_name: str, **context: object) -> str:
        return self.environment.get_template(template_name).render(**context)
