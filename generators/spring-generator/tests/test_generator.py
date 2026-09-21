import json
from io import BytesIO
from pathlib import Path
from typing import Any
from zipfile import ZipFile

import pytest

from spring_generator import SpringGenerator


def test_biblioteca_demo_generates_all_required_relationship_fixtures() -> None:
    example = Path(__file__).parents[3] / "docs" / "examples" / "biblioteca.json"
    generated = SpringGenerator().generate(json.loads(example.read_text(encoding="utf-8")))
    path = "src/test/java/com/example/biblioteca/RelationshipPersistenceTests.java"
    persistence_test = generated.files[path]

    assert "target.setLibro(source);" in persistence_test
    assert "target.setSocio(source);" in persistence_test
    assert "target.setSocio(requiredSocio);" in persistence_test
    assert "target.setLibro(requiredLibro);" in persistence_test


def test_generates_complete_simple_crud(simple_entity_model: dict[str, Any]) -> None:
    generated = SpringGenerator().generate(simple_entity_model)
    root = "src/main/java/com/example/veterinaria"

    assert set(generated.files) == {
        ".env.example",
        ".gitignore",
        "README.md",
        "pom.xml",
        "openapi/openapi.json",
        "metadata/domain-model.json",
        "src/main/resources/application.yml",
        f"{root}/VeterinariaApplication.java",
        f"{root}/config/OpenApiConfig.java",
        f"{root}/model/Cliente.java",
        f"{root}/dto/ClienteRequest.java",
        f"{root}/dto/ClienteResponse.java",
        f"{root}/mapper/ClienteMapper.java",
        f"{root}/exception/ApiError.java",
        f"{root}/exception/GlobalExceptionHandler.java",
        f"{root}/exception/ResourceNotFoundException.java",
        f"{root}/repository/ClienteRepository.java",
        f"{root}/service/ClienteService.java",
        f"{root}/controller/ClienteController.java",
        "src/test/java/com/example/veterinaria/ClienteControllerTests.java",
        "src/test/java/com/example/veterinaria/OpenApiContractTests.java",
        "src/test/java/com/example/veterinaria/VeterinariaApplicationTests.java",
        "src/test/resources/application-test.yml",
    }
    assert "<version>4.1.1</version>" in generated.files["pom.xml"]
    assert "<artifactId>postgresql</artifactId>" in generated.files["pom.xml"]
    assert "<artifactId>spring-boot-starter-validation</artifactId>" in generated.files[
        "pom.xml"
    ]
    assert "<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>" in generated.files[
        "pom.xml"
    ]
    assert "<version>3.1.1</version>" in generated.files["pom.xml"]
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
    controller = generated.files[f"{root}/controller/ClienteController.java"]
    assert "ClienteResponse" in controller
    assert "@Valid @RequestBody ClienteRequest input" in controller
    assert "model.Cliente" not in controller
    request_dto = generated.files[f"{root}/dto/ClienteRequest.java"]
    assert '@NotBlank(message = "nombre es obligatorio")' in request_dto
    assert '@NotNull(message = "fechaRegistro es obligatorio")' in request_dto
    response_dto = generated.files[f"{root}/dto/ClienteResponse.java"]
    assert "Long id" in response_dto
    assert "ClienteMapper" in generated.files[f"{root}/mapper/ClienteMapper.java"]
    assert "ResourceNotFoundException" in generated.files[
        f"{root}/service/ClienteService.java"
    ]
    assert "MethodArgumentNotValidException" in generated.files[
        f"{root}/exception/GlobalExceptionHandler.java"
    ]
    assert '@Operation(operationId = "listCliente"' in controller
    assert 'title("Veterinaria API")' in generated.files[f"{root}/config/OpenApiConfig.java"]
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
    assert "RelationshipDtoTests.java" in "\n".join(generated.files)
    assert "Relaciones JPA generadas:" in generated.files["README.md"]

    if association_model["name"] == "Identidad":
        assert "@OneToOne(optional = false)" in sources
        assert '@OneToOne(mappedBy = "pasaporte")' in sources
        assert 'name = "pasaporte_id", nullable = false, unique = true' in sources
        service = generated.files[
            "src/main/java/com/example/identidad/service/PersonaService.java"
        ]
        assert "input.pasaporteId()" in service
        assert "PasaporteRepository pasaporteRepository" in service
        dto_test = generated.files[
            "src/test/java/com/example/identidad/PersonaRelationshipDtoTests.java"
        ]
        assert "relationshipIdsAreResolvedAndReturned" in dto_test
        assert "missingRelationshipIdsAreRejected" in dto_test
    elif association_model["name"] == "Veterinaria Relaciones":
        assert '@OneToMany(mappedBy = "cliente", fetch = FetchType.EAGER)' in sources
        assert "@ManyToOne(optional = false)" in sources
        assert 'name = "cliente_id", nullable = false' in sources
        mascota_request = generated.files[
            "src/main/java/com/example/veterinariarelaciones/dto/MascotaRequest.java"
        ]
        assert "@NotNull" in mascota_request
        assert "Long clienteId" in mascota_request
        cliente_response = generated.files[
            "src/main/java/com/example/veterinariarelaciones/dto/ClienteResponse.java"
        ]
        assert "Set<Long> mascotasIds" in cliente_response
    else:
        assert "@ManyToMany(fetch = FetchType.EAGER)" in sources
        assert '@ManyToMany(mappedBy = "cursos", fetch = FetchType.EAGER)' in sources
        assert 'name = "estudiantes_cursos"' in sources
        estudiante_request = generated.files[
            "src/main/java/com/example/academia/dto/EstudianteRequest.java"
        ]
        assert "Set<Long> cursosIds" in estudiante_request
