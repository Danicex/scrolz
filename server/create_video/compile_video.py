import itertools
import json
import logging
import os
import random
import re
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from sqlmodel import Session, select
from config import BG_SOUND_DIR, IMAGES_DIR, OUTPUT_VIDEO_DIR, VIDEO_ASSET
from create_video.generate_caption import create_caption_clips
from create_video.get_visuals import get_visuals
from utils.progress import no_progress
from pathlib import Path
from model import Chunk, Project 
from database import engine 

log = logging.getLogger(__name__)

STAGE = "creating_video"
SETTINGS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "video_settings.json")
DEFAULT_TMPL = "video_tmpl_1"  # used when a chunk has no "video_tmpl"
SLIDE_SECONDS = 2  # every asset (image, gif or video) is shown for 2 sec
FADE_SECONDS = 0.4  # fade/slide time at the start and end of each slide
BG_VOLUME = 0.12
FPS = 24

# Stacked layout (portrait templates). Every value can be overridden per template in
# video_settings.json with the keys: slide_height, image_width, caption_width,
# caption_height, caption_margin (gap between the caption and the bottom edge).
SLIDE_H = 500  # slideshow strip: full template width x 500, centered vertically
IMAGE_W = 900  # still images are 900 x 500 inside the strip, videos/gifs fill 1080 x 500
CAP_W, CAP_H = 1000, 100
CAP_MARGIN = 120

SEG_PRESET = "ultrafast"  # tiny per-slide clips, joined later without re-encoding
FINAL_PRESET = "veryfast"  # the one real encode, per chunk
WORKERS = max(2, (os.cpu_count() or 4) // 2)  # slides rendered in parallel
FINAL_SHARE = 0.97  # chunks are the first 97% of this stage, joining them the rest
COMBINE_ALL = False  # True: also join every chunk video into one <project>.mp4 next to the chunk folder

IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp")
VIDEO_EXT = (".mp4", ".mov", ".webm", ".mkv", ".avi", ".gif")
SOUND_EXT = (".mp3", ".wav", ".ogg", ".m4a")


def even(n):
    """h264 needs even width/height (449 -> 448)."""
    return int(n) - int(n) % 2


# ---------- assets ----------
def list_assets(asset_name):
    """Files in video_assets/<asset_name>/ sorted by the number in the name (0, 1, 2 ... 10)."""
    folder = os.path.join(VIDEO_ASSET, asset_name)
    if not os.path.isdir(folder):
        return []
    files = [os.path.join(folder, f) for f in os.listdir(folder) if f.lower().endswith(IMAGE_EXT + VIDEO_EXT)]

    def number(path):
        found = re.findall(r"\d+", os.path.basename(path))
        return int(found[-1]) if found else 0

    return sorted(files, key=number)


def pdf_images(project_name):
    """Fallback when no stock visuals: the pictures taken out of the PDF (or its cover)."""
    prefix = f"{project_name}_"
    files = sorted(
        os.path.join(IMAGES_DIR, f)
        for f in os.listdir(IMAGES_DIR)
        if f.startswith(prefix) and f.lower().endswith(IMAGE_EXT)
    )
    embedded = [f for f in files if not f.endswith("_cover.png")]
    return embedded or files


def bg_tracks():
    return [
        os.path.join(BG_SOUND_DIR, f)
        for f in sorted(os.listdir(BG_SOUND_DIR))
        if f.lower().endswith(SOUND_EXT)
    ]


# ---------- ffmpeg helpers ----------
class FFmpegError(RuntimeError):
    pass


def ffmpeg(args, total=None, on_progress=None):
    """Run ffmpeg. With `total` (seconds of output) and `on_progress`, reports 0..1 about every 5%."""
    cmd = ["ffmpeg", "-y", "-hide_banner", "-nostdin", "-v", "error"]
    if on_progress and total:
        cmd += ["-progress", "pipe:1", "-nostats"]
    cmd += [str(a) for a in args]

    if on_progress and total:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        last = -0.05
        for line in p.stdout:
            if line.startswith("out_time_us="):
                try:
                    frac = min(1.0, int(line.split("=")[1]) / 1e6 / total)
                except ValueError:  # "N/A" at the start
                    continue
                if frac >= last + 0.05:
                    last = frac
                    on_progress(frac)
        err = p.stderr.read()
        rc = p.wait()
    else:
        p = subprocess.run(cmd, capture_output=True, text=True)
        rc, err = p.returncode, p.stderr

    if rc != 0:
        raise FFmpegError(f"ffmpeg failed ({rc}): {' '.join(cmd)}\n{err[-1500:]}")


def probe_duration(path):
    if not os.path.isfile(path):
        raise FileNotFoundError(f"audio file not found: {path}")
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", path],
        capture_output=True, text=True, check=True,
    ).stdout
    return float(out.strip())


