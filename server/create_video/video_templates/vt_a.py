"""Template A: main video on top, a thin caption strip, a second video at the bottom."""

TEMPLATE = {
    "width": 1080,
    "height": 1920,
    "beat_max_words": 7,  # the caption strip is thin, keep each caption short
    "regions": {
        "main": {"x": 0, "y": 0, "w": 1, "h": 0.6735},
        "caption": {
            "x": 0, "y": 0.6735, "w": 1, "h": 0.0877,
            "bg": "#C8D0DA", "color": "#000000", "stroke": "#000000",
            "max_font": 60, "valign": "middle",
        },
        "second": {"x": 0, "y": 0.7612, "w": 1, "h": 0.2388},
    },
}
