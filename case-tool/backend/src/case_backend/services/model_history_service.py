from uuid import uuid4

from sqlalchemy.orm import Session

from case_backend.models import ChangeEventRecord, ProjectSnapshotRecord
from case_backend.repositories import ModelHistoryRepository, ProjectRepository
from case_backend.schemas import CanonicalProjectModel, ChangeCreate
from case_backend.services.conflict_resolution import RevisionConflictResolver
from case_backend.services.errors import (
    ModelProjectMismatchError,
    ModelRevisionMismatchError,
    ProjectNotFoundError,
    RevisionConflictError,
    SnapshotNotFoundError,
)


class ModelHistoryService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.projects = ProjectRepository(session)
        self.history = ModelHistoryRepository(session)

    @staticmethod
    def empty_model(project_id: str, name: str) -> CanonicalProjectModel:
        return CanonicalProjectModel(
            id=project_id,
            name=name,
            revision=0,
            classes=[],
            relationships=[],
            enumerations=[],
        )

    def add_initial_snapshot(self, project_id: str, name: str) -> ProjectSnapshotRecord:
        model = self.empty_model(project_id, name)
        return self.add_snapshot(model)

    def add_snapshot(self, model: CanonicalProjectModel) -> ProjectSnapshotRecord:
        snapshot = ProjectSnapshotRecord(
            id=str(uuid4()),
            project_id=model.id,
            revision=model.revision,
            model_json=model.model_dump(mode="json", by_alias=True, exclude_unset=True),
        )
        return self.history.add_snapshot(snapshot)

    def get_current_snapshot(self, project_id: str) -> ProjectSnapshotRecord:
        project = self.projects.get(project_id)
        if project is None:
            raise ProjectNotFoundError(project_id)
        snapshot = self.history.get_snapshot(project_id, project.revision)
        if snapshot is None:
            raise SnapshotNotFoundError(project_id)
        return snapshot

    def list_changes(self, project_id: str, after_revision: int) -> list[ChangeEventRecord]:
        if self.projects.get(project_id) is None:
            raise ProjectNotFoundError(project_id)
        return self.history.list_events(project_id, after_revision)

    def record_change(
        self,
        project_id: str,
        data: ChangeCreate,
        conflict_resolver: RevisionConflictResolver | None = None,
    ) -> tuple[ProjectSnapshotRecord, ChangeEventRecord]:
        project = self.projects.get_for_update(project_id)
        if project is None:
            raise ProjectNotFoundError(project_id)
        if data.base_revision != project.revision:
            resolved = None
            if conflict_resolver is not None:
                current_snapshot = self.history.get_snapshot(project_id, project.revision)
                if current_snapshot is None:
                    raise SnapshotNotFoundError(project_id)
                current_model = CanonicalProjectModel.model_validate(current_snapshot.model_json)
                resolved = conflict_resolver.resolve(project.revision, current_model, data)
            if resolved is None:
                raise RevisionConflictError(project.revision, data.base_revision)
            data = resolved

        next_revision = project.revision + 1
        if data.model.id != project_id:
            raise ModelProjectMismatchError(project_id, data.model.id)
        if data.model.revision != next_revision:
            raise ModelRevisionMismatchError(next_revision, data.model.revision)

        snapshot = ProjectSnapshotRecord(
            id=str(uuid4()),
            project_id=project_id,
            revision=next_revision,
            model_json=data.model.model_dump(mode="json", by_alias=True, exclude_unset=True),
        )
        event = ChangeEventRecord(
            id=str(uuid4()),
            project_id=project_id,
            command_id=data.command.id,
            base_revision=data.base_revision,
            revision=next_revision,
            command_json=data.command.model_dump(mode="json", by_alias=True, exclude_unset=True),
        )
        project.revision = next_revision
        self.history.add_event(event)
        self.history.add_snapshot(snapshot)
        self.session.commit()
        self.session.refresh(event)
        self.session.refresh(snapshot)
        return snapshot, event
