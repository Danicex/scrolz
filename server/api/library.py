from fastapi import APIRouter, File, Form, HTTPException, UploadFile
import crud
from database import SessionDep
from pydantic import BaseModel

router = APIRouter(prefix="/library", tags=["library-api"])
#get all projects 
@router.post("/all_projects")
def list_projects(session: SessionDep, user_id: int):
    return crud.list_projects(session, user_id)


#get chunks for project
@router.post("/chunks/{project_id}")
def list_projects(session: SessionDep, user_id: int, project_id: int):
    return crud.get_project_chunks(session, project_id)