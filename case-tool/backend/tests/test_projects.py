import httpx
import pytest


@pytest.mark.anyio
async def test_project_crud(client: httpx.AsyncClient) -> None:
    created_response = await client.post("/projects", json={"name": "  Veterinaria  "})

    assert created_response.status_code == 201
    created = created_response.json()
    assert created["name"] == "Veterinaria"
    assert created["revision"] == 0
    assert created["id"]

    list_response = await client.get("/projects")
    assert list_response.status_code == 200
    assert [project["id"] for project in list_response.json()] == [created["id"]]

    get_response = await client.get(f"/projects/{created['id']}")
    assert get_response.status_code == 200
    assert get_response.json() == created

    update_response = await client.put(
        f"/projects/{created['id']}", json={"name": "Clínica veterinaria"}
    )
    assert update_response.status_code == 200
    assert update_response.json()["name"] == "Clínica veterinaria"

    delete_response = await client.delete(f"/projects/{created['id']}")
    assert delete_response.status_code == 204
    assert delete_response.content == b""

    missing_response = await client.get(f"/projects/{created['id']}")
    assert missing_response.status_code == 404
    assert "No existe el proyecto" in missing_response.json()["detail"]


@pytest.mark.anyio
async def test_project_name_validation(client: httpx.AsyncClient) -> None:
    response = await client.post("/projects", json={"name": "   "})

    assert response.status_code == 422


@pytest.mark.anyio
@pytest.mark.parametrize("method", ["get", "put", "delete"])
async def test_missing_project(client: httpx.AsyncClient, method: str) -> None:
    request = getattr(client, method)
    kwargs = {"json": {"name": "No existe"}} if method == "put" else {}

    response = await request("/projects/missing-project", **kwargs)

    assert response.status_code == 404

