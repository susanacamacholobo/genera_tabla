import argparse
import json
from typing import Any
from urllib.parse import urlencode, urlsplit, urlunsplit
from urllib.request import Request, urlopen

from websockets.sync.client import connect


def http_json(base_url: str, method: str, path: str, body: object | None = None) -> Any:
    data = None if body is None else json.dumps(body).encode()
    request = Request(
        f"{base_url.rstrip('/')}{path}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    with urlopen(request, timeout=10) as response:
        payload = response.read()
        return None if not payload else json.loads(payload)


def websocket_url(base_url: str, project_id: str, user_id: str, name: str) -> str:
    parsed = urlsplit(base_url)
    query = urlencode({"userId": user_id, "displayName": name})
    scheme = "wss" if parsed.scheme == "https" else "ws"
    return urlunsplit((scheme, parsed.netloc, f"/ws/projects/{project_id}", query, ""))


def receive_json(websocket: object) -> dict[str, Any]:
    return json.loads(websocket.recv(timeout=10))


def assert_type(message: dict[str, Any], expected: str) -> None:
    if message.get("type") != expected:
        raise RuntimeError(f"Se esperaba {expected}; se recibió {message!r}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Prueba WebSocket contra un backend activo.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    args = parser.parse_args()

    project = http_json(args.base_url, "POST", "/projects", {"name": "Smoke colaboración"})
    project_id = project["id"]
    try:
        with connect(websocket_url(args.base_url, project_id, "ana", "Ana")) as ana:
            ana_ready = receive_json(ana)
            assert_type(ana_ready, "session.ready")
            assert_type(receive_json(ana), "presence.changed")

            with connect(websocket_url(args.base_url, project_id, "nico", "Nico")) as nico:
                nico_ready = receive_json(nico)
                assert_type(nico_ready, "session.ready")
                assert_type(receive_json(nico), "presence.changed")
                ana_presence = receive_json(ana)
                assert_type(ana_presence, "presence.changed")
                if len(ana_presence["presence"]) != 2:
                    raise RuntimeError("La room no informó ambos participantes.")

                model = {
                    "id": project_id,
                    "name": "Smoke colaboración",
                    "revision": 1,
                    "classes": [
                        {
                            "id": "class-smoke",
                            "name": "Prueba",
                            "position": {"x": 100, "y": 100},
                            "attributes": [],
                        }
                    ],
                    "relationships": [],
                    "enumerations": [],
                }
                ana.send(
                    json.dumps(
                        {
                            "type": "change.submit",
                            "baseRevision": 0,
                            "command": {
                                "id": "command-smoke",
                                "type": "ADD_CLASS",
                                "payload": {
                                    "id": "class-smoke",
                                    "name": "Prueba",
                                    "position": {"x": 100, "y": 100},
                                },
                            },
                            "model": model,
                        }
                    )
                )
                ana_event = receive_json(ana)
                nico_event = receive_json(nico)
                assert_type(ana_event, "change.applied")
                assert_type(nico_event, "change.applied")
                if ana_event["eventId"] != nico_event["eventId"]:
                    raise RuntimeError("Los clientes recibieron eventos distintos.")

        current = http_json(args.base_url, "GET", f"/projects/{project_id}/model")
        if current["revision"] != 1 or current["model"]["classes"][0]["id"] != "class-smoke":
            raise RuntimeError("El evento difundido no quedó persistido.")

        print(
            json.dumps(
                {
                    "projectId": project_id,
                    "participants": 2,
                    "eventId": ana_event["eventId"],
                    "persistedRevision": current["revision"],
                    "result": "ok",
                },
                ensure_ascii=False,
            )
        )
    finally:
        http_json(args.base_url, "DELETE", f"/projects/{project_id}")


if __name__ == "__main__":
    main()
