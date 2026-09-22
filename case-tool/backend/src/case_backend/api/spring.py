from typing import Annotated
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from case_backend.database import get_session
from case_backend.schemas import CanonicalProjectModel
from case_backend.services import (
    ModelHistoryService,
    ProjectNotFoundError,
    SnapshotNotFoundError,
)

router = APIRouter(prefix="/projects", tags=["Spring generation"])
DatabaseSession = Annotated[Session, Depends(get_session)]


@router.get("/{project_id}/spring.zip", response_class=Response)
def download_spring_backend(project_id: str, session: DatabaseSession) -> Response:
    try:
        snapshot = ModelHistoryService(session).get_current_snapshot(project_id)
    except ProjectNotFoundError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error)) from error
    except SnapshotNotFoundError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El proyecto todavía no tiene un snapshot.",
        ) from error

    model = CanonicalProjectModel.model_validate(snapshot.model_json)
    try:
        from spring_generator import SpringGenerator
        from spring_generator.validation import GenerationValidationError
    except ModuleNotFoundError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="El generador Spring no está instalado en el entorno del backend CASE.",
        ) from error

    try:
        generated = SpringGenerator().generate(model.model_dump(mode="json", by_alias=True))
    except GenerationValidationError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=[
                {"code": item.code, "path": item.path, "message": item.message}
                for item in error.issues
            ],
        ) from error

    filename = quote(f"{model.name}.zip", safe="")
    return Response(
        content=generated.to_zip_bytes(),
        media_type="application/zip",
        headers={
            "Content-Disposition": f"attachment; filename*=UTF-8''{filename}",
            "Cache-Control": "no-store",
        },
    )