def write_concat_list(files, list_path):
    with open(list_path, "w", encoding="utf-8") as f:
        for p in files:
            f.write("file '" + os.path.abspath(p).replace("'", "'\\''") + "'\n")


# ---------- stage 1: slideshow ----------
def make_slide(src, dst, d, strip_w, strip_h, image_w):
    """One asset -> a strip_w x strip_h clip of `d` sec: covers its box (crop the middle), slides in
    from the right while fading in, slides out to the left while fading out."""
    is_image = src.lower().endswith(IMAGE_EXT)
    tw = image_w if is_image else strip_w  # images 900 wide, gifs/videos full width
    fade = min(FADE_SECONDS, d / 2)
    shift = strip_w // 4
    out_start = d - fade

    x = (
        f"(W-w)/2+if(lt(t,{fade:.3f}),{shift}*(1-t/{fade:.3f}),"
        f"if(gt(t,{out_start:.3f}),-{shift}*(t-{out_start:.3f})/{fade:.3f},0))"
    )
    fc = (
        f"[1:v]scale={tw}:{strip_h}:force_original_aspect_ratio=increase,crop={tw}:{strip_h},"
        f"setsar=1,fps={FPS},format=yuv420p,"
        f"fade=t=in:st=0:d={fade:.3f},fade=t=out:st={out_start:.3f}:d={fade:.3f}[a];"
        f"[0:v][a]overlay=x='{x}':y=(H-h)/2:shortest=1,format=yuv420p[v]"
    )
    loop = ["-loop", "1"] if is_image else ["-stream_loop", "-1"]  # loops gifs/videos that are too short
    ffmpeg([
        "-f", "lavfi", "-i", f"color=c=black:s={strip_w}x{strip_h}:r={FPS}:d={d:.3f}",
        *loop, "-i", src,
        "-filter_complex", fc, "-map", "[v]", "-an", "-t", f"{d:.3f}",
        "-c:v", "libx264", "-preset", SEG_PRESET, "-crf", "20", "-g", FPS * 2, dst,
    ])


def make_slideshow(assets, duration, strip_w, strip_h, image_w, tmp, idx, out):
    """Slides are rendered in parallel (once per distinct asset) and joined without re-encoding."""
    if not assets:  # nothing to show: plain black strip
        ffmpeg(["-f", "lavfi", "-i", f"color=c=black:s={strip_w}x{strip_h}:r={FPS}:d={duration:.3f}",
                "-c:v", "libx264", "-preset", SEG_PRESET, "-pix_fmt", "yuv420p", "-g", FPS * 2, out])
        return

    plan, start, i = [], 0.0, 0
    while duration - start > 1 / FPS:
        d = round(min(SLIDE_SECONDS, duration - start), 3)
        plan.append((assets[i % len(assets)], d))  # fewer assets than needed -> start over
        start += SLIDE_SECONDS
        i += 1

    unique = list(dict.fromkeys(plan))  # a repeated asset is only rendered once
    files = {u: os.path.join(tmp, f"c{idx}_slide{n}.mp4") for n, u in enumerate(unique)}
    with ThreadPoolExecutor(WORKERS) as ex:
        list(ex.map(lambda u: make_slide(u[0], files[u], u[1], strip_w, strip_h, image_w), unique))

    list_path = os.path.join(tmp, f"c{idx}_slides.txt")
    write_concat_list([files[u] for u in plan], list_path)
    ffmpeg(["-f", "concat", "-safe", "0", "-i", list_path, "-c", "copy", out])


# ---------- stage 2: caption video ----------
def make_caption_video(audio_path, cap_w, cap_h, duration, solid_bar, out):
    """Silent cap_w x cap_h video with the Whisper captions (your create_caption_clips), on black.
    Only this small frame goes through moviepy; the voice + bg sound are mixed later by ffmpeg."""
    from moviepy import ColorClip, CompositeVideoClip  # lazy: only the captions still use moviepy

    layers = [ColorClip((cap_w, cap_h), color=(0, 0, 0), duration=duration)]
    layers += create_caption_clips(audio_path, cap_w, cap_h, duration, solid_bar=solid_bar)
    clip = CompositeVideoClip(layers, size=(cap_w, cap_h)).with_duration(duration)
    try:
        clip.write_videofile(out, fps=FPS, codec="libx264", audio=False, preset="ultrafast", logger=None)
    finally:
        clip.close()


