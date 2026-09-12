from sqlalchemy import select
from sqlalchemy.orm import Session

from case_backend.models import ProjectRecord


class ProjectRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list(self) -> list[ProjectRecord]:
        statement = select(ProjectRecord).order_by(ProjectRecord.created_at, ProjectRecord.id)
        return list(self.session.scalars(statement))

    def get(self, project_id: str) -> ProjectRecord | None:
        return self.session.get(ProjectRecord, project_id)

    def add(self, project: ProjectRecord) -> ProjectRecord:
        self.session.add(project)
        self.session.flush()
        return project

    def delete(self, project: ProjectRecord) -> None:
        self.session.delete(project)
        self.session.flush()

