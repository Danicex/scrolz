import itertools
import json
import logging
import os
import random
import re
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageDraw
from sqlmodel import Session, select

from config import BG_SOUND_DIR, IMAGES_DIR, OUTPUT_VIDEO_DIR, VIDEO_ASSET
from create_video.beats import make_beats
from create_video.generate_caption import render_caption
from create_video.get_visuals import get_visuals
from create_video.video_templates import get_template
from database import engine
from model import Chunk, Project
from utils.progress import no_progress
from crud import update_chunk_vid_path
log = logging.getLogger(__name__)

STAGE = "creating_video"
HERE = os.path.dirname(os.path.abspath(__file__))
SECOND_DIR = os.path.join(HERE, "second_videos")  # clips for a template's "second" region
DEFAULT_TMPL = "vt_a"  # used when a chunk has no "video_tmpl"
BG_VOLUME = 0.12
FPS = 24
ZOOM_STEP, ZOOM_MAX = 0.0008, 1.12  # slow zoom on still images (per frame, and the most it ever zooms)

SEG_PRESET = "ultrafast"  # tiny per-beat clips, joined later without re-encoding
FINAL_PRESET = "veryfast"  # the one real encode, per chunk
WORKERS = max(2, (os.cpu_count() or 4) // 2)  # beat clips rendered in parallel
FINAL_SHARE = 0.97  # chunks are the first 97% of this stage, joining them the rest
COMBINE_ALL = False  # True: also join every chunk video into one <project>.mp4 next to the chunk folder

IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp")
VIDEO_EXT = (".mp4", ".mov", ".webm", ".mkv", ".avi", ".gif")
SOUND_EXT = (".mp3", ".wav", ".ogg", ".m4a")


def even(n):
    """h264 needs even width/height (449 -> 448)."""
    return int(n) - int(n) % 2


# ---------- assets ----------
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


def second_clips():
    if not os.path.isdir(SECOND_DIR):
        return []
    return [os.path.join(SECOND_DIR, f) for f in sorted(os.listdir(SECOND_DIR)) if f.lower().endswith(VIDEO_EXT)]


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


# ---------- template layout ----------
def pixel_regions(tmpl, w, h):
    """{"main": (x, y, w, h), ...} in even pixels. Edges are rounded, not sizes, so neighbours never leave a gap."""
    out = {}
    for name, b in tmpl["regions"].items():
        x0, x1 = even(round(b["x"] * w)), even(round((b["x"] + b["w"]) * w))
        y0, y1 = even(round(b["y"] * h)), even(round((b["y"] + b["h"]) * h))
        out[name] = (x0, y0, x1 - x0, y1 - y0)
    return out


def snap_beats(beats, duration):
    """Gives every beat a whole number of frames (so clips add up to the voice exactly) and drops empty ones."""
    snapped, prev = [], 0
    for b in beats:
        end = round(b["end"] * FPS)
        frames = end - prev
        if frames >= 1:
            snapped.append({**b, "frames": frames})
            prev = end
    if snapped:  # the last beat runs to the end of the audio
        snapped[-1]["frames"] += round(duration * FPS) - prev
    return snapped


def rounded_mask(w, h, radius, path):
    """White rounded rectangle on black (anti-aliased by drawing 4x bigger)."""
    k = 4
    big = Image.new("L", (w * k, h * k), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * k - 1, h * k - 1), radius=radius * k, fill=255)
    big.resize((w, h), Image.LANCZOS).save(path)


