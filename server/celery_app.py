from celery import Celery

from config import REDIS_URL

# Redis is both the broker and the result backend
celery_app = Celery(
    "scrolz",
    broker=REDIS_URL,
    backend=REDIS_URL,
    include=["task.task"],  # without this the worker doesn't know the tasks
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
    worker_prefetch_multiplier=1,  # long jobs: take one at a time
)

# run the worker with:  celery -A celery_app worker -l info --concurrency=1
