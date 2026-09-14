from typing import Annotated

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from pydantic import ValidationError
from sqlalchemy.orm import Session

from case_backend.collaboration import collaboration_manager
from case_backend.database import get_session
from case_backend.schemas import (
    ChangeCreate,
    CollaborationChangeMessage,
    CollaborationPingMessage,
    CollaborationPresenceMessage,
    collaboration_client_message_adapter,
)
from case_backend.services import (
    LastWriteWinsMoveResolver,
    ModelHistoryService,
    ModelProjectMismatchError,
    ModelRevisionMismatchError,
    ProjectNotFoundError,
    RevisionConflictError,
    SnapshotNotFoundError,
)

router = APIRouter(tags=["collaboration"])
DatabaseSession = Annotated[Session, Depends(get_session)]
move_conflict_resolver = LastWriteWinsMoveResolver()


def model_json(model: object) -> dict[str, object]:
    return model.model_dump(mode="json", by_alias=True, exclude_unset=True)


async def reject_connection(websocket: WebSocket, code: str, message: str, close: int) -> None:
    await websocket.accept()
    await websocket.send_json({"type": "protocol.error", "code": code, "message": message})
    await websocket.close(code=close, reason=message)


@router.websocket("/ws/projects/{project_id}")
async def collaborate(
    websocket: WebSocket,
    project_id: str,
    session: DatabaseSession,
) -> None:
    user_id = (websocket.query_params.get("userId") or "").strip()
    display_name = (websocket.query_params.get("displayName") or "").strip()
    if not user_id or not display_name or len(user_id) > 200 or len(display_name) > 200:
        await reject_connection(
            websocket,
            "INVALID_IDENTITY",
            "userId y displayName son obligatorios y admiten hasta 200 caracteres.",
            4400,
        )
        return

    history = ModelHistoryService(session)
    try:
        snapshot = history.get_current_snapshot(project_id)
    except (ProjectNotFoundError, SnapshotNotFoundError):
        session.rollback()
        await reject_connection(
            websocket,
            "PROJECT_NOT_FOUND",
            f"No existe el proyecto '{project_id}'.",
            4404,
        )
        return
    session.rollback()

    connection = await collaboration_manager.connect(
        project_id, websocket, user_id, display_name
    )
    connected = True
    try:
        await websocket.send_json(
            {
                "type": "session.ready",
                "projectId": project_id,
                "userId": user_id,
                "revision": snapshot.revision,
                "model": snapshot.model_json,
                "presence": collaboration_manager.presence(project_id),
            }
        )
        await collaboration_manager.broadcast_presence(project_id)

        while True:
            try:
                raw_message = await websocket.receive_json()
                message = collaboration_client_message_adapter.validate_python(raw_message)
            except WebSocketDisconnect:
                break
            except (KeyError, TypeError, ValueError, ValidationError) as error:
                await websocket.send_json(
                    {
                        "type": "protocol.error",
                        "code": "INVALID_MESSAGE",
                        "message": "El mensaje no cumple el protocolo de colaboración.",
                        "details": str(error),
                    }
                )
                continue

            if isinstance(message, CollaborationPingMessage):
                await websocket.send_json({"type": "pong"})
                continue

            if isinstance(message, CollaborationPresenceMessage):
                collaboration_manager.update_status(project_id, connection.id, message.status)
                await collaboration_manager.broadcast_presence(project_id)
                continue

            if isinstance(message, CollaborationChangeMessage):
                incoming_revision = message.base_revision
                try:
                    snapshot, event = history.record_change(
                        project_id,
                        ChangeCreate(
                            base_revision=message.base_revision,
                            command=message.command,
                            model=message.model,
                        ),
                        conflict_resolver=move_conflict_resolver,
                    )
                except RevisionConflictError as error:
                    session.rollback()
                    await websocket.send_json(
                        {
                            "type": "change.rejected",
                            "code": "REVISION_CONFLICT",
                            "projectId": project_id,
                            "currentRevision": error.expected_revision,
                            "receivedRevision": error.received_revision,
                            "message": str(error),
                        }
                    )
                    continue
                except (ModelProjectMismatchError, ModelRevisionMismatchError) as error:
                    session.rollback()
                    await websocket.send_json(
                        {
                            "type": "change.rejected",
                            "code": "INVALID_MODEL",
                            "projectId": project_id,
                            "message": str(error),
                        }
                    )
                    continue

                await collaboration_manager.broadcast(
                    project_id,
                    {
                        "type": "change.applied",
                        "eventId": event.id,
                        "projectId": project_id,
                        "userId": user_id,
                        "baseRevision": event.base_revision,
                        "revision": event.revision,
                        "command": model_json(message.command),
                        "model": snapshot.model_json,
                        "rebased": incoming_revision != event.base_revision,
                        "createdAt": event.created_at.isoformat(),
                    },
                )
    finally:
        if connected and collaboration_manager.disconnect(project_id, connection.id):
            await collaboration_manager.broadcast_presence(project_id)
