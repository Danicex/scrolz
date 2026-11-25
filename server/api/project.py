import json
import os
import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

import crud
from authentication.auth import CurrentUser
from config import PROCESS_PDF_DIR
from database import SessionDep
from task.task import run_process_pdf, run_video_pipeline
from task.task_status import get_task, init_task

router = APIRouter(prefix="/project", tags=["scrolz-api"])


def get_owned(session: SessionDep, project_id: int, user_id: int):
    project = crud.get_project(session, project_id)
    if not project or project.user_id != user_id:  # 404, so ids can't be probed
        raise HTTPException(404, "Project not found")
    return project


@router.post("/upload_pdf")
def upload_pdf(
    session: SessionDep,
    user_id: CurrentUser,
    # user_id: int,
    file: UploadFile = File(...),
):
    if not crud.get_user(session, user_id):
        raise HTTPException(404, "User not found")

    original_name = Path(file.filename or "").name
    if not original_name.lower().endswith(".pdf"):
        raise HTTPException(400, "Only .pdf files are accepted")

    # unique name, so two uploads with the same file name never overwrite each other
    os.makedirs(PROCESS_PDF_DIR, exist_ok=True)
    pdf_path = os.path.join(PROCESS_PDF_DIR, f"{uuid.uuid4().hex}_{original_name}")
    with open(pdf_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # 1) write the status record, 2) only then queue the job with the same id
    task_id = uuid.uuid4().hex
    init_task(task_id, task_type="process_pdf", project_name=original_name, user_id=user_id)
    
    run_process_pdf.apply_async(args=[pdf_path, original_name, user_id, task_id], task_id=task_id)

    return {"task_id": task_id, "status": "pending"}


@router.get("/task/{task_id}")
def task_status(task_id: str, debug: bool = False):
    """Where the job is. status: pending -> processing_pdf -> creating_video -> done (or failed).

    percent    0-100
    current    what it is doing right now (stage, step, chunk i of n)
    events     every step so far, with time
    failed_at  the step it was on when it broke (only if failed), plus `error`
    ?debug=true also returns the Python traceback (keep this off for real users)
    """
    task = get_task(task_id)
    if not task:
        raise HTTPException(404, "Task not found (it may have expired)")
    if not debug:
        task.pop("traceback", None)
    return task


@router.get("/")
def list_projects(session: SessionDep, user_id: CurrentUser):
    return crud.list_projects(session, user_id)


@router.get("/{project_id}")
def get_project(session: SessionDep, project_id: int, user_id: CurrentUser):
    return get_owned(session, project_id, user_id)


@router.get("/{project_id}/content")
def get_project_content(session: SessionDep, project_id: int, user_id: CurrentUser):
    """The chunks json: text, summary, quiz and audio path per chunk."""
    project = get_owned(session, project_id, user_id)
    with open(project.json_path, encoding="utf-8") as f:
        return json.load(f)


@router.patch("/{project_id}")
def update_project(session: SessionDep, project_id: int, title: str, user_id: CurrentUser):
    get_owned(session, project_id, user_id)
    return crud.update_project(session, project_id, title)


@router.delete("/{project_id}")
def delete_project(session: SessionDep, project_id: int, user_id: CurrentUser):
    get_owned(session, project_id, user_id)
    crud.delete_project(session, project_id)
    return {"deleted": project_id}


class VideoTaskPayload(BaseModel):
    task_id: str
    original_name: str
    json_path: str
    project_id: int
    job_id: str
    user_id: int


@router.post("/complete_video_task")
def complete_video_task(param: VideoTaskPayload):
    init_task(
        param.task_id,
        task_type="processing video",
        project_name=param.original_name,
        user_id=param.user_id,
    )
    run_video_pipeline.apply_async(
        args=[param.json_path, param.project_id, param.job_id],
        task_id=param.task_id,
    )
    return {
        "status": "started",
        "task_id": param.task_id,
        "project_id": param.project_id,
    }
