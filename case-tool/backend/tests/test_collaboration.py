from urllib.parse import urlencode

from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect


def create_project(client: TestClient) -> str:
    response = client.post("/projects", json={"name": "Veterinaria"})
    assert response.status_code == 201
    return str(response.json()["id"])


def websocket_path(project_id: str, user_id: str = "ana", name: str = "Ana") -> str:
    query = urlencode({"userId": user_id, "displayName": name})
    return f"/ws/projects/{project_id}?{query}"


def class_model(project_id: str, revision: int, x: float = 100) -> dict[str, object]:
    return {
        "id": project_id,
        "name": "Veterinaria",
        "revision": revision,
        "classes": [
            {
                "id": "class-cliente",
                "name": "Cliente",
                "position": {"x": x, "y": 120},
                "attributes": [],
            }
        ],
        "relationships": [],
        "enumerations": [],
    }


def add_class_message(project_id: str, base_revision: int = 0) -> dict[str, object]:
    return {
        "type": "change.submit",
        "baseRevision": base_revision,
        "command": {
            "id": f"add-class-{base_revision}",
            "type": "ADD_CLASS",
            "payload": {
                "id": "class-cliente",
                "name": "Cliente",
                "position": {"x": 100, "y": 120},
            },
        },
        "model": class_model(project_id, base_revision + 1),
    }


def move_message(
    project_id: str, command_id: str, base_revision: int, x: float
) -> dict[str, object]:
    return {
        "type": "change.submit",
        "baseRevision": base_revision,
        "command": {
            "id": command_id,
            "type": "MOVE_CLASS",
            "targetId": "class-cliente",
            "payload": {"position": {"x": x, "y": 120}},
        },
        "model": class_model(project_id, base_revision + 1, x),
    }


def consume_ready(websocket: object) -> dict[str, object]:
    ready = websocket.receive_json()
    assert ready["type"] == "session.ready"
    presence = websocket.receive_json()
    assert presence["type"] == "presence.changed"
    return ready


def test_connection_receives_snapshot_and_answers_ping(websocket_client: TestClient) -> None:
    project_id = create_project(websocket_client)

    with websocket_client.websocket_connect(websocket_path(project_id)) as websocket:
        ready = consume_ready(websocket)
        assert ready["projectId"] == project_id
        assert ready["revision"] == 0
        assert ready["model"]["classes"] == []
        assert ready["presence"] == [
            {"userId": "ana", "displayName": "Ana", "status": "active"}
        ]

        websocket.send_json({"type": "ping"})
        assert websocket.receive_json() == {"type": "pong"}


def test_room_broadcasts_presence_and_status(websocket_client: TestClient) -> None:
    project_id = create_project(websocket_client)

    with websocket_client.websocket_connect(websocket_path(project_id)) as ana:
        consume_ready(ana)
        with websocket_client.websocket_connect(
            websocket_path(project_id, "nico", "Nico")
        ) as nico:
            nico_ready = consume_ready(nico)
            ana_joined = ana.receive_json()
            assert [item["userId"] for item in nico_ready["presence"]] == ["ana", "nico"]
            assert [item["userId"] for item in ana_joined["presence"]] == ["ana", "nico"]

            nico.send_json({"type": "presence.update", "status": "editing"})
            ana_status = ana.receive_json()
            nico_status = nico.receive_json()
            assert ana_status == nico_status
            assert ana_status["presence"][1]["status"] == "editing"

        nico_left = ana.receive_json()
        assert nico_left["presence"] == [
            {"userId": "ana", "displayName": "Ana", "status": "active"}
        ]


def test_change_is_persisted_then_broadcast(websocket_client: TestClient) -> None:
    project_id = create_project(websocket_client)

    with websocket_client.websocket_connect(websocket_path(project_id)) as websocket:
        consume_ready(websocket)
        websocket.send_json(add_class_message(project_id))
        applied = websocket.receive_json()

        assert applied["type"] == "change.applied"
        assert applied["projectId"] == project_id
        assert applied["userId"] == "ana"
        assert applied["baseRevision"] == 0
        assert applied["revision"] == 1
        assert applied["rebased"] is False

    response = websocket_client.get(f"/projects/{project_id}/model")
    assert response.status_code == 200
    assert response.json()["model"] == class_model(project_id, 1)


def test_stale_move_uses_lww_but_structural_change_is_rejected(
    websocket_client: TestClient,
) -> None:
    project_id = create_project(websocket_client)
    created = websocket_client.post(
        f"/projects/{project_id}/changes",
        json={
            "base_revision": 0,
            "command": add_class_message(project_id)["command"],
            "model": class_model(project_id, 1),
        },
    )
    assert created.status_code == 201

    with websocket_client.websocket_connect(websocket_path(project_id)) as websocket:
        ready = consume_ready(websocket)
        assert ready["revision"] == 1

        websocket.send_json(move_message(project_id, "move-first", 1, 200))
        first_move = websocket.receive_json()
        assert first_move["revision"] == 2
        assert first_move["rebased"] is False

        stale_structure = add_class_message(project_id, base_revision=1)
        stale_structure["command"]["id"] = "stale-structure"
        websocket.send_json(stale_structure)
        rejected = websocket.receive_json()
        assert rejected["type"] == "change.rejected"
        assert rejected["code"] == "REVISION_CONFLICT"
        assert rejected["currentRevision"] == 2

        websocket.send_json(move_message(project_id, "move-last", 1, 300))
        last_move = websocket.receive_json()
        assert last_move["revision"] == 3
        assert last_move["baseRevision"] == 2
        assert last_move["rebased"] is True
        assert last_move["model"]["classes"][0]["position"]["x"] == 300

    current = websocket_client.get(f"/projects/{project_id}/model").json()
    assert current["revision"] == 3
    assert current["model"]["classes"][0]["position"]["x"] == 300


def test_protocol_errors_do_not_close_valid_connection(websocket_client: TestClient) -> None:
    project_id = create_project(websocket_client)

    with websocket_client.websocket_connect(websocket_path(project_id)) as websocket:
        consume_ready(websocket)
        websocket.send_json({"type": "unknown"})
        error = websocket.receive_json()
        assert error["type"] == "protocol.error"
        assert error["code"] == "INVALID_MESSAGE"

        websocket.send_json({"type": "ping"})
        assert websocket.receive_json() == {"type": "pong"}


def test_missing_project_is_reported_and_closed(websocket_client: TestClient) -> None:
    with websocket_client.websocket_connect(websocket_path("missing")) as websocket:
        error = websocket.receive_json()
        assert error["code"] == "PROJECT_NOT_FOUND"
        try:
            websocket.receive_json()
        except WebSocketDisconnect as disconnect:
            assert disconnect.code == 4404
        else:
            raise AssertionError("El servidor debía cerrar el WebSocket inexistente.")
