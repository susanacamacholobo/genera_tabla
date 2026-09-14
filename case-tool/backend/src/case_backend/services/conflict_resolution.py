from typing import Protocol

from case_backend.schemas import CanonicalProjectModel, ChangeCreate, Position


class RevisionConflictResolver(Protocol):
    def resolve(
        self,
        current_revision: int,
        current_model: CanonicalProjectModel,
        incoming: ChangeCreate,
    ) -> ChangeCreate | None: ...


class LastWriteWinsMoveResolver:
    """Rebase stale node movements without overwriting structural changes."""

    def resolve(
        self,
        current_revision: int,
        current_model: CanonicalProjectModel,
        incoming: ChangeCreate,
    ) -> ChangeCreate | None:
        command = incoming.command
        if command.type != "MOVE_CLASS" or command.target_id is None:
            return None

        try:
            position = Position.model_validate(command.payload.get("position"))
        except ValueError:
            return None

        classes = list(current_model.classes)
        for index, uml_class in enumerate(classes):
            if uml_class.id == command.target_id:
                classes[index] = uml_class.model_copy(update={"position": position})
                break
        else:
            return None

        rebased_model = current_model.model_copy(
            update={"revision": current_revision + 1, "classes": classes}
        )
        return ChangeCreate(
            base_revision=current_revision,
            command=command,
            model=rebased_model,
        )
