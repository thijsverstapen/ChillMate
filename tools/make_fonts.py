#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cut the Inter webfont down to the characters this site actually renders.

Who pays for this file.

Nobody on an Apple device: the stack is `-apple-system` first, so iPhones and
Macs use San Francisco and never touch Inter at all. The 133 KB is paid entirely
by visitors on Windows, Android and Linux, which makes it the one asset whose
cost falls on exactly the people least likely to be the audience and most likely
to be on a slower connection.

The site renders 120 distinct characters across all five languages. Shipping the
full Latin and Latin-Extended ranges to deliver 120 glyphs is the definition of
paying for something nobody uses.

    python3 tools/make_fonts.py

The subset is deliberately wider than those 120, for two reasons. The risk
checker has a free-text field for medication names, so a visitor can type
characters no page contains. And a subset pinned to today's copy would break
quietly the first time somebody writes a word with a character in it that was
not there before. Latin-1 plus Latin Extended-A covers every language the app
ships in with room to spare, and a character outside it simply falls through to
the next font in the stack, which is what would have happened anyway.

Originals are kept as `.full.woff2` so this is reversible without a download.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

try:
    from fontTools import subset
    from fontTools.ttLib import TTFont
except ImportError:
    sys.exit("fonttools is required: python3 -m pip install fonttools brotli")

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "docs" / "assets" / "fonts"
# Originals live outside docs/ so they are never published. Keeping a 130 KB
# pristine copy next to the 63 KB subset in the served directory would have
# undone most of the saving the moment anyone deployed it.
ORIGINALS = ROOT / "tools" / "font-originals"

# Kept in step with the unicode-range in style.css, so the browser never asks
# for a file that no longer contains what the range promised.
RANGES = {
    "inter-latin.woff2": (
        "U+0020-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,"
        "U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD"
    ),
    "inter-latin-ext.woff2": (
        "U+0100-017F,U+0192,U+01FA-01FF,U+0218-021B,U+1E00-1E9F,U+1EF2-1EFF,"
        "U+2020,U+20A0-20AB,U+20AD-20C0,U+2113"
    ),
}

# Layout features worth keeping. Kerning and ligatures are what make Inter look
# like Inter; everything else is weight the page never asks for.
LAYOUT_FEATURES = "kern,liga,clig,calt,ccmp,locl,mark,mkmk,rlig"


def subset_one(name: str, unicodes: str) -> tuple[int, int]:
    path = FONTS / name
    if not path.exists():
        raise SystemExit(f"missing {path}")

    # Keep a pristine copy the first time, so re-running never subsets a subset.
    ORIGINALS.mkdir(exist_ok=True)
    original = ORIGINALS / name
    if not original.exists():
        shutil.copy2(path, original)

    before = original.stat().st_size
    font = TTFont(original)
    options = subset.Options()
    options.flavor = "woff2"
    options.layout_features = LAYOUT_FEATURES.split(",")
    options.desubroutinize = True
    options.drop_tables += ["FFTM"]
    options.name_IDs = ["*"]          # keep the licence strings; it is OFL
    options.name_legacy = True
    options.notdef_outline = True

    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=subset.parse_unicodes(unicodes))
    subsetter.subset(font)
    font.flavor = "woff2"
    font.save(path)
    font.close()
    return before, path.stat().st_size


def main():
    total_before = total_after = 0
    print(f"{'file':<26}{'before':>9}{'after':>9}{'saved':>8}")
    for name, unicodes in RANGES.items():
        before, after = subset_one(name, unicodes)
        total_before += before
        total_after += after
        print(f"{name:<26}{before // 1024:>8}K{after // 1024:>8}K"
              f"{100 - after * 100 // before:>7}%")
    print(f"{'':-<52}")
    print(f"{'total':<26}{total_before // 1024:>8}K{total_after // 1024:>8}K"
          f"{100 - total_after * 100 // total_before:>7}%")
    print(f"\n{(total_before - total_after) // 1024} KB saved for every visitor "
          f"not on an Apple device.")
    print(f"Originals kept in {ORIGINALS.relative_to(ROOT)}/, outside the published tree.")


if __name__ == "__main__":
    main()