# ---------- stage 1: main track (one clip per beat) ----------
def make_beat_clip(src, frames, rw, rh, dst, n=0):
    """One beat of the main region: the asset covers rw x rh (middle is cropped), exactly `frames` frames.
    Stills get a slow zoom (in on even beats, out on odd ones), videos play from the start and loop if short."""
    enc = ["-an", "-frames:v", frames, "-c:v", "libx264", "-preset", SEG_PRESET, "-crf", "20",
           "-g", FPS * 2, "-pix_fmt", "yuv420p", dst]

    if src is None:  # nothing found for this beat
        ffmpeg(["-f", "lavfi", "-i", f"color=c=black:s={rw}x{rh}:r={FPS}", *enc])
    elif src.lower().endswith(IMAGE_EXT):
        z = f"min(1+{ZOOM_STEP}*on,{ZOOM_MAX})" if n % 2 == 0 else f"max({ZOOM_MAX}-{ZOOM_STEP}*on,1)"
        vf = (
            f"scale={rw * 2}:{rh * 2}:force_original_aspect_ratio=increase,crop={rw * 2}:{rh * 2},"  # 2x so the zoom is smooth
            f"zoompan=z='{z}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s={rw}x{rh}:fps={FPS},setsar=1"
        )
        ffmpeg(["-loop", "1", "-i", src, "-vf", vf, *enc])
    else:
        vf = f"scale={rw}:{rh}:force_original_aspect_ratio=increase,crop={rw}:{rh},setsar=1,fps={FPS}"
        ffmpeg(["-stream_loop", "-1", "-i", src, "-vf", vf, *enc])


def make_main_track(beats, assets, rw, rh, tmp, idx, out):
    """Beat clips are rendered in parallel (a repeated asset in a row is fine, each beat is its own clip)
    and joined without re-encoding."""
    files = [os.path.join(tmp, f"c{idx}_beat{b['i']}.mp4") for b in beats]
    jobs = [(assets.get(b["i"]), b["frames"], files[n], b["i"]) for n, b in enumerate(beats)]
    with ThreadPoolExecutor(WORKERS) as ex:
        list(ex.map(lambda j: make_beat_clip(j[0], j[1], rw, rh, j[2], j[3]), jobs))

    list_path = os.path.join(tmp, f"c{idx}_main.txt")
    write_concat_list(files, list_path)
    ffmpeg(["-f", "concat", "-safe", "0", "-i", list_path, "-c", "copy", out])


def fill_missing(beats, found, fallback):
    """Every beat gets a visual: if its search found nothing, keep showing the previous beat's visual;
    before the first one, use the PDF's own pictures (or nothing = black)."""
    assets, last = {}, None
    for b in beats:
        src = found.get(b["i"])
        if src is None and last is None and fallback:
            src = fallback[b["i"] % len(fallback)]
        if src is None:
            src = last
        assets[b["i"]] = src
        last = src
    return assets


# ---------- stage 2: caption pictures (one per beat) ----------
def make_caption_track(beats, size, style, tmp, idx):
    """Writes one transparent PNG per beat and a concat list that shows each for its length.
    Returns the list path (ffmpeg reads it with -f concat)."""
    cw, ch = size
    lines = []
    for b in beats:
        png = os.path.join(tmp, f"c{idx}_cap{b['i']}.png")
        render_caption(b["text"], cw, ch, style).save(png)
        lines.append((png, b["frames"] / FPS))

    list_path = os.path.join(tmp, f"c{idx}_captions.txt")
    with open(list_path, "w", encoding="utf-8") as f:
        for png, d in lines:
            f.write(f"file '{os.path.abspath(png)}'\nduration {d:.5f}\n")
        f.write(f"file '{os.path.abspath(lines[-1][0])}'\n")  # concat ignores the last duration unless the file repeats
    return list_path


# ---------- stage 3: put the template together ----------
def probe_has_duration(path):
    try:
        return probe_duration(path)
    except Exception:
        return 0.0


