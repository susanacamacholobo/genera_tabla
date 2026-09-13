from io import BytesIO
from pathlib import Path
from typing import Any
from zipfile import ZipFile

import pytest

from spring_generator import SpringGenerator


def test_generates_complete_simple_crud(simple_entity_model: dict[str, Any]) -> None:
    generated = SpringGenerator().generate(simple_entity_model)
    root = "src/main/java/com/example/veterinaria"

    assert set(generated.files) == {
        ".env.example",
        ".gitignore",
        "README.md",
        "pom.xml",
        "src/main/resources/application.yml",
        f"{root}/VeterinariaApplication.java",
        f"{root}/model/Cliente.java",
        f"{root}/repository/ClienteRepository.java",
        f"{root}/service/ClienteService.java",
        f"{root}/controller/ClienteController.java",
        "src/test/java/com/example/veterinaria/ClienteControllerTests.java",
        "src/test/java/com/example/veterinaria/VeterinariaApplicationTests.java",
        "src/test/resources/application-test.yml",
    }
    assert "<version>4.1.1</version>" in generated.files["pom.xml"]
    assert "<artifactId>postgresql</artifactId>" in generated.files["pom.xml"]
    assert "<scope>test</scope>" in generated.files["pom.xml"]
    assert "${DB_PASSWORD}" in generated.files["src/main/resources/application.yml"]
    assert "replace-with-your-local-password" in generated.files[".env.example"]
    assert "docker" not in "\n".join(generated.files).lower()
    assert "extends JpaRepository<Cliente, Long>" in generated.files[
        f"{root}/repository/ClienteRepository.java"
    ]
    assert '@RequestMapping("/api/clientes")' in generated.files[
        f"{root}/controller/ClienteController.java"
    ]
    assert "private final ClienteService service;" in generated.files[
        f"{root}/controller/ClienteController.java"
    ]
    assert "ClienteRepository" not in generated.files[f"{root}/controller/ClienteController.java"]
    assert "private BigDecimal saldo;" in generated.files[f"{root}/model/Cliente.java"]
    assert '@ActiveProfiles("test")' in generated.files[
        "src/test/java/com/example/veterinaria/VeterinariaApplicationTests.java"
    ]
    controller_test = generated.files[
        "src/test/java/com/example/veterinaria/ClienteControllerTests.java"
    ]
    assert 'post("/api/clientes")' in controller_test
    assert 'delete("/api/clientes/{id}", id)' in controller_test


def test_generation_and_zip_are_byte_deterministic(simple_entity_model: dict[str, Any]) -> None:
    first = SpringGenerator().generate(simple_entity_model)
    second = SpringGenerator().generate(simple_entity_model)

    assert first.files == second.files
    assert first.to_zip_bytes() == second.to_zip_bytes()


def test_writes_safe_project_tree(
    simple_entity_model: dict[str, Any], tmp_path: Path
) -> None:
    output = tmp_path / "generated"
    generated = SpringGenerator().generate(simple_entity_model)

    generated.write_to(output)

    assert (output / "pom.xml").read_text(encoding="utf-8") == generated.files["pom.xml"]
    with ZipFile(BytesIO(generated.to_zip_bytes())) as archive:
        assert archive.namelist() == sorted(generated.files)
        assert archive.read("pom.xml").decode("utf-8") == generated.files["pom.xml"]


def test_refuses_to_overwrite_non_empty_directory(
    simple_entity_model: dict[str, Any], tmp_path: Path
) -> None:
    output = tmp_path / "generated"
    output.mkdir()
    (output / "owned-by-user.txt").write_text("preserve", encoding="utf-8")

    with pytest.raises(FileExistsError):
        SpringGenerator().generate(simple_entity_model).write_to(output)

    assert (output / "owned-by-user.txt").read_text(encoding="utf-8") == "preserve"


def test_generates_bidirectional_jpa_annotations(association_model: dict[str, Any]) -> None:
    generated = SpringGenerator().generate(association_model)
    project_folder = association_model["name"].lower().replace(" ", "")
    root = f"src/main/java/com/example/{project_folder}/model"
    sources = "\n".join(
        content
        for path, content in generated.files.items()
        if path.startswith(root) and path.endswith(".java")
    )

    assert "@JsonIgnoreProperties" in sources
    assert "src/test/java/com/example/" in "\n".join(generated.files)
    assert "RelationshipMappingTests.java" in "\n".join(generated.files)
    assert "RelationshipPersistenceTests.java" in "\n".join(generated.files)
    assert "Relaciones JPA generadas:" in generated.files["README.md"]

    if association_model["name"] == "Identidad":
        assert "@OneToOne(optional = false)" in sources
        assert '@OneToOne(mappedBy = "pasaporte")' in sources
        assert 'name = "pasaporte_id", nullable = false, unique = true' in sources
        service = generated.files[
            "src/main/java/com/example/identidad/service/PersonaService.java"
        ]
        assert "current.setPasaporte(input.getPasaporte());" in service
    elif association_model["name"] == "Veterinaria Relaciones":
        assert '@OneToMany(mappedBy = "cliente", fetch = FetchType.EAGER)' in sources
        assert "@ManyToOne(optional = false)" in sources
        assert 'name = "cliente_id", nullable = false' in sources
    else:
        assert "@ManyToMany(fetch = FetchType.EAGER)" in sources
        assert '@ManyToMany(mappedBy = "cursos", fetch = FetchType.EAGER)' in sources
        assert 'name = "estudiantes_cursos"' in sources
