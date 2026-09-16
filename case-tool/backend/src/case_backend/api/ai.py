from collections.abc import AsyncGenerator
from typing import Annotated
from urllib.parse import urlsplit

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from case_backend.config import Settings, get_settings

router = APIRouter(prefix="/ai", tags=["CASE AI"])


class AIRequest(BaseModel):
    prompt: str = Field(min_length=1, max_length=20000)


class AIResponse(BaseModel):
    response: str


class AIStatus(BaseModel):
    configured: bool
    remote: bool


def ai_settings() -> Settings:
    return get_settings()


async def ai_client() -> AsyncGenerator[httpx.AsyncClient, None]:
    async with httpx.AsyncClient(timeout=60.0) as client:
        yield client


def configuration(settings: Settings) -> tuple[str, str] | None:
    url = settings.case_ai_chat_url
    model = settings.case_ai_model
    if not url or not model:
        return None
    try:
        parsed = urlsplit(url)
    except ValueError:
        return None
    local_hosts = {"localhost", "127.0.0.1", "::1"}
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        return None
    if parsed.scheme == "http" and parsed.hostname not in local_hosts:
        return None
    if parsed.username or parsed.password or parsed.fragment or parsed.query:
        return None
    return url, model


@router.get("/status", response_model=AIStatus)
def status(settings: Annotated[Settings, Depends(ai_settings)]) -> AIStatus:
    configured = configuration(settings)
    if not configured:
        return AIStatus(configured=False, remote=False)
    host = urlsplit(configured[0]).hostname
    return AIStatus(configured=True, remote=host not in {"localhost", "127.0.0.1", "::1"})


@router.post("/generate", response_model=AIResponse)
async def generate(
    request: AIRequest,
    settings: Annotated[Settings, Depends(ai_settings)],
    client: Annotated[httpx.AsyncClient, Depends(ai_client)],
) -> AIResponse:
    configured = configuration(settings)
    if not configured:
        raise HTTPException(status_code=503, detail="El proveedor de IA CASE no está configurado.")
    url, model = configured
    api_key = settings.case_ai_api_key.get_secret_value()
    headers = {"Authorization": f"Bearer {api_key}"} if api_key else {}
    try:
        response = await client.post(
            url,
            json={
                "model": model,
                "messages": [
                    {"role": "system", "content": "Interpreta sólo la petición UML del usuario. Responde únicamente un objeto JSON con una acción permitida. No inventes requisitos ni ejecutas cambios."},
                    {"role": "user", "content": request.prompt},
                ],
            },
            headers=headers,
        )
        response.raise_for_status()
        body = response.json()
        content = body["choices"][0]["message"]["content"]
        if not isinstance(content, str) or not content.strip() or len(content) > 20000:
            raise ValueError("invalid response")
    except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError) as error:
        raise HTTPException(
            status_code=502,
            detail="El proveedor de IA CASE no devolvió una respuesta válida.",
        ) from error
    return AIResponse(response=content)
