import json
import logging
import re
from functools import lru_cache

import openai

import config  # loads .env

log = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def get_client():
    # created on first use, so importing this file never needs the key
    return openai.OpenAI()  # reads OPENAI_API_KEY


def ask_llm(prompt):
    reply = get_client().chat.completions.create(
        model=config.LLM_MODEL,
        max_completion_tokens=1500,
        messages=[{"role": "user", "content": prompt}],
    )
    return reply.choices[0].message.content


def ask_llm_json(prompt, retries=1):
    """Ask for JSON and parse it. Retries once, returns None if it still isn't valid."""
    for _ in range(retries + 1):
        raw = ask_llm(prompt) or ""
        raw = re.sub(r"^```(?:json)?|```$", "", raw.strip(), flags=re.MULTILINE).strip()
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            match = re.search(r"\[.*\]", raw, flags=re.DOTALL)  # JSON array hiding in extra text
            if match:
                try:
                    return json.loads(match.group(0))
                except json.JSONDecodeError:
                    pass
    log.warning("LLM did not return valid JSON")
    return None


def summarize_text(text):
    return ask_llm("Summarize this text in 2-3 sentences:\n\n" + text)


def convert_to_quiz(text):
    """List of {"question", "options", "answer"}."""
    quiz = ask_llm_json(
        "Write 3 multiple-choice questions based on the text below. "
        "Reply with ONLY a JSON array, no other text, like this:\n"
        '[{"question": "...", "options": ["A text", "B text", "C text", "D text"], "answer": "A"}]\n\n'
        "Text:\n" + text
    )
    if not isinstance(quiz, list):
        return []
    return [q for q in quiz if isinstance(q, dict) and "question" in q]


def generate_visuals(text):
    """Search ideas for stock footage: [{"query": "city traffic", "type": "image" | "video"}, ...]"""
    ideas = ask_llm_json(
        "Read the text below and give 5 stock-media search queries, in the order the text goes. "
        "Each query: 2-4 words, something concrete you can photograph or film (no abstract words). "
        'Use "video" for at most 2 of them and "image" for the rest. '
        "Reply with ONLY a JSON array, no other text, like this:\n"
        '[{"query": "city traffic", "type": "image"}]\n\n'
        "Text:\n" + text[:3000]
    )
    if not isinstance(ideas, list):
        return []

    clean = []
    for item in ideas:
        if isinstance(item, dict) and isinstance(item.get("query"), str) and item["query"].strip():
            kind = "video" if item.get("type") == "video" else "image"
            clean.append({"query": item["query"].strip(), "type": kind})
    return clean
