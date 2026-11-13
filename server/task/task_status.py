"""Job status kept in Redis, so you can see what a job is doing and where it broke.

One record per upload, key  task:<task_id>
{
  "status":   "pending" | "processing_pdf" | "creating_video" | "done" | "failed",
  "percent":  0-100,
  "current":  {"stage", "step", "chunk", "total_chunks", "msg"},   <- what it is doing right now
  "events":   [ ... every step so far, with time ... ],             <- history
  "error", "failed_at", "traceback"                                 <- only when it failed
}
"""
import json
import logging
from datetime import datetime, timezone
from typing import Optional

from redis_client import redis_client

log = logging.getLogger(__name__)

TTL = 60 * 60 * 24  # 24h
MAX_EVENTS = 300

# the whole job is 0-100%: stage 1 is the first 40%, the video the rest
STAGE_RANGE = {"processing_pdf": (0, 40), "creating_video": (40, 100)}


def _now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def init_task(task_id: str, task_type: str, **fields):
    """Called by the API before the job is queued."""
    payload = {
        "task_type": task_type,
        "status": "pending",
        "percent": 0,
        "start_time": _now(),
        "json_path": "",
        "project_id": None,
        "project_name": "",
        "current": {"stage": "pending", "step": "queued", "chunk": None, "total_chunks": None, "msg": ""},
        "events": [],
        **fields,
    }
    redis_client.set(f"task:{task_id}", json.dumps(payload), ex=TTL)


def update_task(task_id: str, **fields):
    """Merge fields into an existing task record."""
    key = f"task:{task_id}"
    raw = redis_client.get(key)
    data = json.loads(raw) if raw else {}
    data.update(fields)
    redis_client.set(key, json.dumps(data), ex=TTL)


def get_task(task_id: str) -> Optional[dict]:
    raw = redis_client.get(f"task:{task_id}")
    return json.loads(raw) if raw else None


def log_step(task_id, stage, step, chunk=None, total=None, msg="", fraction=0.0, record=True):
    """Say what the job is doing now.
    fraction = how far through this stage (0 to 1). record=False updates the numbers
    without adding a line to the history (used for the frame counter while rendering)."""
    lo, hi = STAGE_RANGE.get(stage, (0, 100))
    percent = round(lo + (hi - lo) * max(0.0, min(1.0, fraction)), 1)
    current = {"stage": stage, "step": step, "chunk": chunk, "total_chunks": total, "msg": msg}

    data = get_task(task_id) or {}
    events = data.get("events", [])
    if record:
        events.append({"at": _now(), "percent": percent, **current})
    update_task(task_id, status=stage, percent=percent, current=current, events=events[-MAX_EVENTS:])

    if record:
        where = f" | chunk {chunk}/{total}" if chunk else ""
        log.info("[job %s] %s | %s%s %s (%s%%)", task_id[:8], stage, step, where, msg, percent)


def fail_task(task_id, error: str, traceback_text: str = ""):
    """Mark the job as failed and keep WHERE it was (the last step it started)."""
    data = get_task(task_id) or {}
    update_task(
        task_id,
        status="failed",
        error=error,
        failed_at=data.get("current"),
        traceback=traceback_text[-4000:],
        failed_time=_now(),
    )