# ---------- stage 3: slideshow + caption + audio ----------
def merge_chunk(slides, caption, voice, bg, duration, w, h, lay, out, on_progress=None):
    y_slide = (h - lay["slide_h"]) // 2
    x_cap = (w - lay["cap_w"]) // 2
    y_cap = h - lay["cap_h"] - lay["margin"]

    audio_fmt = "aformat=sample_rates=44100:channel_layouts=stereo"
    if bg:
        audio = (
            f"[2:a]{audio_fmt}[a1];[3:a]{audio_fmt},volume={BG_VOLUME}[a2];"
            f"[a1][a2]amix=inputs=2:duration=first:normalize=0[a]"
        )
    else:
        audio = f"[2:a]{audio_fmt}[a]"
    fc = (
        f"[0:v]pad={w}:{h}:0:{y_slide}:black[base];"
        f"[base][1:v]overlay={x_cap}:{y_cap}:shortest=1,format=yuv420p[v];{audio}"
    )

    inputs = ["-i", slides, "-i", caption, "-i", voice]
    if bg:
        inputs += ["-stream_loop", "-1", "-i", bg]  # bg loops to fill the voice length

    ffmpeg([
        *inputs, "-filter_complex", fc, "-map", "[v]", "-map", "[a]", "-t", f"{duration:.3f}",
        "-c:v", "libx264", "-preset", FINAL_PRESET, "-crf", "21", "-r", FPS,
        "-c:a", "aac", "-b:a", "192k", "-ar", "44100", "-ac", "2", out,
    ], total=duration, on_progress=on_progress)


def layout_for(tmpl, w, h):
    portrait = h > w
    slide_h = even(min(tmpl.get("slide_height", SLIDE_H if portrait else h), h))
    return {
        "slide_h": slide_h,
        "image_w": even(min(tmpl.get("image_width", IMAGE_W if portrait else w), w)),
        "cap_w": even(min(tmpl.get("caption_width", CAP_W), w)),
        "cap_h": even(min(tmpl.get("caption_height", CAP_H), h)),
        "margin": int(tmpl.get("caption_margin", CAP_MARGIN)),
    }


# ---------- one chunk ----------
def build_chunk(key, chunk, settings, project_name, playlist, tmp, progress=no_progress, idx=1, total=1,
                out_path=None):
    """Makes the video of ONE chunk. Written to `out_path` (or to the temp dir when not given)."""
    def step(frac, label, msg="", **kw):  # frac = 0..1 of this chunk
        progress(STAGE, label, chunk=idx, total=total, msg=msg or key,
                 fraction=FINAL_SHARE * (idx - 1 + frac) / total, **kw)

    tmpl_name = chunk.get("video_tmpl") or DEFAULT_TMPL
    if tmpl_name not in settings:
        raise ValueError(f"Unknown video_tmpl: {tmpl_name}")
    tmpl = settings[tmpl_name]
    w, h = even(tmpl["width"]), even(tmpl["height"])
    lay = layout_for(tmpl, w, h)

    duration = probe_duration(chunk["audio"])

    # stock visuals for this chunk, saved in their own folder
    asset_name = f"{project_name}_{key}"
    step(0.0, "visuals")
    try:
        get_visuals(chunk["text"], asset_name, "landscape" if w >= h else "portrait")
    except Exception as e:
        log.exception("get_visuals failed for %s, using the PDF's own images", asset_name)
        step(0.0, "visuals", f"stock visuals failed ({type(e).__name__}: {e}), using the PDF's own images")
    assets = list_assets(asset_name)
    if assets:
        step(0.0, "visuals", f"{len(assets)} stock files")
    else:
        assets = pdf_images(project_name)
        step(0.0, "visuals", f"no stock files, using {len(assets)} image(s) from the PDF")

    step(0.2, "composing", f"template {tmpl_name} ({w}x{h}), {duration:.0f}s")
    slides = os.path.join(tmp, f"c{idx}_slideshow.mp4")
    make_slideshow(assets, duration, w, lay["slide_h"], lay["image_w"], tmp, idx, slides)

    step(0.35, "captions", "Whisper is listening to the audio")
    caption = os.path.join(tmp, f"c{idx}_caption.mp4")
    make_caption_video(chunk["audio"], lay["cap_w"], lay["cap_h"], duration, not tmpl["bg_transparent"], caption)

    # voice + (optional) background sound
    bg = next(playlist) if tmpl["bg_sound"] and playlist else None

    step(0.6, "rendering", f"chunk {idx}/{total}")
    out = out_path or os.path.join(tmp, f"c{idx}_final.mp4")
    part = out + ".part.mp4"  # written under another name, so a half-finished video never looks finished
    merge_chunk(
        slides, caption, chunk["audio"], bg, duration, w, h, lay, part,
        on_progress=lambda f: step(0.6 + 0.4 * f, "rendering", f"chunk {idx}/{total}: {f * 100:.0f}%", record=False),
    )
    os.replace(part, out)
    return out, (w, h)


