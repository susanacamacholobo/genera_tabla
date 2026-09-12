from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from case_backend.database import get_session
from case_backend.schemas import ProjectCreate, ProjectResponse, ProjectUpdate
from case_backend.services import ProjectNotFoundError, ProjectService

router = APIRouter(prefix="/projects", tags=["projects"])
DatabaseSession = Annotated[Session, Depends(get_session)]


def not_found(error: ProjectNotFoundError) -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error))


@router.post("", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
def create_project(data: ProjectCreate, session: DatabaseSession) -> ProjectResponse:
    project = ProjectService(session).create_project(data)
    return ProjectResponse.model_validate(project)


@router.get("", response_model=list[ProjectResponse])
def list_projects(session: DatabaseSession) -> list[ProjectResponse]:
    projects = ProjectService(session).list_projects()
    return [ProjectResponse.model_validate(project) for project in projects]


@router.get("/{project_id}", response_model=ProjectResponse)
def get_project(project_id: str, session: DatabaseSession) -> ProjectResponse:
    try:
        project = ProjectService(session).get_project(project_id)
    except ProjectNotFoundError as error:
        raise not_found(error) from error
    return ProjectResponse.model_validate(project)


@router.put("/{project_id}", response_model=ProjectResponse)
def update_project(
    project_id: str, data: ProjectUpdate, session: DatabaseSession
) -> ProjectResponse:
    try:
        project = ProjectService(session).update_project(project_id, data)
    except ProjectNotFoundError as error:
        raise not_found(error) from error
    return ProjectResponse.model_validate(project)


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project(project_id: str, session: DatabaseSession) -> Response:
    try:
        ProjectService(session).delete_project(project_id)
    except ProjectNotFoundError as error:
        raise not_found(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)

