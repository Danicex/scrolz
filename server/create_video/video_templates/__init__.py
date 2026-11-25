"""Video templates.

A template is a python file in this folder named vt_<anything>.py that defines a dict called TEMPLATE.
Drop a new file in here and it is picked up automatically, nothing else to register.
Pick one per chunk with  chunk["video_tmpl"] = "vt_a"  (the file name without .py).

Every template must have a "main" and a "caption" region and may have a "second" region.
Regions are fractions (0..1) of the card, so changing width/height never breaks the layout:

    "main":    {"x": 0, "y": 0,      "w": 1, "h": 0.6735}
    "caption": {"x": 0, "y": 0.6735, "w": 1, "h": 0.0877, "bg": "#C8D0DA", ...caption style...}
    "second":  {"x": 0, "y": 0.7612, "w": 1, "h": 0.2388}            (optional)

Caption style keys (all optional): bg, color, stroke, max_font, min_font, padding, align, valign.
Template keys: width, height, canvas, card_color, corner_radius, bg_sound, beat_max_words, beat_max_seconds.
"""
import importlib
import pkgutil

REQUIRED_REGIONS = ("main", "caption")
OPTIONAL_REGIONS = ("second",)

DEFAULTS = {
    "width": 1080,
    "height": 1920,
    "canvas": "#F5F4F1",  # colour outside the rounded card (StyleConfig.lightBackground)
    "card_color": "#000000",  # colour of the card behind the regions
    "corner_radius": 0,
    "bg_sound": True,
    "beat_max_words": 8,  # a beat (one caption + one visual) never has more words than this
    "beat_max_seconds": 4.0,  # ...or lasts longer than this
}

CAPTION_DEFAULTS = {
    "bg": None,
    "color": "#FFFFFF",
    "stroke": "#000000",
    "max_font": 64,
    "min_font": 28,
    "padding": 24,
    "align": "center",  # left | center | right
    "valign": "middle",  # top | middle | bottom
}


def _validate(name, t):
    regions = t.get("regions", {})
    for r in REQUIRED_REGIONS:
        if r not in regions:
            raise ValueError(f"template {name!r} needs a {r!r} region")
    for r, box in regions.items():
        if r not in REQUIRED_REGIONS + OPTIONAL_REGIONS:
            raise ValueError(f"template {name!r}: unknown region {r!r}")
        for k in ("x", "y", "w", "h"):
            if not 0 <= box.get(k, -1) <= 1:
                raise ValueError(f"template {name!r}: region {r!r} needs {k} between 0 and 1")


def load_templates():
    """{"vt_a": {...full template...}, ...} for every vt_*.py that defines TEMPLATE."""
    found = {}
    for mod in pkgutil.iter_modules(__path__):
        if not mod.name.startswith("vt_"):
            continue
        tmpl = getattr(importlib.import_module(f"{__name__}.{mod.name}"), "TEMPLATE", None)
        if not tmpl:  # empty placeholder file
            continue
        full = {**DEFAULTS, **tmpl}
        full["caption_style"] = {**CAPTION_DEFAULTS, **{
            k: v for k, v in tmpl["regions"]["caption"].items() if k in CAPTION_DEFAULTS
        }}
        full["name"] = mod.name
        _validate(mod.name, full)
        found[mod.name] = full
    return found


def get_template(name):
    templates = load_templates()
    if name not in templates:
        raise ValueError(f"Unknown video_tmpl {name!r}. Available: {', '.join(sorted(templates)) or 'none'}")
    return templates[name]
