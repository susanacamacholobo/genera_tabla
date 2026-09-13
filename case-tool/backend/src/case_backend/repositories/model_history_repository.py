from sqlalchemy import select
from sqlalchemy.orm import Session

from case_backend.models import ChangeEventRecord, ProjectSnapshotRecord


class ModelHistoryRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get_snapshot(self, project_id: str, revision: int) -> ProjectSnapshotRecord | None:
        statement = select(ProjectSnapshotRecord).where(
            ProjectSnapshotRecord.project_id == project_id,
            ProjectSnapshotRecord.revision == revision,
        )
        return self.session.scalar(statement)

    def add_snapshot(self, snapshot: ProjectSnapshotRecord) -> ProjectSnapshotRecord:
        self.session.add(snapshot)
        self.session.flush()
        return snapshot

    def add_event(self, event: ChangeEventRecord) -> ChangeEventRecord:
        self.session.add(event)
        self.session.flush()
        return event

    def list_events(self, project_id: str, after_revision: int) -> list[ChangeEventRecord]:
        statement = (
            select(ChangeEventRecord)
            .where(
                ChangeEventRecord.project_id == project_id,
                ChangeEventRecord.revision > after_revision,
            )
            .order_by(ChangeEventRecord.revision)
        )
        return list(self.session.scalars(statement))
