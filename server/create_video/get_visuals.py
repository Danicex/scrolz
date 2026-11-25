"""Downloads one stock image/video (Pixabay) for every beat of a chunk.

Beats -> noun-only queries (visual_queries.py) -> Pixabay -> video_assets/<asset_name>/beat_<i>.<ext>
Returns {beat index: file path}. A beat that found nothing is simply missing from the result.
"""
import logging
import os
import shutil
import time
from urllib.parse import urlparse

import requests

from config import PIXABAY_API_KEY, VIDEO_ASSET
from create_video.visual_queries import queries_for_beats

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


def find_media(query, kind, orientation, nth=0):
    """Search Pixabay. Returns (download_url, extension) or None.
    nth > 0 takes a later hit, so two beats with the same query don't show the same file."""
    query = query[:100]  # Pixabay allows 100 characters

    if kind == "video":
        hits = pixabay_get(PIXABAY + "videos/", {"q": query}).get("hits", [])
        if not hits:
            return None
        sizes = hits[nth % len(hits)].get("videos", {})
        for name in ("medium", "small", "large", "tiny"):  # medium = 1080p-ish, enough for a 1080 wide frame
            if sizes.get(name, {}).get("url"):
                return sizes[name]["url"], ".mp4"
        return None

    params = {"q": query, "image_type": "photo"}
    if orientation in ("horizontal", "vertical"):
        params["orientation"] = orientation
    hits = pixabay_get(PIXABAY, params).get("hits", [])
    if not hits and "orientation" in params:  # nothing in that orientation: take any, it is cropped anyway
        hits = pixabay_get(PIXABAY, {"q": query, "image_type": "photo"}).get("hits", [])
    if not hits:
        return None
    url = hits[nth % len(hits)]["largeImageURL"]  # up to 1280 px
    return url, os.path.splitext(urlparse(url).path)[1].lower() or ".jpg"


def download(url, path):
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        with open(path, "wb") as f:
            for block in r.iter_content(1024 * 256):
                f.write(block)


def get_visuals(beats, asset_name: str, orientation: str = "vertical") -> dict:
    """{beat i: path}. Never raises for a single bad search or download."""
    if not PIXABAY_API_KEY:
        log.warning("PIXABAY_API_KEY is not set, skipping stock visuals")
        return {}

    folder = os.path.join(VIDEO_ASSET, asset_name)
    shutil.rmtree(folder, ignore_errors=True)  # no leftovers from an earlier run
    os.makedirs(folder)

    ideas = queries_for_beats(beats)
    for idea in ideas:
        log.info("beat %s -> %s (%s)", idea["i"], idea["query"], idea["type"])

    saved, used = {}, {}
    for idea in ideas:
        key = (idea["query"], idea["type"])
        nth = used.get(key, 0)
        used[key] = nth + 1
        try:
            found = find_media(idea["query"], idea["type"], orientation, nth)
            if not found and idea["type"] == "video":
                found = find_media(idea["query"], "image", orientation, nth)
            if not found:
                continue
            url, ext = found
            path = os.path.join(folder, f"beat_{idea['i']}{ext}")
            download(url, path)
            saved[idea["i"]] = path
        except requests.RequestException as e:
            log.warning("visual %r failed: %s", idea["query"], e)

    return saved
