"""Beats: the voice-over cut into short phrases, each with exact start/end times.

One beat = one caption on screen + one visual on screen, so what you see matches what you hear.

Where the timings come from (first one that exists wins):
  1. chunk["words"]  - [{"word", "start", "end"}, ...] if your TTS gives word timestamps
                       (Kokoro's KPipeline can; ElevenLabs "with-timestamps" can too).
  2. Whisper word timestamps on the finished audio. Works for ANY voice (Kokoro, ElevenLabs, ...),
     and Whisper is already loaded for captions, so this is the default.
"""
import logging
import re

from create_video.generate_caption import transcribe_words

log = logging.getLogger(__name__)

SENTENCE_END = re.compile(r"[.!?…]['\")\]]*$")
CLAUSE_END = re.compile(r"[,;:—–-]['\")\]]*$")
PAUSE = 0.45  # a silence this long between two words always ends a beat (seconds)
MIN_WORDS = 3  # don't leave tiny beats behind ("Yes." alone is fine, a stray "of" is not)


def _split(words, max_words, max_seconds):
    """Words -> lists of words. Break at sentence ends, long pauses and clause ends, never past the limits."""
    beats, cur = [], []
    for i, w in enumerate(words):
        cur.append(w)
        nxt = words[i + 1] if i + 1 < len(words) else None
        text = w["word"].strip()
        span = w["end"] - cur[0]["start"]

        if nxt is None:
            break
        pause = nxt["start"] - w["end"]
        end_here = (
            SENTENCE_END.search(text)
            or pause >= PAUSE
            or (CLAUSE_END.search(text) and len(cur) >= MIN_WORDS + 1)
            or len(cur) >= max_words
            or span >= max_seconds
        )
        if end_here:
            beats.append(cur)
            cur = []
    if cur:
        beats.append(cur)

    # a leftover of 1-2 words glues onto the beat before it, if that still fits
    merged = []
    for b in beats:
        if merged and len(b) < MIN_WORDS and len(merged[-1]) + len(b) <= max_words + 2 \
                and not SENTENCE_END.search(merged[-1][-1]["word"].strip()):
            merged[-1].extend(b)
        else:
            merged.append(b)
    return merged


def make_beats(audio_path, duration, max_words=8, max_seconds=4.0, words=None):
    """[{"i": 0, "text": "...", "start": 0.0, "end": 2.4}, ...]

    Beats are back to back: a beat lasts until the next one starts, the first starts at 0 and the
    last ends at `duration`, so there is never a gap with no visual or no caption.
    """
    words = words or transcribe_words(audio_path)
    words = [
        {"word": str(w["word"]).strip(), "start": float(w["start"]), "end": float(w["end"])}
        for w in words
        if str(w.get("word", "")).strip()
    ]
    if not words:
        return []

    groups = _split(words, max_words, max_seconds)
    beats = []
    for i, g in enumerate(groups):
        start = 0.0 if i == 0 else g[0]["start"]
        end = groups[i + 1][0]["start"] if i + 1 < len(groups) else duration
        beats.append({"i": i, "text": " ".join(w["word"] for w in g), "start": start, "end": min(end, duration)})

    return [b for b in beats if b["end"] - b["start"] > 0.05]
