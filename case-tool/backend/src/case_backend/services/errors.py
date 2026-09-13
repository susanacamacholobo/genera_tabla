class ProjectNotFoundError(Exception):
    def __init__(self, project_id: str) -> None:
        super().__init__(f"No existe el proyecto '{project_id}'.")
        self.project_id = project_id


class RevisionConflictError(Exception):
    def __init__(self, expected_revision: int, received_revision: int) -> None:
        super().__init__(
            f"La revisión actual es {expected_revision}; se recibió {received_revision}."
        )
        self.expected_revision = expected_revision
        self.received_revision = received_revision


class ModelProjectMismatchError(Exception):
    def __init__(self, project_id: str, model_project_id: str) -> None:
        super().__init__(
            f"El modelo pertenece a '{model_project_id}', no al proyecto '{project_id}'."
        )


class ModelRevisionMismatchError(Exception):
    def __init__(self, expected_revision: int, received_revision: int) -> None:
        super().__init__(
            f"El modelo debe tener revisión {expected_revision}; contiene {received_revision}."
        )


class SnapshotNotFoundError(Exception):
    pass