def merge_chunk(tmpl, regions, main, captions, second, voice, bg, duration, out, tmp, idx, on_progress=None):
    w, h = tmpl["width"], tmpl["height"]
    mx, my, mw, mh = regions["main"]
    cx, cy, cw, ch = regions["caption"]

    inputs = ["-f", "lavfi", "-i", f"color=c={tmpl['card_color'].replace('#', '0x')}:s={w}x{h}:r={FPS}:d={duration:.3f}",
              "-i", main,
              "-f", "concat", "-safe", "0", "-i", captions]
    n = 3  # next input number

    chain = []
    base = "[0:v]"
    bg_fill = tmpl["caption_style"]["bg"]
    if bg_fill:
        chain.append(f"{base}drawbox=x={cx}:y={cy}:w={cw}:h={ch}:color={bg_fill.replace('#', '0x')}:t=fill[b0]")
        base = "[b0]"
    chain.append(f"{base}[1:v]overlay={mx}:{my}[b1]")

    last = "[b1]"
    if second:
        sx, sy, sw, sh, clip, offset = second
        inputs += ["-stream_loop", "-1", "-ss", f"{offset:.2f}", "-i", clip]
        chain.append(
            f"[{n}:v]scale={sw}:{sh}:force_original_aspect_ratio=increase,crop={sw}:{sh},setsar=1,fps={FPS}[sec]"
        )
        chain.append(f"[b1][sec]overlay={sx}:{sy}[b2]")
        last = "[b2]"
        n += 1

    chain.append(f"[2:v]fps={FPS},format=rgba[cap]")
    chain.append(f"{last}[cap]overlay={cx}:{cy}:format=auto[card]")

    radius = tmpl["corner_radius"]
    if radius > 0:
        mask = os.path.join(tmp, f"c{idx}_mask.png")
        rounded_mask(w, h, radius, mask)
        inputs += ["-f", "lavfi", "-i", f"color=c={tmpl['canvas'].replace('#', '0x')}:s={w}x{h}:r={FPS}:d={duration:.3f}",
                   "-loop", "1", "-framerate", FPS, "-i", mask]
        chain.append(f"[{n + 1}:v]format=gray[m]")
        chain.append(f"[card]format=yuv420p[cy];[cy][m]alphamerge[round]")
        chain.append(f"[{n}:v][round]overlay=0:0:format=auto,format=yuv420p[v]")
        n += 2
    else:
        chain.append("[card]format=yuv420p[v]")

    inputs += ["-i", voice]
    voice_n = n
    n += 1
    audio_fmt = "aformat=sample_rates=44100:channel_layouts=stereo"
    if bg:
        inputs += ["-stream_loop", "-1", "-i", bg]  # bg loops to fill the voice length
        chain.append(
            f"[{voice_n}:a]{audio_fmt}[a1];[{n}:a]{audio_fmt},volume={BG_VOLUME}[a2];"
            f"[a1][a2]amix=inputs=2:duration=first:normalize=0[a]"
        )
    else:
        chain.append(f"[{voice_n}:a]{audio_fmt}[a]")

    ffmpeg([
        *inputs, "-filter_complex", ";".join(chain), "-map", "[v]", "-map", "[a]", "-t", f"{duration:.3f}",
        "-c:v", "libx264", "-preset", FINAL_PRESET, "-crf", "21", "-r", FPS,
        "-c:a", "aac", "-b:a", "192k", "-ar", "44100", "-ac", "2", "-movflags", "+faststart", out,
    ], total=duration, on_progress=on_progress)


