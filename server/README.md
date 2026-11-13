# scrolz server

## Set up
1. `pip install -r requirements.txt` (Python 3.10-3.12). Whisper also needs the `ffmpeg` program on your PATH.
2. Copy `.env.example` to `.env` and fill it in.
3. Put a few `.mp3` / `.wav` background tracks in `create_video/bg_sound/` (none = no background music).
4. Start Redis and Postgres.

## Run (two terminals, both from this folder)
```
uvicorn main:app --reload
celery -A celery_app worker -l info --concurrency=1      # Windows: add --pool=solo
```

## Flow
`POST /project/upload_pdf` (form: `user_id`, `file`) returns a `task_id`.
Poll `GET /project/task/{task_id}`: `pending -> processing_pdf -> creating_video -> done` (or `failed` with `error`).
When it is `done`, `GET /project/{project_id}` has `video_path`.

Create a user first with `POST /user/?email=you@example.com`.

## Notes
- The database tables are created on startup, but existing tables are NOT changed. If you ran an older
  version, drop the `projects` and `chunks` tables (or use Alembic) so the new columns are added.
- Pexels asks for a visible credit ("Photos provided by Pexels") wherever the media is shown. Free limit: 200 requests/hour.
