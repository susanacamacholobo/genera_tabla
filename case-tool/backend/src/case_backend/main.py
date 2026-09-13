from fastapi import FastAPI

from case_backend.api.model_history import router as model_history_router
from case_backend.api.projects import router as projects_router

app = FastAPI(title="Software 1 CASE API", version="0.1.0")
app.include_router(projects_router)
app.include_router(model_history_router)


@app.get("/health", tags=["system"])
def health() -> dict[str, str]:
    return {"status": "ok"}
