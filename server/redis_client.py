# NOTE: this file must NOT be called redis.py, or it hides the real "redis" package.
import redis

from config import REDIS_URL

# plain (sync) client: Celery tasks and the API both call it without await
redis_client = redis.Redis.from_url(REDIS_URL, decode_responses=True)
