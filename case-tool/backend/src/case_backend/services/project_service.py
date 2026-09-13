from uuid import uuid4

from sqlalchemy.orm import Session

from case_backend.models import ProjectRecord
from case_backend.repositories import ProjectRepository
from case_backend.schemas import ProjectCreate, ProjectUpdate
from case_backend.services.errors import ProjectNotFoundError
from case_backend.services.model_history_service import ModelHistoryService


class ProjectService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.repository = ProjectRepository(session)

    def list_projects(self) -> list[ProjectRecord]:
        return self.repository.list()

    def get_project(self, project_id: str) -> ProjectRecord:
        project = self.repository.get(project_id)
        if project is None:
            raise ProjectNotFoundError(project_id)
        return project

    def create_project(self, data: ProjectCreate) -> ProjectRecord:
        project = ProjectRecord(id=str(uuid4()), name=data.name, revision=0)
        self.repository.add(project)
        ModelHistoryService(self.session).add_initial_snapshot(project.id, project.name)
        self.session.commit()
        self.session.refresh(project)
        return project

    def update_project(self, project_id: str, data: ProjectUpdate) -> ProjectRecord:
        project = self.get_project(project_id)
        project.name = data.name
        self.session.commit()
        self.session.refresh(project)
        return project

    def delete_project(self, project_id: str) -> None:
        project = self.get_project(project_id)
        self.repository.delete(project)
        self.session.commit()
