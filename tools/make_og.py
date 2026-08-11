#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Render one 1200x630 share card per language into docs/assets/.

A share card is the only part of the site most people ever see, and a German
reader being shown an English one is a small, avoidable rudeness. Rendered with
headless Chrome so the type is the same system font stack the site uses, rather
than approximated in an image editor.

    python3 tools/make_og.py

Only needs re-running when the wording in `og_sub` / `og_foot` / `h1` changes.
The output is committed, so a normal site build does not need Chrome.
"""

from __future__ import annotations

import html
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import site_content as C  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "docs" / "assets"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

TEMPLATE = """<!DOCTYPE html>
<html lang="{lang}"><head><meta charset="utf-8"><style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: 1200px; height: 630px; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif;
    color: #eef1f8;
    background:
      radial-gradient(900px 620px at 88% -10%, rgba(124,140,255,.34), transparent 62%),
      radial-gradient(700px 520px at -6% 8%, rgba(111,227,180,.20), transparent 58%),
      linear-gradient(165deg, #0e1430 0%, #131a2e 55%, #0b1022 100%);
    display: grid; grid-template-columns: 1fr auto;
    align-items: center; gap: 64px; padding: 0 84px;
    -webkit-font-smoothing: antialiased;
  }}
  .brand {{ display: flex; align-items: center; gap: 16px; margin-bottom: 30px; }}
  .brand svg {{ width: 46px; height: 46px; }}
  .brand span {{ font-size: 30px; font-weight: 800; letter-spacing: -.5px; }}
  .brand em {{ font-style: normal; color: #6fe3b4; }}
  h1 {{ font-size: {size}px; line-height: 1.06; letter-spacing: -2px; font-weight: 800; max-width: 15ch; }}
  p {{ margin-top: 22px; font-size: 26px; line-height: 1.45; color: #bcc5dc; max-width: 26ch; }}
  .art {{
    width: 300px; height: 300px; border-radius: 24%;
    background: linear-gradient(160deg, #1b2140, #10152b);
    border: 1px solid rgba(255,255,255,.12);
    display: grid; place-items: center;
    box-shadow: 0 40px 100px -24px rgba(78,107,245,.75), inset 0 2px 0 rgba(255,255,255,.08);
  }}
  .art svg {{ width: 58%; height: 58%; }}
  .foot {{ position: absolute; left: 84px; bottom: 46px; font-size: 21px; color: #8a93ad; }}
  .foot b {{ color: #bcc5dc; font-weight: 650; }}
</style></head>
<body>
  <svg width="0" height="0" style="position:absolute">
    <defs>
      <linearGradient id="g-c" x1="14" y1="10" x2="50" y2="54" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="#7C8CFF"/><stop offset="1" stop-color="#4E6BF5"/>
      </linearGradient>
      <linearGradient id="g-k" x1="24" y1="40" x2="48" y2="20" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="#6FE3B4"/><stop offset="1" stop-color="#8CEBC4"/>
      </linearGradient>
      <symbol id="i-mark" viewBox="0 0 64 64">
        <path d="M43.5 15.6 A20 20 0 1 0 43.5 48.4" fill="none" stroke="url(#g-c)" stroke-width="9.5" stroke-linecap="round"/>
        <path d="M24.5 32.6 L31.4 39.6 L45.2 22.4" fill="none" stroke="url(#g-k)" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
      </symbol>
    </defs>
  </svg>

  <div>
    <div class="brand"><svg><use href="#i-mark"/></svg><span>Chill<em>Mate</em></span></div>
    <h1>{title}</h1>
    <p>{sub}</p>
  </div>
  <div class="art"><svg><use href="#i-mark"/></svg></div>
  <div class="foot">{foot}</div>
</body></html>
"""


def bind_last_two(text: str) -> str:
    """Same orphan rule the site uses, so the card wraps the way the page does."""
    parts = text.rsplit(" ", 1)
    return parts[0] + " " + parts[1] if len(parts) == 2 and parts[0] else text


def render(lang: str) -> Path:
    s = C.STRINGS[lang]
    # German and Dutch headlines are longer; drop a step so they still fit.
    title = s["h1"]
    size = 62 if len(title) <= 46 else (56 if len(title) <= 56 else 50)

    page = TEMPLATE.format(
        lang=C.LANG_TAGS[lang],
        size=size,
        title=html.escape(bind_last_two(title)),
        sub=html.escape(s["og_sub"]),
        foot=html.escape(s["og_foot"]),
    )

    out = ASSETS / (f"og.png" if lang == "en" else f"og-{lang}.png")
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "og.html"
        src.write_text(page, encoding="utf-8")
        subprocess.run(
            [CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
             "--force-device-scale-factor=1", f"--screenshot={out}",
             "--window-size=1200,630", f"file://{src}"],
            capture_output=True, timeout=90, check=True,
        )
    return out


def main():
    if not Path(CHROME).exists():
        sys.exit(f"Chrome not found at {CHROME}; the committed og-*.png stay as they are.")
    for lang in C.LANGS:
        path = render(lang)
        print(f"  {path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
