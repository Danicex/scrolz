import os
import re

import numpy as np
import random
from config import AUDIO_DIR

MODEL_PATH = "models/kokoro-v1.0.onnx"
VOICES_PATH = "models/voices-v1.0.bin"
VOICE = "af_heart"
LANG = "en-us"
MAX_CHARS = 300
PAUSE_SECONDS = 0.25

_kokoro = None


def get_kokoro():
    """Loads Kokoro once per worker."""
    global _kokoro
    if _kokoro is None:
        from kokoro_onnx import Kokoro

        _kokoro = Kokoro(MODEL_PATH, VOICES_PATH)
    return _kokoro


def split_text(text, max_chars=MAX_CHARS):
    """Sentences grouped into pieces of at most ~max_chars."""
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    pieces, current = [], ""
    for sentence in sentences:
        if current and len(current) + len(sentence) + 1 > max_chars:
            pieces.append(current)
            current = sentence
        else:
            current = f"{current} {sentence}".strip()
    if current:
        pieces.append(current)
    return pieces


def convert_to_speech(text, filename, project_name):
    """Text -> wav in audio/. Returns the path."""
    import soundfile as sf

    kokoro = get_kokoro()
    parts, rate = [], 24000
    for piece in split_text(text):
        samples, rate = kokoro.create(piece, voice=VOICE, speed=1.0, lang=LANG)
        pause = np.zeros(int(rate * PAUSE_SECONDS), dtype=np.float32)
        parts += [np.asarray(samples, dtype=np.float32).reshape(-1), pause]

    if not parts:
        raise ValueError(f"No audio generated for {filename!r} (empty text?)")

    out_path = os.path.join(AUDIO_DIR, f"{project_name}_{random.randint(100000, 999999)}", f"{filename}.wav")
    

    sf.write(out_path, np.concatenate(parts), rate)
    return out_path