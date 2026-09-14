from pathlib import Path

import httpx
import pytest

from case_backend.api import xmi as xmi_api
from case_backend.importers.xmi import XMIImporter

FIXTURES = Path(__file__).parent / "fixtures" / "enterprise-architect"


@pytest.mark.anyio
async def test_import_persists_project_and_initial_snapshot(client: httpx.AsyncClient) -> None:
    content = (FIXTURES / "06-complete-veterinaria.xmi").read_bytes()

    response = await client.post(
        "/projects/xmi/import?scope=ea15-api-test",
        files={"file": ("veterinaria.xmi", content, "application/xml")},
    )

    assert response.status_code == 201
    snapshot = response.json()
    project_id = snapshot["project_id"]
    assert snapshot["revision"] == 0
    assert snapshot["model"]["name"] == "Veterinaria"
    assert len(snapshot["model"]["classes"]) == 3
    assert len(snapshot["model"]["relationships"]) == 2
    assert snapshot["model"]["externalReferences"][0]["scope"] == "ea15-api-test"

    project_response = await client.get(f"/projects/{project_id}")
    model_response = await client.get(f"/projects/{project_id}/model")
    assert project_response.status_code == 200
    assert project_response.json()["revision"] == 0
    assert model_response.json() == snapshot


@pytest.mark.anyio
async def test_export_returns_downloadable_xmi(client: httpx.AsyncClient) -> None:
    imported = await client.post(
        "/projects/xmi/import",
        files={
            "file": (
                "single.xmi",
                (FIXTURES / "01-single-class.xmi").read_bytes(),
                "application/xml",
            )
        },
    )
    project_id = imported.json()["project_id"]

    response = await client.get(f"/projects/{project_id}/xmi")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/xml")
    assert "SingleClass.xmi" in response.headers["content-disposition"]
    restored = XMIImporter().import_bytes(response.content)
    assert restored.name == "SingleClass"
    assert [item.name for item in restored.classes] == ["Cliente"]


@pytest.mark.anyio
async def test_import_rejects_invalid_and_oversized_files(
    client: httpx.AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    invalid = await client.post(
        "/projects/xmi/import",
        files={"file": ("invalid.xmi", b"<root />", "application/xml")},
    )
    assert invalid.status_code == 422

    monkeypatch.setattr(xmi_api, "MAX_XMI_BYTES", 10)
    oversized = await client.post(
        "/projects/xmi/import",
        files={"file": ("large.xmi", b"x" * 11, "application/xml")},
    )
    assert oversized.status_code == 413


@pytest.mark.anyio
async def test_export_missing_project_returns_404(client: httpx.AsyncClient) -> None:
    response = await client.get("/projects/missing/xmi")

    assert response.status_code == 404
