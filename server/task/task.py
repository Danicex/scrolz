import logging
import traceback

from utils.process_pdf import process_pdf
from celery_app import celery_app
from task.task_status import fail_task, log_step, update_task
from sqlmodel import Session

import crud
from create_video.compile_video import compile_video
from database import engine
from model import Chunk, Project, now

from sqlmodel import Session, select
import os
import shutil
import traceback
import mimetypes
from pathlib import Path

import boto3
from botocore.config import Config

from config import IMAGES_DIR, OUTPUT_VIDEO_DIR, VIDEO_ASSET, AUDIO_DIR, PROCESS_PDF_DIR, JSON_DIR

# --- adjust these imports to match your project ---
from database import engine                      # your SQLModel engine

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
def run_process_pdf(self, pdf_path: str, filename: str, user_id: int, task_id: int):
    job_id = self.request.id  # the API creates the status record with this same id
    update_task(job_id, status="processing_pdf")

    try:

        result = process_pdf(pdf_path, filename, user_id, task_id, progress=make_progress(job_id))
        
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
        result = compile_video(json_path, project_id,  progress=make_progress(job_id))  # {"dir": video_path, "status": True}

        with Session(engine) as session:
            crud.set_video_path(session, project_id, result["dir"])
            
    except Exception as e:
        log.exception("[job %s] stage 2 failed", job_id[:8])
        fail_task(job_id, f"{type(e).__name__}: {e}", traceback.format_exc())
        raise

    log_step(job_id, "creating_video", "finished", msg=result["dir"], fraction=1.0)
    update_task(job_id, status="done", percent=100, video_path=result["dir"])
    migrate_and_cleanup.delaay()
    return result



# ---------- Stage 2: migrate files to R2 and clean up ----------
# Single-file version: R2 client, helpers and the Celery task all live here.


# ---------------------------------------------------------------------------
# R2 helpers
# ---------------------------------------------------------------------------
def _r2_client():
    return boto3.client(
        "s3",
        endpoint_url=os.environ["R2_ENDPOINT_URL"],
        aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
        region_name="auto",
        config=Config(signature_version="s3v4", retries={"max_attempts": 3}),
    )


def _is_remote(path: str | None) -> bool:
    return bool(path) and path.startswith(("http://", "https://", "r2://"))


def _upload(client, bucket: str, local_path: str, key: str) -> str:
    """Upload one file and return the R2 key. Raises if the file is missing."""
    p = Path(local_path)
    if not p.is_file():
        raise FileNotFoundError(f"missing file for upload: {local_path}")
    content_type = mimetypes.guess_type(p.name)[0] or "application/octet-stream"
    client.upload_file(str(p), bucket, key, ExtraArgs={"ContentType": content_type})
    return key


# ---------------------------------------------------------------------------
# Cleanup helpers
# ---------------------------------------------------------------------------
def _safe_name(name: str | None) -> str:
    """Guard against empty/odd names so rmtree/glob can never hit a parent dir."""
    if not name or name.strip() in {".", ".."} or any(s in name for s in ("/", "\\")):
        raise ValueError(f"unsafe project_name for cleanup: {name!r}")
    return name.strip()


def _rm_dir(base: Path, project_name: str) -> int:
    target = base / project_name
    if target.is_dir():
        shutil.rmtree(target, ignore_errors=True)
        return 1
    return 0


def _rm_files_containing(base: Path, project_name: str) -> int:
    removed = 0
    if not base.is_dir():
        return removed
    for f in base.rglob("*"):
        if f.is_file() and project_name in f.name:
            try:
                f.unlink()
                removed += 1
            except OSError:
                log.warning("could not delete %s", f)
    return removed


# ---------------------------------------------------------------------------
# Task
# ---------------------------------------------------------------------------
@celery_app.task(bind=True)
def migrate_and_cleanup(self, project_id: int, job_id: str):

    try:
        # R2 bucket names only allow lowercase letters, numbers and hyphens (no underscores)
        cover_bucket = os.environ.get("R2_BUCKET_COVERS",'' )
        video_bucket = os.environ.get("R2_BUCKET_VIDEOS",'')
        audio_bucket = os.environ.get("R2_BUCKET_AUDIO",'')
        client = _r2_client()
        log_step(job_id, "migrate & clean up", "started", fraction=0.0)

        with Session(engine) as session:
            project = session.get(Project, project_id)
            if not project:
                raise ValueError(f"project {project_id} not found")

            chunks = session.exec(
                select(Chunk).where(Chunk.project_id == project_id).order_by(Chunk.index)
            ).all()

            # folder name used on disk
            project_name = _safe_name(
                next((c.project_name for c in chunks if c.project_name), None) or project.title
            )
            prefix = f"projects/{project_id}"

            uploaded = 0
            total = len(chunks) * 2 + 1  # video + audio per chunk + cover

            # ---- 1. upload + update DB paths ----
            for c in chunks:
                if c.video_url and not _is_remote(c.video_url):
                    key = f"{prefix}/{c.key}{Path(c.video_url).suffix or '.mp4'}"
                    c.video_url = _upload(client, video_bucket, c.video_url, key)
                uploaded += 1

                if c.audio and not _is_remote(c.audio):
                    key = f"{prefix}/{c.key}{Path(c.audio).suffix or '.mp3'}"
                    c.audio = _upload(client, audio_bucket, c.audio, key)
                uploaded += 1

                session.add(c)
                log_step(job_id, "migrate & clean up", "uploading", fraction=0.8 * uploaded / total)

            if project.cover and not _is_remote(project.cover):
                key = f"{prefix}/cover{Path(project.cover).suffix or '.jpg'}"
                project.cover = _upload(client, cover_bucket, project.cover, key)
            uploaded += 1

            project.updated_at = now()
            session.add(project)
            session.commit()  # only commit after every upload succeeded

        # ---- 2. cleanup local files (only reached if uploads + commit succeeded) ----
        log_step(job_id, "migrate & clean up", "cleaning", fraction=0.9)
        removed_dirs = sum(
            _rm_dir(Path(base), project_name)
            for base in (OUTPUT_VIDEO_DIR, VIDEO_ASSET, AUDIO_DIR)
        )
        removed_files = sum(
            _rm_files_containing(Path(base), project_name)
            for base in (PROCESS_PDF_DIR, JSON_DIR, IMAGES_DIR)
        )

        result = {
            "dir": prefix,
            "project_id": project_id,
            "project_name": project_name,
            "removed_dirs": removed_dirs,
            "removed_files": removed_files,
        }

    except Exception as e:
        log.exception("[job %s] stage 3 failed", job_id[:8])
        fail_task(job_id, f"{type(e).__name__}: {e}", traceback.format_exc())
        raise

    log_step(job_id, "migrate & clean up", "finished", msg=result["dir"], fraction=1.0)
    update_task(job_id, status="done", percent=100, video_path=result["dir"])
    return result


