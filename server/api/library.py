from fastapi import APIRouter, HTTPException

import crud
from authentication.auth import CurrentUser
from database import SessionDep

router = APIRouter(prefix="/library", tags=["library-api"])


@router.get("/all_projects")
def all_projects(session: SessionDep, user_id: CurrentUser):
    return crud.list_projects(session, user_id)


@router.get("/chunks")
def chunks(session: SessionDep, user_id: CurrentUser, project_id: int):
    project = crud.get_project(session, project_id)
    if not project or project.user_id != user_id:
        raise HTTPException(404, "Project not found")
    return crud.get_project_chunks(session, project_id)