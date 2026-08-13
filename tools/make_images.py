#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate AVIF versions of every screenshot, and squeeze the touch icon.

Why this exists.

The site's text is already small: 11 KB of HTML, 12 KB of CSS and 6 KB of
JavaScript over the wire, all gzipped. Measured against the live site, images
were **811 KB of an 840 KB page**, which is 96.5% of everything a visitor
downloads. Nothing else on the site is within an order of magnitude of that, so
this is the only optimisation worth building a tool for.

AVIF carries these particular images extremely well. They are UI screenshots:
large flat areas, hard edges, a narrow palette, and no film grain, which is the
exact case where a modern codec pulls away from JPEG. Measured on the real
files, the set drops from 870 KB to about 227 KB.

    python3 tools/make_images.py

Every AVIF is written beside its JPEG rather than replacing it. The JPEG stays
as the `<picture>` fallback, so a browser that has never heard of AVIF is served
exactly what it was served before. The press kit keeps the JPEGs too, because a
journalist dropping a screenshot into a document should not have to think about
codecs.

Output is committed, so a normal site build needs neither Pillow nor an encoder.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: python3 -m pip install pillow")

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "docs" / "assets"
SHOTS = ASSETS / "shots"

# Quality 60 in AVIF is not quality 60 in JPEG. On these screenshots it is
# visually indistinguishable from the source at roughly a quarter of the size;
# pushing lower starts to soften the small type inside the phone frames, which
# is the one thing these images exist to show.
AVIF_QUALITY = 60
AVIF_SPEED = 4          # slower encode, smaller file; this runs rarely


def convert(path: Path) -> tuple[int, int]:
    """Write `path` as AVIF beside itself. Returns (before, after) in bytes."""
    out = path.with_suffix(".avif")
    image = Image.open(path)
    # The phone frames are opaque; the watch shot is a PNG that may not be.
    if image.mode in ("RGBA", "LA", "P"):
        image = image.convert("RGBA")
        has_alpha = image.getchannel("A").getextrema()[0] < 255
        if not has_alpha:
            image = image.convert("RGB")
    else:
        image = image.convert("RGB")
    image.save(out, "AVIF", quality=AVIF_QUALITY, speed=AVIF_SPEED)
    return path.stat().st_size, out.stat().st_size


def shrink_touch_icon() -> tuple[int, int] | None:
    """The apple-touch-icon was 25 KB for a 180px square.

    It has to stay PNG, because that is what iOS reads, but it does not have to
    stay a full-colour one. These icons are flat vector art with a handful of
    distinct colours, so an adaptive palette is lossless in practice and about
    six times smaller.
    """
    icon = ASSETS / "icon-180.png"
    if not icon.exists():
        return None
    before = icon.stat().st_size
    image = Image.open(icon).convert("RGBA")
    quantised = image.quantize(colors=255, method=Image.Quantize.FASTOCTREE)
    quantised.save(icon, "PNG", optimize=True)
    return before, icon.stat().st_size


def main():
    if not SHOTS.exists():
        sys.exit(f"missing {SHOTS}")

    sources = sorted(p for p in SHOTS.iterdir() if p.suffix in (".jpg", ".png"))
    if not sources:
        sys.exit("no screenshots to convert")

    total_before = total_after = 0
    print(f"{'file':<22}{'before':>9}{'avif':>9}{'saved':>8}")
    for path in sources:
        before, after = convert(path)
        total_before += before
        total_after += after
        print(f"{path.name:<22}{before // 1024:>8}K{after // 1024:>8}K"
              f"{100 - after * 100 // before:>7}%")

    print(f"{'':-<48}")
    print(f"{'screenshots':<22}{total_before // 1024:>8}K{total_after // 1024:>8}K"
          f"{100 - total_after * 100 // total_before:>7}%")

    icon = shrink_touch_icon()
    if icon:
        before, after = icon
        print(f"{'icon-180.png':<22}{before // 1024:>8}K{after // 1024:>8}K"
              f"{100 - after * 100 // before:>7}%")

    saved = (total_before - total_after) + ((icon[0] - icon[1]) if icon else 0)
    print(f"\n{saved // 1024} KB less to download, per visitor, per cold visit.")
    print("The JPEGs stay where they are as the <picture> fallback.")


if __name__ == "__main__":
    main()
