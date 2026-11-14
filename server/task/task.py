import logging
import traceback

from utils.process_pdf import process_pdf
from celery_app import celery_app
from task.task_status import fail_task, log_step, update_task
from sqlmodel import Session

import crud
from create_video.compile_video import compile_video
from database import engine
from model import Chunk, Project 

from sqlmodel import Session, select
from config import IMAGES_DIR, OUTPUT_VIDEO_DIR, VIDEO_ASSET, AUDIO_DIR, PROCESS_PDF_DIR, JSON_DIR

log = logging.getLogger(__name__)

# The heavy libraries (whisper, moviepy, ...) are imported inside the tasks,
# so the API process doesn't load them just to queue a job.


def make_progress(job_id):
    """The function process_pdf / compile_video call to report what they are doing."""

    def progress(stage, step, **kwargs):
        try:
            log_step(job_id, stage, step, **kwargs)
        except Exception:  # a Redis hiccup must never kill the real job
            log.exception("could not write progress")

    return progress


# ---------- Stage 1: pdf -> chunks, summary, quiz, audio ----------
@celery_app.task(bind=True)
def run_process_pdf(self, pdf_path: str, filename: str, user_id: int):
    job_id = self.request.id  # the API creates the status record with this same id
    update_task(job_id, status="processing_pdf")

    try:

        result = process_pdf(pdf_path, filename, user_id, progress=make_progress(job_id))
    except Exception as e:
        log.exception("[job %s] stage 1 failed", job_id[:8])
        fail_task(job_id, f"{type(e).__name__}: {e}", traceback.format_exc())
        raise

    update_task(
        job_id,
        json_path=result["json_path"],
        project_id=result["project_id"],
        project_name=result["title"],
    )
    log_step(job_id, "creating_video", "queued", msg="waiting for the video worker", fraction=0.0)

    # stage 2 starts as soon as stage 1 is done
    run_video_pipeline.delay(result["json_path"], result["project_id"], job_id)
    return result


# ---------- Stage 2: chunks -> video ----------
@celery_app.task(bind=True)
def run_video_pipeline(self, json_path: str, project_id: int, job_id: str):
    try:
        result = compile_video(json_path, progress=make_progress(job_id))  # {"dir": video_path, "status": True}

        with Session(engine) as session:
            crud.set_video_path(session, project_id, result["dir"])
    except Exception as e:
        log.exception("[job %s] stage 2 failed", job_id[:8])
        fail_task(job_id, f"{type(e).__name__}: {e}", traceback.format_exc())
        raise

    log_step(job_id, "creating_video", "finished", msg=result["dir"], fraction=1.0)
    update_task(job_id, status="done", percent=100, video_path=result["dir"])
    return result


# # ---------- Stage 3: store all resource on r2 and clear local files ----------
# def migrate_resource(project_name) -> bool:
#     with Session(engine) as session:
#         project = session.exec(select(Project).where(Project.name == project_name)).first()
#         chucks = session.exec(select(Chunk).where(Chunk.project_id == project.id)).first()
        
#         if not project and chucks:
#             return False #log error
#         #send files with project_name in IMAGES_DIR, OUTPUT_VIDEO_DIR, VIDEO_ASSET, AUDIO_DIR, PROCESS_PDF_DIR, JSON_DIR to r2 
#         #and replace path in db with new path.
#         #remove all files with project_name in IMAGES_DIR, OUTPUT_VIDEO_DIR, VIDEO_ASSET, AUDIO_DIR, PROCESS_PDF_DIR, JSON_DIR
        
#     pass
