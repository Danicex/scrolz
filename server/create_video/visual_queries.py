"""Turns beats into stock-footage search queries made of NOUNS ONLY ("ocean wave", "stock chart").

One LLM call per chunk (all beats at once, so the queries stay consistent with each other),
then every query is checked in code. Bad ones are re-asked once, and if they are still bad
they are rebuilt from the beat's own words, so a beat always ends up with a usable query.
"""
import json
import logging
import re

log = logging.getLogger(__name__)

MAX_QUERY_WORDS = 3

# words that can never be part of a noun-only query (articles, prepositions, pronouns, auxiliaries, common verbs)
STOP = set("""
a an the and or but if so as at by for from in into of on onto to up down out off over under with without about
is am are was were be been being do does did done have has had having will would can could should may might must
i me my we us our you your he him his she her it its they them their this that these those there here who whom
what which when where why how not no yes very just also then than too more most some any each every all
get gets got go goes going went make makes made take takes took see sees saw look looks come comes came give gives
gave know knows knew think thinks use uses used want wants need needs say says said tell tells told show shows
run runs ran walk walks walked eat eats ate drink drinks drank buy buys bought sell sells sold grow grows grew
""".split())

# real nouns that end like verbs/adverbs; everything else ending in -ing / -ed / -ly is treated as a verb or adverb
NOUN_EXCEPTIONS = set("""
building painting ceiling morning evening wedding clothing meeting feeling drawing blessing earring ring king wing
spring string thing sing swing bring sling sting cling bed red shed sled speed seed weed need breed bread hundred
family italy july lily jelly belly valley alley ally rally bully butterfly fly sly reply supply assembly gallery
""".split())

PROMPT = """You choose stock footage for a short vertical video. Below are the numbered beats (short phrases) of the narration, in order.

For EACH beat give ONE search query for a stock image or video that shows what is being talked about.

Hard rules for every query:
- NOUNS ONLY. 1 to 3 words. Concrete, visible things, places or people: "city skyline", "gold coins", "doctor", "forest".
- NO verbs, NO adjectives that are really verbs, NO -ing words used as actions, no adverbs, no pronouns, no articles, no punctuation.
- Never "man running" or "people laughing". Use the nouns: "marathon", "friends".
- Abstract idea (freedom, growth)? Pick the most common concrete noun that stands for it ("bird", "plant").
- Pick whatever best shows the beat; type is "video" when motion helps, otherwise "image".
- Different neighbouring beats should get different queries when the narration moves on.

Answer with JSON only, no other text, one object per beat:
[{{"i": 0, "query": "city skyline", "type": "video"}}, ...]

Beats:
{beats}
"""

RETRY = """These queries broke the rules (nouns only, 1-3 words, letters only):
{bad}

Give corrected queries for ONLY these beat numbers, same JSON format, JSON only.

Beats:
{beats}
"""


def llm_complete(prompt: str) -> str:
    """>>> THE ONE PLACE TO CONNECT YOUR LLM <<<
    Send `prompt` to the model you already use in utils/use_llm.py and return its text answer.
    Example (adapt to your helper):
        from utils.use_llm import <your function>
        return <your function>(prompt)
    Until this is wired the pipeline still runs: queries are built from each beat's own words.
    """
    raise NotImplementedError("wire llm_complete() in create_video/visual_queries.py to your LLM helper")


# ---------- checks ----------
def clean(query) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z ]", " ", str(query).lower())).strip()


def is_noun_word(w) -> bool:
    """Cheap check (no NLP model needed): rejects function words, common verbs, and anything that looks like
    a verb form or adverb (-ing, -ed, -ly) unless it is a known noun."""
    if len(w) < 3 or w in STOP:
        return False
    if w in NOUN_EXCEPTIONS:
        return True
    return not (w.endswith("ing") or (w.endswith("ed") and len(w) > 4) or (w.endswith("ly") and len(w) > 4))


def is_noun_query(query) -> bool:
    q = clean(query)
    words = q.split()
    return 1 <= len(words) <= MAX_QUERY_WORDS and all(is_noun_word(w) for w in words) and q == str(query).strip().lower()


def from_text(text) -> str:
    """Fallback with no LLM: the longest non-stop words of the beat (longer words are mostly nouns)."""
    words = [w for w in clean(text).split() if is_noun_word(w) and len(w) > 3]
    keep = sorted(dict.fromkeys(words), key=len, reverse=True)[:2]
    ordered = [w for w in words if w in keep]
    return " ".join(dict.fromkeys(ordered)) or "nature"


def _parse(raw):
    raw = re.sub(r"^```(?:json)?|```$", "", raw.strip(), flags=re.M).strip()
    start, end = raw.find("["), raw.rfind("]")
    data = json.loads(raw[start:end + 1])
    return {int(d["i"]): d for d in data if isinstance(d, dict) and "i" in d and "query" in d}


def _beat_lines(beats):
    return "\n".join(f"{b['i']}: {b['text']}" for b in beats)


def queries_for_beats(beats):
    """[{"i", "query", "type"}] - one per beat, in beat order. Never raises."""
    answers = {}
    try:
        answers = _parse(llm_complete(PROMPT.format(beats=_beat_lines(beats))))

        bad = [b for b in beats if b["i"] not in answers or not is_noun_query(answers[b["i"]]["query"])]
        if bad:
            listing = "\n".join(f"{b['i']}: {answers.get(b['i'], {}).get('query', '(missing)')}" for b in bad)
            answers.update(_parse(llm_complete(RETRY.format(bad=listing, beats=_beat_lines(bad)))))
    except NotImplementedError:
        log.warning("llm_complete() is not wired, building queries from the beat text")
    except Exception as e:
        log.warning("visual query LLM failed (%s: %s), building queries from the beat text", type(e).__name__, e)

    out = []
    for b in beats:
        a = answers.get(b["i"], {})
        query = clean(a.get("query", ""))
        if not is_noun_query(query):
            query = from_text(b["text"])
        kind = a.get("type") if a.get("type") in ("image", "video") else "video"
        out.append({"i": b["i"], "query": query, "type": kind})
    return out
