from dataclasses import dataclass
from uuid import uuid4

from fastapi import WebSocket


@dataclass(slots=True)
class CollaborationConnection:
    id: str
    user_id: str
    display_name: str
    status: str
    websocket: WebSocket


class CollaborationManager:
    """In-memory project rooms for the single-process collaboration MVP."""

    def __init__(self) -> None:
        self._rooms: dict[str, dict[str, CollaborationConnection]] = {}

    async def connect(
        self,
        project_id: str,
        websocket: WebSocket,
        user_id: str,
        display_name: str,
    ) -> CollaborationConnection:
        await websocket.accept()
        connection = CollaborationConnection(
            id=str(uuid4()),
            user_id=user_id,
            display_name=display_name,
            status="active",
            websocket=websocket,
        )
        self._rooms.setdefault(project_id, {})[connection.id] = connection
        return connection

    def disconnect(self, project_id: str, connection_id: str) -> bool:
        room = self._rooms.get(project_id)
        if room is None or room.pop(connection_id, None) is None:
            return False
        if not room:
            self._rooms.pop(project_id, None)
        return True

    def update_status(self, project_id: str, connection_id: str, status: str) -> None:
        connection = self._rooms[project_id][connection_id]
        connection.status = status

    def presence(self, project_id: str) -> list[dict[str, str]]:
        room = self._rooms.get(project_id, {})
        users: dict[str, dict[str, str]] = {}
        status_priority = {"away": 0, "active": 1, "editing": 2}
        for connection in room.values():
            previous = users.get(connection.user_id)
            if previous is None or status_priority[connection.status] > status_priority[
                previous["status"]
            ]:
                users[connection.user_id] = {
                    "userId": connection.user_id,
                    "displayName": connection.display_name,
                    "status": connection.status,
                }
        return [users[user_id] for user_id in sorted(users)]

    async def broadcast(self, project_id: str, message: dict[str, object]) -> None:
        room = self._rooms.get(project_id, {})
        disconnected: list[str] = []
        for connection_id, connection in list(room.items()):
            try:
                await connection.websocket.send_json(message)
            except RuntimeError:
                disconnected.append(connection_id)
        for connection_id in disconnected:
            self.disconnect(project_id, connection_id)

    async def broadcast_presence(self, project_id: str) -> None:
        await self.broadcast(
            project_id,
            {
                "type": "presence.changed",
                "projectId": project_id,
                "presence": self.presence(project_id),
            },
        )

    def clear(self) -> None:
        """Drop room bookkeeping during application/test shutdown."""
        self._rooms.clear()


collaboration_manager = CollaborationManager()
