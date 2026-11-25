import os

from dotenv import load_dotenv

load_dotenv()  # reads .env

# every folder is absolute, so the API and the Celery worker agree
# no matter which folder they were started from
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_URL = os.getenv("BASE_URL")
POSTGRES_URL = os.getenv("POSTGRES_URL")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# LLM (OpenAI). Change the model in .env if you like.
LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4o-mini")

# stock visuals (https://www.pexels.com/api/)
PIXABAY_API_KEY = os.getenv("PIXABAY_API_KEY")

# captions
WHISPER_MODEL = os.getenv("WHISPER_MODEL", "base")
CAPTION_FONT = os.getenv(
    "CAPTION_FONT", os.path.join(BASE_DIR, "create_video", "fonts", "DejaVuSans-Bold.ttf")
)

AUDIO_DIR = os.path.join(BASE_DIR, "audio")

JSON_DIR = os.path.join(BASE_DIR, "json")
IMAGES_DIR = os.path.join(BASE_DIR, "images")
VIDEO_ASSET = os.path.join(BASE_DIR, "video_assets")  # video_assets/<project>_<chunk>/0.jpg ...
OUTPUT_VIDEO_DIR = os.path.join(BASE_DIR, "videos")
PROCESS_PDF_DIR = os.path.join(BASE_DIR, "process_pdf")
BG_SOUND_DIR = os.path.join(BASE_DIR, "create_video", "bg_sound")  # put your .mp3/.wav tracks here

for folder in (AUDIO_DIR, JSON_DIR, IMAGES_DIR, VIDEO_ASSET, OUTPUT_VIDEO_DIR, PROCESS_PDF_DIR, BG_SOUND_DIR):
    os.makedirs(folder, exist_ok=True)

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", str(60 * 24 * 7)))  # 7 days
CLERK_SECRET_KEY = os.getenv("CLERK_SECRET_KEY")
CLERK_ISSUER = os.getenv("CLERK_ISSUER", "").rstrip("/")