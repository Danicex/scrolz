"""Captions: Whisper listens to the voice-over and gives text + timing,
which is drawn as text clips at the bottom of the video (no extra video file)."""
import logging
import os
from functools import lru_cache

from moviepy import ColorClip, TextClip
from PIL import ImageFont

from config import CAPTION_FONT, WHISPER_MODEL

log = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def get_whisper():
    import whisper  # imported here: it pulls in torch, so only the worker pays for it

    return whisper.load_model(WHISPER_MODEL)  # loaded once, not for every chunk


def transcribe(audio_path):
    """[{"start": 0.0, "end": 3.2, "text": "..."}, ...]"""
    result = get_whisper().transcribe(audio_path)
    return [
        {"start": s["start"], "end": s["end"], "text": s["text"].strip()}
        for s in result.get("segments", [])
        if s["text"].strip()
    ]


def wrap_text(text, font_path, font_size, max_width):
    """Break text into lines that fit max_width, only between words.
    (MoviePy's own 'caption' wrapping splits words in the middle after the first line.)"""
    if font_path:
        font = ImageFont.truetype(font_path, font_size)
    else:
        font = ImageFont.load_default(font_size)

    lines, line = [], ""
    for word in text.split():
        test = f"{line} {word}".strip()
        if line and font.getlength(test) > max_width:
            lines.append(line)
            line = word
        else:
            line = test
    lines.append(line)
    return "\n".join(lines)


def create_caption_clips(audio_path, w, h, duration, solid_bar=False):
    """Caption clips for one chunk, ready to go on top of the slideshow.
    solid_bar=True puts a black bar behind the text (templates with bg_transparent: false)."""
    font_size = max(20, int(h * 0.045))
    pad = max(8, font_size // 2)  # room around the text, otherwise the last line and the outline get cut
    margin = int(h * 0.04)  # gap under the caption
    max_width = int(w * 0.9) - 2 * pad

    font_path = CAPTION_FONT if os.path.exists(CAPTION_FONT) else None
    if not font_path:
        log.warning("Caption font %s not found, using the default font", CAPTION_FONT)

    clips = []
    if solid_bar:
        bar_h = int(h * 0.26)
        clips.append(ColorClip((w, bar_h), color=(0, 0, 0), duration=duration).with_position((0, h - bar_h)))

    for seg in transcribe(audio_path):
        start, end = seg["start"], min(seg["end"], duration)
        if start >= duration or end <= start:
            continue

        text = TextClip(
            font=font_path,
            text=wrap_text(seg["text"], font_path, font_size, max_width),
            font_size=font_size,
            color="white",
            stroke_color="black",
            stroke_width=max(1, font_size // 16),
            method="label",  # we already broke the lines ourselves
            text_align="center",
            margin=(pad, pad),
        )
        y = max(0, h - margin - text.h)  # sits at the bottom
        clips.append(text.with_start(start).with_end(end).with_position(("center", y)))

    return clips
