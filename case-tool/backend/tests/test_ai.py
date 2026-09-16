import json
from collections.abc import AsyncGenerator

import httpx
import pytest

from case_backend.api.ai import ai_client, ai_settings
from case_backend.config import Settings
from case_backend.main import app


def configured_settings(**overrides: str) -> Settings:
    return Settings(
        _env_file=None,
        case_ai_chat_url=overrides.get("url", "https://provider.test/v1/chat/completions"),
        case_ai_model=overrides.get("model", "example-model"),
        case_ai_api_key=overrides.get("key", "private-test-key"),
    )


@pytest.mark.anyio
async def test_ai_status_is_disabled_without_configuration(client: httpx.AsyncClient) -> None:
    app.dependency_overrides[ai_settings] = lambda: Settings(
        _env_file=None, case_ai_chat_url=None, case_ai_model=None
    )

    response = await client.get("/ai/status")

    assert response.status_code == 200
    assert response.json() == {"configured": False, "remote": False}


@pytest.mark.anyio
async def test_ai_proxy_keeps_key_on_server_and_returns_only_text(
    client: httpx.AsyncClient,
) -> None:
    app.dependency_overrides[ai_settings] = lambda: configured_settings()

    async def answer(request: httpx.Request) -> httpx.Response:
        assert request.url == "https://provider.test/v1/chat/completions"
        assert request.headers["Authorization"] == "Bearer private-test-key"
        payload = json.loads(request.content)
        assert payload["model"] == "example-model"
        assert payload["messages"][1]["content"] == "crea clase Cliente"
        return httpx.Response(200, json={
            "choices": [{"message": {"content": '{"actions":[{"type":"ADD_CLASS"}]}'}}]
        })

    async def mock_client() -> AsyncGenerator[httpx.AsyncClient, None]:
        async with httpx.AsyncClient(transport=httpx.MockTransport(answer)) as transport_client:
            yield transport_client

    app.dependency_overrides[ai_client] = mock_client

    status = await client.get("/ai/status")
    response = await client.post("/ai/generate", json={"prompt": "crea clase Cliente"})

    assert status.json() == {"configured": True, "remote": True}
    assert response.status_code == 200
    assert response.json() == {"response": '{"actions":[{"type":"ADD_CLASS"}]}' }
    assert "private-test-key" not in response.text


@pytest.mark.anyio
async def test_ai_proxy_rejects_unencrypted_external_endpoint(
    client: httpx.AsyncClient,
) -> None:
    app.dependency_overrides[ai_settings] = lambda: configured_settings(
        url="http://provider.test/v1/chat/completions"
    )

    response = await client.post("/ai/generate", json={"prompt": "crea clase Cliente"})

    assert response.status_code == 503


@pytest.mark.anyio
async def test_ai_proxy_hides_remote_errors(client: httpx.AsyncClient) -> None:
    app.dependency_overrides[ai_settings] = lambda: configured_settings()

    async def failed(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, text="secret-provider-stack-trace")

    async def mock_client() -> AsyncGenerator[httpx.AsyncClient, None]:
        async with httpx.AsyncClient(transport=httpx.MockTransport(failed)) as transport_client:
            yield transport_client

    app.dependency_overrides[ai_client] = mock_client
    response = await client.post("/ai/generate", json={"prompt": "crea clase Cliente"})

    assert response.status_code == 502
    assert "secret-provider-stack-trace" not in response.text
