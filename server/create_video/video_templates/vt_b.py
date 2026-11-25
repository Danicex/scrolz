"""Template B: main video on top, a tall caption area underneath (no second video)."""

TEMPLATE = {
    "width": 1080,
    "height": 1920,
    "beat_max_words": 12,  # room for several lines
    "beat_max_seconds": 5.0,
    "regions": {
        "main": {"x": 0, "y": 0, "w": 1, "h": 0.671},
        "caption": {
            "x": 0, "y": 0.671, "w": 1, "h": 0.329,
            "bg": "#C8D0DA", "color": "#000000", "stroke": "#000000",
            "max_font": 84, "valign": "top", "padding": 48,
        },
    },
}
