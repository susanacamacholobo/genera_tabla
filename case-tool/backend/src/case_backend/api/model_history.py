from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from case_backend.database import get_session
from case_backend.models import ChangeEventRecord, ProjectSnapshotRecord
from case_backend.schemas import (
    CanonicalProjectModel,
    ChangeAppliedResponse,
    ChangeCreate,
    ChangeEventResponse,
    CommandPayload,
    ProjectSnapshotResponse,
)
from case_backend.services import (
    ModelHistoryService,
    ModelProjectMismatchError,
    ModelRevisionMismatchError,
    ProjectNotFoundError,
    RevisionConflictError,
    SnapshotNotFoundError,
)

router = APIRouter(prefix="/projects", tags=["model history"])
DatabaseSession = Annotated[Session, Depends(get_session)]


def project_not_found(error: ProjectNotFoundError) -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error))


def snapshot_response(snapshot: ProjectSnapshotRecord) -> ProjectSnapshotResponse:
    return ProjectSnapshotResponse(
        project_id=snapshot.project_id,
        revision=snapshot.revision,
        model=CanonicalProjectModel.model_validate(snapshot.model_json),
        created_at=snapshot.created_at,
    )


def event_response(event: ChangeEventRecord) -> ChangeEventResponse:
    return ChangeEventResponse(
        id=event.id,
        project_id=event.project_id,
        base_revision=event.base_revision,
        revision=event.revision,
        command=CommandPayload.model_validate(event.command_json),
        created_at=event.created_at,
    )


@router.get(
    "/{project_id}/model",
    response_model=ProjectSnapshotResponse,
    response_model_exclude_unset=True,
)
def get_current_model(project_id: str, session: DatabaseSession) -> ProjectSnapshotResponse:
    try:
        snapshot = ModelHistoryService(session).get_current_snapshot(project_id)
    except ProjectNotFoundError as error:
        raise project_not_found(error) from error
    except SnapshotNotFoundError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El proyecto todavía no tiene un snapshot.",
        ) from error
    return snapshot_response(snapshot)


@router.get(
    "/{project_id}/changes",
    response_model=list[ChangeEventResponse],
    response_model_exclude_unset=True,
)
def list_changes(
    project_id: str,
    session: DatabaseSession,
    after_revision: Annotated[int, Query(ge=0)] = 0,
) -> list[ChangeEventResponse]:
    try:
        events = ModelHistoryService(session).list_changes(project_id, after_revision)
    except ProjectNotFoundError as error:
        raise project_not_found(error) from error
    return [event_response(event) for event in events]


@router.post(
    "/{project_id}/changes",
    response_model=ChangeAppliedResponse,
    response_model_exclude_unset=True,
    status_code=status.HTTP_201_CREATED,
)
def record_change(
    project_id: str, data: ChangeCreate, session: DatabaseSession
) -> ChangeAppliedResponse:
    try:
        snapshot, event = ModelHistoryService(session).record_change(project_id, data)
    except ProjectNotFoundError as error:
        raise project_not_found(error) from error
    except RevisionConflictError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "message": str(error),
                "current_revision": error.expected_revision,
                "received_revision": error.received_revision,
            },
        ) from error
    except (ModelProjectMismatchError, ModelRevisionMismatchError) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(error)
        ) from error
    return ChangeAppliedResponse(
        snapshot=snapshot_response(snapshot),
        event=event_response(event),
    )
