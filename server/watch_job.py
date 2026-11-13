"""Watch an upload job from the terminal.

    python watch_job.py <task_id>
    python watch_job.py <task_id> --url http://localhost:8000

Prints every new step as it happens, and if the job fails, where it failed and the traceback.
"""
import argparse
import time

import requests


def watch(task_id, base_url="http://localhost:8000", interval=2.0, get=requests.get, out=print):
    seen = 0
    last_percent = None
    while True:
        r = get(f"{base_url}/project/task/{task_id}", params={"debug": "true"}, timeout=10)
        if r.status_code == 404:
            out("task not found (wrong id, or it expired after 24h)")
            return None
        task = r.json()

        events = task.get("events", [])
        for e in events[seen:]:
            where = f" chunk {e['chunk']}/{e['total_chunks']}" if e.get("chunk") else ""
            out(f"{e['at'][11:19]}  {e['percent']:5.1f}%  {e['stage']:<15} {e['step']:<20}{where}  {e.get('msg') or ''}")
        seen = len(events)

        percent = task.get("percent")
        cur = task.get("current") or {}
        if percent != last_percent and cur.get("step") == "rendering":
            out(f"          {percent:5.1f}%  rendering: {cur.get('msg')}")
        last_percent = percent

        if task["status"] == "done":
            out(f"DONE  video: {task.get('video_path')}   project_id: {task.get('project_id')}")
            return task
        if task["status"] == "failed":
            at = task.get("failed_at") or {}
            out("")
            out(f"FAILED during  {at.get('stage')} / {at.get('step')}"
                + (f" / chunk {at['chunk']} of {at['total_chunks']}" if at.get("chunk") else ""))
            out(f"error: {task.get('error')}")
            if task.get("traceback"):
                out("--- traceback ---")
                out(task["traceback"])
            return task
        time.sleep(interval)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("task_id")
    ap.add_argument("--url", default="http://localhost:8000")
    args = ap.parse_args()
    watch(args.task_id, args.url)
