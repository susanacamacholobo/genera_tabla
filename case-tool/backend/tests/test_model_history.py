import httpx
import pytest


async def create_project(client: httpx.AsyncClient) -> dict[str, object]:
    response = await client.post("/projects", json={"name": "Veterinaria"})
    assert response.status_code == 201
    return response.json()


def add_class_change(project_id: str, base_revision: int = 0) -> dict[str, object]:
    return {
        "base_revision": base_revision,
        "command": {
            "id": "command-add-cliente",
            "type": "ADD_CLASS",
            "payload": {
                "id": "class-cliente",
                "name": "Cliente",
                "position": {"x": 100, "y": 120},
            },
        },
        "model": {
            "id": project_id,
            "name": "Veterinaria",
            "revision": base_revision + 1,
            "classes": [
                {
                    "id": "class-cliente",
                    "name": "Cliente",
                    "position": {"x": 100, "y": 120},
                    "attributes": [],
                }
            ],
            "relationships": [],
            "enumerations": [],
        },
    }


@pytest.mark.anyio
async def test_project_starts_with_empty_snapshot(client: httpx.AsyncClient) -> None:
    project = await create_project(client)

    response = await client.get(f"/projects/{project['id']}/model")

    assert response.status_code == 200
    snapshot = response.json()
    assert snapshot["revision"] == 0
    assert snapshot["model"] == {
        "id": project["id"],
        "name": "Veterinaria",
        "revision": 0,
        "classes": [],
        "relationships": [],
        "enumerations": [],
    }


@pytest.mark.anyio
async def test_record_change_persists_snapshot_and_event(client: httpx.AsyncClient) -> None:
    project = await create_project(client)
    project_id = str(project["id"])
    change = add_class_change(project_id)

    response = await client.post(f"/projects/{project_id}/changes", json=change)

    assert response.status_code == 201
    applied = response.json()
    assert applied["snapshot"]["revision"] == 1
    assert applied["snapshot"]["model"] == change["model"]
    assert applied["event"]["base_revision"] == 0
    assert applied["event"]["revision"] == 1
    assert applied["event"]["command"] == change["command"]

    current_response = await client.get(f"/projects/{project_id}/model")
    assert current_response.json()["model"] == change["model"]

    changes_response = await client.get(f"/projects/{project_id}/changes")
    assert changes_response.status_code == 200
    assert [event["revision"] for event in changes_response.json()] == [1]

    project_response = await client.get(f"/projects/{project_id}")
    assert project_response.json()["revision"] == 1


@pytest.mark.anyio
async def test_rejects_stale_revision_without_writing(client: httpx.AsyncClient) -> None:
    project = await create_project(client)
    project_id = str(project["id"])
    change = add_class_change(project_id)
    first_response = await client.post(f"/projects/{project_id}/changes", json=change)
    assert first_response.status_code == 201

    stale_response = await client.post(f"/projects/{project_id}/changes", json=change)

    assert stale_response.status_code == 409
    assert stale_response.json()["detail"]["current_revision"] == 1
    changes_response = await client.get(f"/projects/{project_id}/changes")
    assert len(changes_response.json()) == 1


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("field", "value"),
    [("id", "another-project"), ("revision", 7)],
)
async def test_rejects_model_envelope_mismatch(
    client: httpx.AsyncClient, field: str, value: object
) -> None:
    project = await create_project(client)
    project_id = str(project["id"])
    change = add_class_change(project_id)
    change["model"][field] = value

    response = await client.post(f"/projects/{project_id}/changes", json=change)

    assert response.status_code == 422


@pytest.mark.anyio
async def test_rejects_broken_canonical_references(client: httpx.AsyncClient) -> None:
    project = await create_project(client)
    project_id = str(project["id"])
    change = add_class_change(project_id)
    change["model"]["relationships"] = [
        {
            "id": "relationship-missing",
            "type": "ASSOCIATION",
            "sourceClassId": "class-cliente",
            "targetClassId": "missing-class",
            "sourceMultiplicity": "1",
            "targetMultiplicity": "0..*",
        }
    ]

    response = await client.post(f"/projects/{project_id}/changes", json=change)

    assert response.status_code == 422


@pytest.mark.anyio
async def test_project_delete_cascades_history(client: httpx.AsyncClient) -> None:
    project = await create_project(client)
    project_id = str(project["id"])
    await client.post(f"/projects/{project_id}/changes", json=add_class_change(project_id))

    delete_response = await client.delete(f"/projects/{project_id}")
    model_response = await client.get(f"/projects/{project_id}/model")
    changes_response = await client.get(f"/projects/{project_id}/changes")

    assert delete_response.status_code == 204
    assert model_response.status_code == 404
    assert changes_response.status_code == 404
