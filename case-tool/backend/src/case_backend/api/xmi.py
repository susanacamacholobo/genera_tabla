from typing import Annotated
from urllib.parse import quote

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile, status
from sqlalchemy.orm import Session

from case_backend.database import get_session
from case_backend.exporters.xmi import XMIExporter
from case_backend.importers.xmi import XMIImporter, XMIImportError
from case_backend.models import ProjectSnapshotRecord
from case_backend.schemas import CanonicalProjectModel, ProjectSnapshotResponse
from case_backend.services import ModelHistoryService, ProjectNotFoundError, ProjectService

router = APIRouter(prefix="/projects", tags=["XMI"])
DatabaseSession = Annotated[Session, Depends(get_session)]
XMIFile = Annotated[UploadFile, File(description="Archivo XMI 2.1 exportado por EA")]
XMIScope = Annotated[str | None, Query(max_length=200)]
MAX_XMI_BYTES = 5 * 1024 * 1024


def snapshot_response(snapshot: ProjectSnapshotRecord) -> ProjectSnapshotResponse:
    return ProjectSnapshotResponse(
        project_id=snapshot.project_id,
        revision=snapshot.revision,
        model=CanonicalProjectModel.model_validate(snapshot.model_json),
        created_at=snapshot.created_at,
    )


@router.post(
    "/xmi/import",
    response_model=ProjectSnapshotResponse,
    response_model_exclude_unset=True,
    status_code=status.HTTP_201_CREATED,
)
async def import_xmi(
    file: XMIFile,
    session: DatabaseSession,
    scope: XMIScope = None,
) -> ProjectSnapshotResponse:
    content = await file.read(MAX_XMI_BYTES + 1)
    if len(content) > MAX_XMI_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail="El archivo XMI supera el límite de 5 MiB.",
        )
    try:
        model = XMIImporter().import_bytes(content, scope=scope)
    except XMIImportError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(error)
        ) from error
    _, snapshot = ProjectService(session).import_project(model)
    return snapshot_response(snapshot)


@router.get("/{project_id}/xmi", response_class=Response)
def export_xmi(project_id: str, session: DatabaseSession) -> Response:
    try:
        snapshot = ModelHistoryService(session).get_current_snapshot(project_id)
    except ProjectNotFoundError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error)) from error
    model = CanonicalProjectModel.model_validate(snapshot.model_json)
    content = XMIExporter().export_bytes(model)
    filename = quote(f"{model.name}.xmi")
    return Response(
        content=content,
        media_type="application/xml",
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{filename}"},
    )