# ---------- one chunk ----------
def build_chunk(key, chunk, project_name, playlist, tmp, progress=no_progress, idx=1, total=1, out_path=None):
    """Makes the video of ONE chunk. Written to `out_path` (or to the temp dir when not given).
    chunk = {"text", "audio", "video_tmpl" (optional), "words" (optional word timestamps from your TTS)}"""
    def step(frac, label, msg="", **kw):  # frac = 0..1 of this chunk
        progress(STAGE, label, chunk=idx, total=total, msg=msg or key,
                 fraction=FINAL_SHARE * (idx - 1 + frac) / total, **kw)

    tmpl_name = chunk.get("video_tmpl") or DEFAULT_TMPL
    tmpl = get_template(tmpl_name)
    w, h = even(tmpl["width"]), even(tmpl["height"])
    tmpl = {**tmpl, "width": w, "height": h}
    regions = pixel_regions(tmpl, w, h)
    mx, my, mw, mh = regions["main"]

    duration = probe_duration(chunk["audio"])

    # beats: the voice-over cut into phrases with exact times (caption + visual change together)
    step(0.0, "beats", "cutting the voice-over into beats")
    beats = make_beats(chunk["audio"], duration, tmpl["beat_max_words"], tmpl["beat_max_seconds"], chunk.get("words"))
    if not beats:  # no speech found: one beat for the whole chunk
        beats = [{"i": 0, "text": chunk["text"], "start": 0.0, "end": duration}]
    beats = snap_beats(beats, duration)

    # one stock visual per beat, matched to what is being said
    asset_name = f"{project_name}_{key}"
    step(0.1, "visuals", f"{len(beats)} beats")
    found = {}
    try:
        found = get_visuals(beats, asset_name, "vertical" if mh > mw else "horizontal")
    except Exception as e:
        log.exception("get_visuals failed for %s", asset_name)
        step(0.1, "visuals", f"stock visuals failed ({type(e).__name__}: {e})")
    assets = fill_missing(beats, found, pdf_images(project_name))
    step(0.2, "visuals", f"stock visuals for {len(found)}/{len(beats)} beats")

    step(0.25, "composing", f"template {tmpl_name} ({w}x{h}), {duration:.0f}s")
    main = os.path.join(tmp, f"c{idx}_main.mp4")
    make_main_track(beats, assets, mw, mh, tmp, idx, main)

    _, _, cw, ch = regions["caption"]
    captions = make_caption_track(beats, (cw, ch), tmpl["caption_style"], tmp, idx)

    second = None
    if "second" in regions:
        sx, sy, sw, sh = regions["second"]
        clips = second_clips()
        if clips:
            clip = random.choice(clips)
            spare = probe_has_duration(clip) - duration - 0.5
            second = (sx, sy, sw, sh, clip, random.uniform(0, spare) if spare > 0 else 0.0)
        else:
            log.warning("template %s has a second video area but %s has no clips: it stays black", tmpl_name, SECOND_DIR)

    bg = next(playlist) if tmpl["bg_sound"] and playlist else None

    step(0.6, "rendering", f"chunk {idx}/{total}")
    out = out_path or os.path.join(tmp, f"c{idx}_final.mp4")
    part = out + ".part.mp4"  # written under another name, so a half-finished video never looks finished
    merge_chunk(
        tmpl, regions, main, captions, second, chunk["audio"], bg, duration, part, tmp, idx,
        on_progress=lambda f: step(0.6 + 0.4 * f, "rendering", f"chunk {idx}/{total}: {f * 100:.0f}%", record=False),
    )
    os.replace(part, out)
    return out, (w, h)


# ---------- everything ----------
def compile_video(json_path, project_id:int, progress=None):
    progress = progress or no_progress
    project_name = os.path.splitext(os.path.basename(json_path))[0]
    progress(STAGE, "loading", msg=json_path, fraction=0.0)

    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)
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
                    key, chunk, chunk.get("project_name") or project_name, playlist, tmp, progress, i,
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
    project = session.exec(select(Project).where(Project.title == project_name)).first()
    if not project:
        raise ValueError(f"Project '{project_name}' not found")

    # Sanitize project_name if used in file paths
    safe_project_dir = safe_name(project_name)
    video_dir = Path(OUTPUT_VIDEO_DIR) / safe_project_dir
    
    if not video_dir.is_dir():
        raise FileNotFoundError(f"Video directory not found: {video_dir}")

    chunks = session.exec(select(Chunk).where(Chunk.project_id == project.id)).all()
    updated, missing = [], []

    for chunk in chunks:
        filename = f"{safe_name(chunk.key)}.mp4"
        file_path = video_dir / filename

        if not file_path.is_file():
            missing.append(chunk.key)
            continue

        # Removed duplicate project_name and used POSIX format for URLs
        chunk.video_url = file_path.as_posix()
        session.add(chunk)
        updated.append(chunk.key)

    # Save the changes to the database
    session.commit()

    return {"updated": updated, "missing": missing}
