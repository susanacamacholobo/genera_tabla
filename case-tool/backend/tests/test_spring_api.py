import json
from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

import httpx
import pytest

from case_backend.exporters.xmi import XMIExporter
from case_backend.schemas import CanonicalProjectModel

ROOT = Path(__file__).parents[3]


@pytest.mark.anyio
async def test_downloads_spring_zip_from_persisted_case_model(client: httpx.AsyncClient) -> None:
    model = CanonicalProjectModel.model_validate(
        json.loads((ROOT / "docs" / "examples" / "veterinaria.json").read_text(encoding="utf-8"))
    )
    imported = await client.post(
        "/projects/xmi/import",
        files={"file": ("veterinaria.xmi", XMIExporter().export_bytes(model), "application/xml")},
    )
    assert imported.status_code == 201
    project_id = imported.json()["project_id"]

    response = await client.get(f"/projects/{project_id}/spring.zip")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/zip")
    assert "Veterinaria.zip" in response.headers["content-disposition"]
    with ZipFile(BytesIO(response.content)) as archive:
        names = archive.namelist()
        assert "pom.xml" in names
        assert "src/main/java/com/example/veterinaria/model/Cliente.java" in names
        assert "src/main/java/com/example/veterinaria/model/Mascota.java" in names
        assert "metadata/domain-model.json" in names
        assert "POSTMAN.md" in names
        assert "POST http://localhost:8080/api/clientes" in archive.read(
            "POSTMAN.md"
        ).decode("utf-8")
        assert "@ManyToOne" in archive.read(
            "src/main/java/com/example/veterinaria/model/Mascota.java"
        ).decode("utf-8")


@pytest.mark.anyio
async def test_generation_rejects_empty_project_with_actionable_issue(
    client: httpx.AsyncClient,
) -> None:
    created = await client.post("/projects", json={"name": "Incompleto"})
    assert created.status_code == 201

    response = await client.get(f"/projects/{created.json()['id']}/spring.zip")

    assert response.status_code == 422
    assert response.json()["detail"] == [
        {
            "code": "EMPTY_MODEL",
            "path": "classes",
            "message": "Agrega al menos una clase antes de generar.",
        }
    ]


@pytest.mark.anyio
async def test_generation_returns_404_for_unknown_project(client: httpx.AsyncClient) -> None:
    response = await client.get("/projects/missing/spring.zip")

    assert response.status_code == 404