# ---------- everything ----------
def compile_video(json_path, progress=None):
    progress = progress or no_progress
    project_name = os.path.splitext(os.path.basename(json_path))[0]
    progress(STAGE, "loading", msg=json_path, fraction=0.0)

    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)
    with open(SETTINGS_PATH, encoding="utf-8") as f:
        settings = json.load(f)
    if not data:
        raise ValueError("The json has no chunks, nothing to make a video from.")

    # shuffle the background tracks (from create_video/bg_sound/) and go through them in that order
    tracks = bg_tracks()
    random.shuffle(tracks)
    playlist = itertools.cycle(tracks) if tracks else None

    # one video per chunk: <OUTPUT_VIDEO_DIR>/<project>/<chunk key>.mp4
    out_dir = os.path.join(OUTPUT_VIDEO_DIR, project_name)
    os.makedirs(out_dir, exist_ok=True)
    total = len(data)

    videos, sizes, failed = {}, [], {}
    with tempfile.TemporaryDirectory(prefix="video_") as tmp:
        for i, (key, chunk) in enumerate(data.items(), start=1):
            safe_key = re.sub(r"[^\w.-]+", "_", str(key))
            target = os.path.join(out_dir, f"{safe_key}.mp4")
            try:
                path, size = build_chunk(
                    key, chunk, settings, chunk.get("project_name") or project_name, playlist, tmp, progress, i,
                    total, out_path=target,
                )
            except Exception as e:  # one bad chunk must not throw away the videos already made
                log.exception("chunk %s failed", key)
                failed[key] = f"{type(e).__name__}: {e}"
                progress(STAGE, "failed", chunk=i, total=total, msg=f"chunk {key} failed: {failed[key]}",
                         fraction=FINAL_SHARE * i / total)
                continue
            videos[key] = path
            sizes.append(size)
            progress(STAGE, "chunk_done", chunk=i, total=total, msg=f"{key} -> {path}",
                     fraction=FINAL_SHARE * i / total)

        if not videos:
            raise RuntimeError(f"No chunk video could be made: {failed}")

        combined = None
        if COMBINE_ALL:
            combined = os.path.join(OUTPUT_VIDEO_DIR, f"{project_name}.mp4")
            files = list(videos.values())
            progress(STAGE, "rendering", msg=f"joining {len(files)} chunk(s) -> {combined}", fraction=FINAL_SHARE)

            if len(set(sizes)) > 1:  # templates differ in size: fit every chunk on the biggest frame
                bw, bh = max(s[0] for s in sizes), max(s[1] for s in sizes)
                fitted = []
                for n, path in enumerate(files):
                    dst = os.path.join(tmp, f"fit{n}.mp4")
                    ffmpeg([
                        "-i", path,
                        "-vf", f"scale={bw}:{bh}:force_original_aspect_ratio=decrease,"
                               f"pad={bw}:{bh}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,format=yuv420p",
                        "-c:v", "libx264", "-preset", FINAL_PRESET, "-crf", "21", "-r", FPS, "-c:a", "copy", dst,
                    ])
                    fitted.append(dst)
                files = fitted

            list_path = os.path.join(tmp, "chunks.txt")
            write_concat_list(files, list_path)
            ffmpeg(["-f", "concat", "-safe", "0", "-i", list_path, "-c", "copy", "-movflags", "+faststart", combined])

    progress(STAGE, "rendering", msg=f"done: {len(videos)} video(s) in {out_dir}", fraction=1.0)
    
    with Session(engine) as session:
        db_result = update_chunk_video_url(project_name, session)
    
    return {
        "dir": out_dir,  
        "videos": videos, 
        "combined": combined,  
        "failed": failed, 
        "status": not failed,
        "db": db_result,
    }
    


VIDEO_URL_PREFIX = "/videos"

def safe_name(key) -> str:
    return re.sub(r"[^\w.-]+", "_", str(key))

def update_chunk_video_url(project_name: str, session: Session) -> dict:
    project = session.exec(select(Project).where(Project.name == project_name)).first()
    if not project:
        raise ValueError(f"Project '{project_name}' not found")

    video_dir = Path(OUTPUT_VIDEO_DIR) / project_name
    if not video_dir.is_dir():
        raise FileNotFoundError(f"Video directory not found: {video_dir}")

    chunks = session.exec(select(Chunk).where(Chunk.project_id == project.id)).all()

    updated, missing = [], []
    for chunk in chunks:
        filename = f"{safe_name(chunk.key)}.mp4"
        if not (video_dir / filename).is_file():
            missing.append(chunk.key)
            continue
        chunk.video_url = f"{VIDEO_URL_PREFIX}/{project_name}/{filename}"
        session.add(chunk)
        updated.append(chunk.key)

    session.commit()
    return {"updated": updated, "missing_videos": missing}