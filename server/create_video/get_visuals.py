"""Downloads stock images/videos (Pixabay) for one chunk.

Files are saved as video_assets/<asset_name>/0.jpg, 1.mp4, 2.jpg ...
The number in the file name is the order they appear in the slideshow.
"""
import logging
import os
import shutil
import time
from urllib.parse import urlparse

import requests

from config import PIXABAY_API_KEY, VIDEO_ASSET
from utils.use_llm import generate_visuals

log = logging.getLogger(__name__)

PIXABAY = "https://pixabay.com/api/"
TIMEOUT = 30


def pixabay_get(url, params):
    """GET with the API key. Waits and retries once if the rate limit (100 requests/min) is hit."""
    params = {"key": PIXABAY_API_KEY, "per_page": 3, "safesearch": "true", **params}  # per_page minimum is 3
    for attempt in range(2):
        r = requests.get(url, params=params, timeout=TIMEOUT)
        if r.status_code == 429 and attempt == 0:
            time.sleep(min(int(r.headers.get("X-RateLimit-Reset", 30)), 60))
            continue
        r.raise_for_status()
        return r.json()


def find_media(query, kind, orientation):
    """Search Pixabay. Returns (download_url, extension) or None."""
    query = query[:100]  # Pixabay allows 100 characters

    if kind == "video":
        data = pixabay_get(PIXABAY + "videos/", {"q": query})
        hits = data.get("hits", [])
        if not hits:
            return None
        sizes = hits[0].get("videos", {})
        # 720p first (small download), then the others
        for name in ("small", "medium", "tiny", "large"):
            if sizes.get(name, {}).get("url"):
                return sizes[name]["url"], ".mp4"
        return None

    data = pixabay_get(
        PIXABAY,
        {
            "q": query,
            "image_type": "photo",
            "orientation": "horizontal" if orientation == "landscape" else "vertical",
        },
    )
    hits = data.get("hits", [])
    if not hits:
        return None
    url = hits[0]["largeImageURL"]  # up to 1280 px
    return url, os.path.splitext(urlparse(url).path)[1].lower() or ".jpg"


def download(url, path):
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        with open(path, "wb") as f:
            for block in r.iter_content(1024 * 256):
                f.write(block)


def get_visuals(text: str, asset_name: str, orientation: str = "landscape") -> bool:
    """True if at least one file was saved. Never raises for a single bad download."""
    if not PIXABAY_API_KEY:
        log.warning("PIXABAY_API_KEY is not set, skipping stock visuals")
        return False

    folder = os.path.join(VIDEO_ASSET, asset_name)
    shutil.rmtree(folder, ignore_errors=True)  # no leftovers from an earlier run
    os.makedirs(folder)

    saved = 0
    for idea in generate_visuals(text):
        try:
            found = find_media(idea["query"], idea["type"], orientation)
            if not found and idea["type"] == "video":
                found = find_media(idea["query"], "image", orientation)
            if not found:
                continue
            url, ext = found
            download(url, os.path.join(folder, f"{saved}{ext}"))
            saved += 1
        except requests.RequestException as e:
            log.warning("visual %r failed: %s", idea["query"], e)

    return saved > 0