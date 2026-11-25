"""Whisper word timings + caption pictures.

Captions are no longer moviepy clips: every beat gets one transparent PNG the size of the
template's caption region, and compile_video.py shows them in time with ffmpeg (much faster).
"""
import logging
import os
from functools import lru_cache

from PIL import Image, ImageDraw, ImageFont

from config import CAPTION_FONT, WHISPER_MODEL

log = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def get_whisper():
    import whisper  # imported here: it pulls in torch, so only the worker pays for it

    return whisper.load_model(WHISPER_MODEL)  # loaded once, not for every chunk


def transcribe_words(audio_path):
    """[{"word": "Hello", "start": 0.0, "end": 0.4}, ...] - punctuation stays on the word."""
    result = get_whisper().transcribe(audio_path, word_timestamps=True)
    return [
        {"word": w["word"].strip(), "start": w["start"], "end": w["end"]}
        for seg in result.get("segments", [])
        for w in seg.get("words", [])
        if w["word"].strip()
    ]


def _font(size):
    if CAPTION_FONT and os.path.exists(CAPTION_FONT):
        return ImageFont.truetype(CAPTION_FONT, size)
    log.warning("Caption font %s not found, using the default font", CAPTION_FONT)
    return ImageFont.load_default(size)


def wrap_text(text, font, max_width):
    """Break text into lines that fit max_width, only between words."""
    lines, line = [], ""
    for word in text.split():
        test = f"{line} {word}".strip()
        if line and font.getlength(test) > max_width:
            lines.append(line)
            line = word
        else:
            line = test
    lines.append(line)
    return lines


def render_caption(text, w, h, style):
    """Transparent w x h picture of `text` fitted inside it: the biggest font between
    min_font and max_font whose wrapped lines fit. `style` = template["caption_style"]."""
    pad = style["padding"]
    box_w, box_h = w - 2 * pad, h - 2 * pad

    size = min(style["max_font"], max(style["min_font"], int(box_h)))
    while True:
        font = _font(size)
        lines = wrap_text(text, font, box_w)
        stroke = max(1, size // 16)
        line_h = int(size * 1.2)
        if len(lines) * line_h <= box_h or size <= style["min_font"]:
            break
        size -= 2

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    block_h = len(lines) * line_h
    y = {"top": pad, "bottom": h - pad - block_h}.get(style["valign"], (h - block_h) // 2)
    for line in lines:
        lw = font.getlength(line)
        x = {"left": pad, "right": w - pad - lw}.get(style["align"], (w - lw) / 2)
        draw.text((x, y), line, font=font, fill=style["color"], stroke_width=stroke, stroke_fill=style["stroke"])
        y += line_h
    return img
