#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the ChillMate GitHub Pages site into docs/.

Why a generator rather than hand-written HTML, or Jekyll:

  * Hand-written means the header, the icon sprite and the footer are copied
    into thirteen files, and the fourteenth edit is the one that forgets one.
  * Jekyll would fix that, but it runs on GitHub's side where a build error
    turns the whole site into a 404 with no local way to see it coming. This
    site has already been dark once.

So: author once here, emit plain static HTML that GitHub only has to serve.

    python3 tools/build_site.py

The stylesheet lives at docs/assets/style.css and is inlined into every page at
build time, so editing it means re-running this script. Everything else in
docs/ except assets/ is generated and safe to delete.
"""

from __future__ import annotations

import functools
import html
import json
import os
import re
import shutil
import struct
import zipfile
from pathlib import Path
from urllib.parse import quote

import privacy_nl
import site_content as C

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
ASSETS = DOCS / "assets"

SITE_ORIGIN = "https://thijsverstapen.github.io"
BASE_PATH = "/ChillMate/"
BASE_URL = SITE_ORIGIN + BASE_PATH
REPO = "https://github.com/thijsverstapen/ChillMate"
EMAIL = "chillmate@icloud.com"

# No storefront in the path. `apps.apple.com/app/id...` sends a reader to their
# own regional store, which for a site in five languages is the difference
# between a Dutch visitor landing in a Dutch listing and landing in the US one
# with a price in dollars and a button that will not install anything for them.
APP_ID = "6774212606"
APP_STORE_URL = f"https://apps.apple.com/app/id{APP_ID}"
VERSION = "4.2.1"
BUILD = "422"
UPDATED = "2026-08-11"


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------

def e(text: str) -> str:
    """Escape text for HTML."""
    return html.escape(text, quote=True)


def no_orphan(text: str) -> str:
    """Bind the last two words so a wrapped heading never leaves one alone.

    A title that breaks as "look after yourself." over "yourself." reads as a
    mistake. Tying the final pair with a non-breaking space moves both words to
    the next line together instead.
    """
    parts = text.rsplit(" ", 1)
    if len(parts) != 2 or not parts[0]:
        return text
    return parts[0] + " " + parts[1]


def t(text: str) -> str:
    """Escaped body text, with the last two words bound together.

    The same rule as `no_orphan`, applied to running prose rather than only to
    headings. A paragraph whose final line carries one word is the same
    typographic fault as a heading that does; it is simply harder to notice,
    which is how "I never see a single thing you put into\u00a0it." sat on the
    front page through four rewrites with "it." alone on the last line.
    """
    return e(no_orphan(text))


# --------------------------------------------------------------------------
# cache busting
# --------------------------------------------------------------------------
#
# GitHub Pages sends `Cache-Control: max-age=600` on everything and gives you no
# way to change it, so a hashed filename buys nothing from the CDN today. It
# buys two things that matter anyway: the service worker can cache a stylesheet
# for as long as it likes and still be certain it has the current one, and a
# deploy can never leave a visitor holding yesterday's CSS with today's markup.
# It also means the day this site sits behind a CDN you control, immutable
# caching is already correct rather than a change waiting to be remembered.

def fingerprint(name: str) -> str:
    """`style.css` -> `style.a1b2c3d4.css`, from the file's own content."""
    import hashlib
    source = ASSETS / name
    digest = hashlib.sha256(source.read_bytes()).hexdigest()[:8]
    stem, _, suffix = name.rpartition(".")
    hashed = f"{stem}.{digest}.{suffix}"
    target = ASSETS / hashed
    if not target.exists():
        target.write_bytes(source.read_bytes())
    return hashed.split("/")[-1] if "/" in name else hashed


def asset_map() -> dict:
    """Hashed names for every asset a page links, built once per run.

    The screenshots are in here as well as the code. A service worker that
    caches aggressively is only safe if the name changes when the bytes do;
    otherwise the first visitor to see a redesigned screen keeps the old one
    until they clear their browser.
    """
    names = ["style.css", "chapters.css", "site.js"]
    names += [f"shots/{p.name}" for p in sorted((ASSETS / "shots").iterdir())
              if p.suffix in (".avif", ".jpg", ".png")]
    names += [f"badges/{p.name}" for p in sorted((ASSETS / "badges").iterdir())
              if p.suffix == ".svg"]
    return {name: fingerprint(name) for name in names}


ASSET = {}


def slug(text: str) -> str:
    value = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return value or "section"


def icon(name: str, cls: str = "icon", style: str = "") -> str:
    attrs = f' class="{cls}"' if cls else ""
    attrs += f' style="{style}"' if style else ""
    return f'<svg{attrs} aria-hidden="true"><use href="#i-{name}"/></svg>'


def image_size(path: Path):
    """Real pixel size of a PNG or JPEG, read from the file.

    Hardcoded width/height attributes went wrong once already: `sips -Z` scales
    by the longest edge, so a portrait screenshot asked to be 560 came out 257
    wide while the markup kept claiming 560. Reading the file removes the class
    of bug rather than the instance.
    """
    data = path.read_bytes()
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", data[16:24])
    if data[:2] == b"\xff\xd8":
        i = 2
        while i < len(data) - 9:
            if data[i] != 0xFF:
                i += 1
                continue
            marker = data[i + 1]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                          0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                height, width = struct.unpack(">HH", data[i + 5:i + 9])
                return width, height
            if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            i += 2 + struct.unpack(">H", data[i + 2:i + 4])[0]
    raise ValueError(f"cannot read dimensions of {path}")


def rel(depth: int) -> str:
    """Path back to docs/ from a page nested `depth` directories deep."""
    return "../" * depth if depth else ""


# --------------------------------------------------------------------------
# the icon sprite
# --------------------------------------------------------------------------

_STROKE = ('fill="none" stroke="currentColor" stroke-width="1.8" '
           'stroke-linecap="round" stroke-linejoin="round"')

SPRITE = f"""<svg width="0" height="0" style="position:absolute" aria-hidden="true" focusable="false">
  <defs>
    <linearGradient id="g-c" x1="14" y1="10" x2="50" y2="54" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#7C8CFF"/><stop offset="1" stop-color="#4E6BF5"/>
    </linearGradient>
    <linearGradient id="g-k" x1="24" y1="40" x2="48" y2="20" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#6FE3B4"/><stop offset="1" stop-color="#8CEBC4"/>
    </linearGradient>
  </defs>

  <symbol id="i-mark" viewBox="0 0 64 64">
    <path d="M43.5 15.6 A20 20 0 1 0 43.5 48.4" fill="none" stroke="url(#g-c)" stroke-width="9.5" stroke-linecap="round"/>
    <path d="M24.5 32.6 L31.4 39.6 L45.2 22.4" fill="none" stroke="url(#g-k)" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
  </symbol>

  <symbol id="i-shield" viewBox="0 0 24 24" {_STROKE}>
    <path d="M12 3l7 3v5.5c0 4.3-2.9 7.9-7 9.5-4.1-1.6-7-5.2-7-9.5V6z"/><path d="M9 12l2.2 2.2L15.5 10"/>
  </symbol>
  <symbol id="i-book" viewBox="0 0 24 24" {_STROKE}>
    <path d="M5 4.5A1.5 1.5 0 016.5 3H18a1 1 0 011 1v14.5"/><path d="M6.5 16H19v4.5H6.5A1.5 1.5 0 015 19V6"/><path d="M9 7.5h6M9 11h4"/>
  </symbol>
  <symbol id="i-chart" viewBox="0 0 24 24" {_STROKE}>
    <path d="M4 20V4"/><path d="M4 20h16"/><path d="M8 16v-4M12.5 16V8M17 16v-6"/>
  </symbol>
  <symbol id="i-life" viewBox="0 0 24 24" {_STROKE}>
    <circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="3.6"/>
    <path d="M6.8 6.8l2 2M17.2 6.8l-2 2M6.8 17.2l2-2M17.2 17.2l-2-2"/>
  </symbol>
  <symbol id="i-flask" viewBox="0 0 24 24" {_STROKE}>
    <path d="M10 3v6.2L5.4 17a2 2 0 001.7 3h9.8a2 2 0 001.7-3L14 9.2V3"/><path d="M9 3h6"/><path d="M7.4 14h9.2"/>
  </symbol>
  <symbol id="i-watch" viewBox="0 0 24 24" {_STROKE}>
    <rect x="7" y="6" width="10" height="12" rx="3"/><path d="M9.5 6l.4-2.4A1 1 0 0110.9 3h2.2a1 1 0 011 .6l.4 2.4M9.5 18l.4 2.4a1 1 0 001 .6h2.2a1 1 0 001-.6l.4-2.4"/><path d="M12 9.8V12l1.6 1"/>
  </symbol>
  <symbol id="i-bell" viewBox="0 0 24 24" {_STROKE}>
    <path d="M18 8.5a6 6 0 10-12 0c0 5-2 6.5-2 6.5h16s-2-1.5-2-6.5z"/><path d="M13.7 19a2 2 0 01-3.4 0"/>
  </symbol>
  <symbol id="i-lock" viewBox="0 0 24 24" {_STROKE}>
    <rect x="4.5" y="10.5" width="15" height="10" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 018 0v3"/>
  </symbol>
  <symbol id="i-alert" viewBox="0 0 24 24" {_STROKE}>
    <path d="M12 4.5l8.5 15h-17z"/><path d="M12 10v4"/><path d="M12 17.2v.1"/>
  </symbol>
  <symbol id="i-info" viewBox="0 0 24 24" {_STROKE}>
    <circle cx="12" cy="12" r="8.5"/><path d="M12 11.2v5"/><path d="M12 8.3v.1"/>
  </symbol>
  <symbol id="i-check" viewBox="0 0 24 24" {_STROKE}>
    <circle cx="12" cy="12" r="8.5"/><path d="M8.6 12.2l2.4 2.4 4.4-5"/>
  </symbol>
  <symbol id="i-mail" viewBox="0 0 24 24" {_STROKE}>
    <rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M3.5 7l7.4 5.4a2 2 0 002.2 0L20.5 7"/>
  </symbol>
  <symbol id="i-bug" viewBox="0 0 24 24" {_STROKE}>
    <rect x="7.5" y="7.5" width="9" height="12" rx="4.5"/><path d="M9.4 7a2.6 2.6 0 015.2 0"/>
    <path d="M4.5 11h3M16.5 11h3M4.5 16h3M16.5 16h3M12 8v11"/>
  </symbol>
  <symbol id="i-ext" viewBox="0 0 24 24" {_STROKE}>
    <path d="M14 4.5h5.5V10"/><path d="M19.5 4.5L11 13"/><path d="M18 14.5v4a1.5 1.5 0 01-1.5 1.5h-11A1.5 1.5 0 014 18.5v-11A1.5 1.5 0 015.5 6h4"/>
  </symbol>
  <symbol id="i-chev" viewBox="0 0 24 24" {_STROKE}>
    <path d="M6.5 9.5L12 15l5.5-5.5"/>
  </symbol>
  <symbol id="i-up" viewBox="0 0 24 24" {_STROKE}>
    <path d="M12 19V5.5"/><path d="M6 11.5L12 5.5l6 6"/>
  </symbol>
  <symbol id="i-globe" viewBox="0 0 24 24" {_STROKE}>
    <circle cx="12" cy="12" r="8.5"/><path d="M3.6 12h16.8"/>
    <path d="M12 3.5c2.3 2.4 3.5 5.4 3.5 8.5S14.3 18.1 12 20.5c-2.3-2.4-3.5-5.4-3.5-8.5S9.7 5.9 12 3.5z"/>
  </symbol>
  <symbol id="i-code" viewBox="0 0 24 24" {_STROKE}>
    <path d="M8.5 8L4.5 12l4 4"/><path d="M15.5 8l4 4-4 4"/><path d="M13.4 5.5l-2.8 13"/>
  </symbol>
  <symbol id="i-phone" viewBox="0 0 24 24" {_STROKE}>
    <rect x="6.5" y="2.5" width="11" height="19" rx="2.5"/><path d="M10.5 5.4h3"/>
  </symbol>
  <symbol id="i-cloud" viewBox="0 0 24 24" {_STROKE}>
    <path d="M7 18a4 4 0 01-.4-8A5.5 5.5 0 0117.4 10 3.9 3.9 0 0117 18z"/>
  </symbol>
  <symbol id="i-hand" viewBox="0 0 24 24" {_STROKE}>
    <path d="M9 11V5.5a1.5 1.5 0 013 0V11"/><path d="M12 11V4.6a1.5 1.5 0 013 0V11"/>
    <path d="M15 11.5V7.6a1.5 1.5 0 013 0V15a6 6 0 01-6 6h-.7a5 5 0 01-3.7-1.7L5 15.6a1.6 1.6 0 012.3-2.2L9 15V8.6a1.5 1.5 0 00-3 0"/>
  </symbol>
  <symbol id="i-doc" viewBox="0 0 24 24" {_STROKE}>
    <path d="M13.5 3H7a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V8.5z"/><path d="M13.5 3v5.5H19"/>
  </symbol>
  <symbol id="i-tag" viewBox="0 0 24 24" {_STROKE}>
    <path d="M11 3.5H4.5v6.6a2 2 0 00.6 1.4l7.6 7.6a2 2 0 002.8 0l5-5a2 2 0 000-2.8l-7.6-7.6a2 2 0 00-1.4-.6z"/>
    <path d="M8 8v.1"/>
  </symbol>
  <symbol id="i-print" viewBox="0 0 24 24" {_STROKE}>
    <path d="M7 9V3.5h10V9"/><rect x="3.5" y="9" width="17" height="7.5" rx="2"/><path d="M7 14h10v6.5H7z"/>
  </symbol>
  <symbol id="i-github" viewBox="0 0 24 24">
    <path fill="currentColor" d="M12 2C6.48 2 2 6.58 2 12.25c0 4.53 2.87 8.37 6.84 9.73.5.09.68-.22.68-.5 0-.24-.01-.87-.01-1.71-2.78.62-3.37-1.37-3.37-1.37-.45-1.18-1.11-1.49-1.11-1.49-.91-.64.07-.62.07-.62 1 .07 1.53 1.06 1.53 1.06.89 1.57 2.34 1.12 2.91.86.09-.66.35-1.12.63-1.38-2.22-.26-4.56-1.14-4.56-5.06 0-1.12.39-2.03 1.03-2.75-.1-.26-.45-1.3.1-2.71 0 0 .84-.28 2.75 1.05a9.3 9.3 0 015 0c1.91-1.33 2.75-1.05 2.75-1.05.55 1.41.2 2.45.1 2.71.64.72 1.03 1.63 1.03 2.75 0 3.93-2.35 4.8-4.58 5.05.36.32.68.94.68 1.9 0 1.37-.01 2.47-.01 2.81 0 .27.18.59.69.49A10.07 10.07 0 0022 12.25C22 6.58 17.52 2 12 2z"/>
  </symbol>
</svg>"""


# --------------------------------------------------------------------------
# page chrome
# --------------------------------------------------------------------------

# Runs before first paint. It exists only to add the `js` class, which is what
# lets the stylesheet hide anything at all: scroll-reveal starts at opacity 0,
# and if this script never runs then neither does the one that reveals it, so
# the CSS must not hide it in the first place.
JS_BOOT = "<script>document.documentElement.classList.add('js')</script>"


def page_urls(key: str) -> dict:
    """Every language's URL for a page key, for hreflang and the switcher."""
    if key == "home":
        return {lang: BASE_PATH + ("" if lang == "en" else lang + "/") for lang in C.LANGS}
    if key == "support":
        return {lang: BASE_PATH + ("support/" if lang == "en" else lang + "/support/") for lang in C.LANGS}
    if key == "checker":
        return {lang: BASE_PATH + ("risk-checker/" if lang == "en" else lang + "/risk-checker/")
                for lang in C.LANGS}
    if key == "howto":
        return {lang: BASE_PATH + ("how-it-works/" if lang == "en" else lang + "/how-it-works/")
                for lang in C.LANGS}
    if key == "privacy":
        # Only two, because only English and Dutch have a policy. hreflang is
        # allowed to be a partial set; claiming a de/fr/es policy that is really
        # the English one would be the wrong signal.
        return {"en": BASE_PATH + "privacy/", "nl": BASE_PATH + "nl/privacy/"}
    return {}


CRITICAL_CSS = """
:root{--bg-0:#0b1022;--bg-1:#0e1430;--bg-2:#131a2e;--text:#eef1f8;
--text-soft:#bcc5dc;--text-dim:#8a93ad;--primary:#7c8cff;--mint:#6fe3b4;
--glow-a:rgba(124,140,255,.2);--glow-b:rgba(111,227,180,.13)}
*{box-sizing:border-box}
body{margin:0;color:var(--text);background:linear-gradient(180deg,#0e1430,#131a2e 55%,#0b1022);
font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Inter","Segoe UI",Roboto,sans-serif;
line-height:1.62;-webkit-font-smoothing:antialiased;overflow-x:hidden;min-height:100vh}
.site-head{display:flex;align-items:center;justify-content:space-between;gap:16px;
flex-wrap:wrap;max-width:1080px;margin-inline:auto;padding:18px 20px 0}
.chapter{padding:clamp(84px,11vw,168px) 20px}
.chapter>.inner{max-width:1080px;margin:0 auto}
h1{font-size:clamp(2.7rem,6.6vw,5.4rem);line-height:1;letter-spacing:-.035em;
font-weight:800;max-width:19ch;margin:0}
"""


def head(lang, title, desc, canonical, depth, key="", extra_head="", body_class=""):
    a = rel(depth) + "assets/"
    # A share card in a language the reader does not speak is the one part of
    # the site most people ever see, so each language gets its own.
    # The card has to advertise the page it is attached to. Falls back to the
    # home card for pages that do not have one of their own.
    stem = {"support": "og-support", "checker": "og-checker",
            "howto": "og-howto"}.get(key, "og")
    og = f"{stem}.png" if lang == "en" else f"{stem}-{lang}.png"
    if not (ASSETS / og).exists():
        og = "og.png" if lang == "en" else f"og-{lang}.png"
    # Preloading has to describe the same choice the <picture> will make, or the
    # browser warms one file and then downloads another. `type` keeps browsers
    # without AVIF from touching it at all; they fall through to the JPEG.
    preload = ""
    if key == "home":
        sizes = "(max-width: 620px) 78vw, 400px"
        preload = (
            f'  <link rel="preload" as="image" type="image/avif" fetchpriority="high"\n'
            f'        imagesrcset="{a}shots/{ASSET["shots/home@half.avif"]} 320w, {a}shots/{ASSET["shots/home.avif"]} 640w"\n'
            f'        imagesizes="{sizes}" href="{a}shots/{ASSET["shots/home.avif"]}" />')
    # The checker and the walk only exist on two pages; everything else stops
    # downloading them.
    chapters_css = ('\n  <link rel="stylesheet" href="%s%s" />' % (a, ASSET["chapters.css"])
                    if key in ("home", "checker") else "")
    urls = page_urls(key)

    alts = ""
    for other in C.LANGS:
        if other in urls:
            alts += (f'\n  <link rel="alternate" hreflang="{C.LANG_TAGS[other]}" '
                     f'href="{SITE_ORIGIN}{urls[other]}" />')
    if urls:
        alts += f'\n  <link rel="alternate" hreflang="x-default" href="{SITE_ORIGIN}{urls["en"]}" />'

    return f"""<!DOCTYPE html>
<html lang="{C.LANG_TAGS[lang]}" data-sw-scope="{BASE_PATH}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{e(title)}</title>
  <meta name="description" content="{e(desc)}" />
  <meta name="theme-color" content="#0e1430" />
  <meta name="referrer" content="strict-origin-when-cross-origin" />
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; font-src 'self'; connect-src 'self'; form-action 'none'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'" />
  <meta name="color-scheme" content="dark" />
  <!-- Safari on iOS turns this into a banner offering the app directly. It is
       the one visitor who is already holding the device the app runs on, so
       they should not have to find the button. -->
  <meta name="apple-itunes-app" content="app-id={APP_ID}" />
  <link rel="canonical" href="{SITE_ORIGIN}{canonical}" />{alts}
  <link rel="icon" href="{a}mark.svg" type="image/svg+xml" />
  <link rel="apple-touch-icon" href="{a}icon-180.png" />
{preload}
  <link rel="manifest" href="{BASE_PATH}manifest.webmanifest" />
  <link rel="alternate" type="application/atom+xml" title="ChillMate releases" href="{BASE_PATH}changelog/feed.xml" />

  <meta property="og:site_name" content="ChillMate" />
  <meta property="og:title" content="{e(title)}" />
  <meta property="og:description" content="{e(desc)}" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="{SITE_ORIGIN}{canonical}" />
  <meta property="og:locale" content="{C.LANG_TAGS[lang]}" />
  <meta property="og:image" content="{BASE_URL}assets/{og}" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta property="og:image:alt" content="ChillMate. A calm, private place to look after yourself." />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="{e(title)}" />
  <meta name="twitter:description" content="{e(desc)}" />
  <meta name="twitter:image" content="{BASE_URL}assets/{og}" />
{JS_BOOT}
  <style>{CRITICAL_CSS}</style>
  <link rel="stylesheet" href="{a}{ASSET["style.css"]}" />{chapters_css}{extra_head}
</head>
<body{f' class="{body_class}"' if body_class else ""}>
{SPRITE}
<a class="skip" href="#main">{e(C.STRINGS[lang]["skip"])}</a>
"""


def header(lang, depth, current, key=""):
    s = C.STRINGS[lang]
    r = rel(depth)
    # Localised pages live under /<lang>/, so "home" from /nl/support/ is "../"
    # and from /nl/ is "./", never the docs root that `rel(depth)` gives.
    home = r if lang == "en" else ("../" * (depth - 1) if depth > 1 else "./")
    # Dutch has its own policy; the other languages point at the English one.
    privacy = (("../" * (depth - 1) if depth > 1 else "./") + "privacy/") if lang == "nl" else r + "privacy/"
    support = (r + "support/") if lang == "en" else (("../" * (depth - 1) if depth > 1 else "./") + "support/")
    howto = (r + "how-it-works/") if lang == "en" else (
        ("../" * (depth - 1) if depth > 1 else "./") + "how-it-works/")

    def item(href, label, ico, name):
        cur = ' aria-current="page"' if current == name else ""
        return f'      <a href="{href}"{cur}>{icon(ico) if ico else ""}{e(label)}</a>\n'

    nav = item(home, s["nav_home"], "", "home")
    nav += item(howto, s["nav_howto"], "phone", "howto")
    nav += item(privacy, s["nav_privacy"], "shield", "privacy")
    nav += item(support, s["nav_support"], "life", "support")
    nav += item(REPO, s["nav_github"], "github", "github")

    # Not every page exists in every language: only English and Dutch have a
    # privacy policy. A language with no counterpart goes to its own home page
    # rather than vanishing from the switcher, which would leave a reader on a
    # page they cannot read with no way out.
    urls = page_urls(key) or page_urls("home")
    homes = page_urls("home")
    menu = ""
    for other in C.LANGS:
        cur = ' aria-current="true"' if other == lang else ""
        menu += (f'        <a lang="{C.LANG_TAGS[other]}" hreflang="{C.LANG_TAGS[other]}" '
                 f'href="{urls.get(other, homes[other])}"{cur}>{e(C.LANG_NAMES[other])}</a>\n')

    return f"""<main class="wrap" id="main">

  <header class="site-head">
    <a class="brand" href="{home}" aria-label="ChillMate">
      <svg class="mark draw" aria-hidden="true"><use href="#i-mark"/></svg>
      <span class="name">Chill<em>Mate</em></span>
    </a>
    <div class="head-right">
      <nav class="site-nav" aria-label="{e(s["nav_home"])}">
{nav}      </nav>
      <details class="lang">
        <summary>{icon("globe")}<span>{e(C.LANG_NAMES[lang])}</span></summary>
        <div class="lang-menu" role="group" aria-label="{e(s["lang_label"])}">
{menu}        </div>
      </details>
    </div>
  </header>
"""


def footer(lang, depth):
    s = C.STRINGS[lang]
    r = rel(depth)
    home = r if lang == "en" else ("../" * (depth - 1) if depth > 1 else "./")
    support = (r + "support/") if lang == "en" else (("../" * (depth - 1) if depth > 1 else "./") + "support/")
    sep = '\n    <span class="sep" aria-hidden="true">·</span>\n    '
    return f"""
  <footer>
    <a href="{home}">{e(s["nav_home"])}</a>{sep}<a href="{r}privacy/">{e(s["nav_privacy"])}</a>{sep}<a href="{support}">{e(s["nav_support"])}</a>{sep}<a href="{r}changelog/">Changelog</a>{sep}<a href="{REPO}">{e(s["nav_github"])}</a>{sep}<a href="mailto:{EMAIL}">{EMAIL}</a>
    <span class="made">ChillMate {VERSION} · {e(s["made"])}</span>
  </footer>

</main>
<button type="button" class="to-top" data-to-top hidden aria-label="{e(s["to_top"])}">
  {icon("up")}
</button>
<script src="{r}assets/{ASSET["site.js"]}" defer></script>
</body>
</html>
"""


def shot(name):
    """Fingerprinted filename for a screenshot, falling back to the plain one."""
    return ASSET.get(f"shots/{name}", name)


def srcset_for(src, depth, full_w, half_w):
    """`srcset` over the full and half-width variants of one file."""
    r = rel(depth)
    half = src.replace(".", "@half.")
    if not (ASSETS / "shots" / half).exists():
        return f'{r}assets/shots/{shot(src)} {full_w}w'
    return f'{r}assets/shots/{shot(half)} {half_w}w, {r}assets/shots/{shot(src)} {full_w}w'


def picture(src, alt, depth, sizes, full_w, half_w, lazy=True, priority=False, cls=""):
    """An <img> wrapped in <picture>, offering AVIF before the original.

    Images were 811 KB of an 840 KB page, so this is where the whole weight of
    the site lived. AVIF carries UI screenshots particularly well: flat areas,
    hard edges, a narrow palette and no grain. Measured on these exact files the
    set drops 76%, and the hero from 111 KB to 25 KB.

    The original stays as the fallback rather than being replaced. A browser
    that does not know AVIF ignores the <source> and gets precisely the file it
    got before, which is the entire point of doing it this way instead of
    swapping the format outright.
    """
    r = rel(depth)
    w, h = image_size(ASSETS / "shots" / src)
    avif = src.rsplit(".", 1)[0] + ".avif"
    loading = ' loading="lazy" decoding="async"' if lazy and not priority else ' decoding="async"'
    if priority:
        loading += ' fetchpriority="high"'
    klass = f' class="{cls}"' if cls else ""

    fallback = srcset_for(src, depth, full_w, half_w)
    modern = srcset_for(avif, depth, full_w, half_w) if (ASSETS / "shots" / avif).exists() else ""
    source = (f'<source type="image/avif" srcset="{modern}" sizes="{sizes}" />\n              '
              if modern else "")
    return (f'{source}<img{klass} src="{r}assets/shots/{shot(src)}" srcset="{fallback}" '
            f'sizes="{sizes}" width="{w}" height="{h}" alt="{e(alt)}"{loading} />')


PHONE_SIZES = "(max-width: 620px) 78vw, 400px"


# Apple asks for a minimum of 40px and clear space around the badge worth 10%
# of its height, which `.badge-link` provides as padding. Sized above that
# minimum because at 40 the badge is narrower and shorter than the ghost button
# next to it, which puts the secondary action ahead of the primary one.
BADGE_HEIGHT = 52


def store_badge(lang, depth):
    """Apple's own "Download on the App Store" artwork, in the reader's language.

    These are the official files, straight from Apple's marketing toolbox, and
    they are used unmodified because that is the condition attached to them:
    no recolouring, no redrawing, no setting the words in our own typeface. The
    black variant is the one meant for a dark background; it carries a #a6a6a6
    border so it reads as a bordered pill rather than a hole in the page.

    French is 126.5 wide where the others are 119.7, so the size is read out of
    each file rather than assumed. Getting that wrong would either stretch the
    artwork, which is also against the terms, or make the page jump as it
    loads.
    """
    name = f"badges/appstore-{lang}.svg"
    markup = (ASSETS / name).read_text(encoding="utf-8")
    w, h = re.search(r'width="([0-9.]+)"\s+height="([0-9.]+)"', markup).groups()
    scale = BADGE_HEIGHT / float(h)
    return (f'<img class="badge" src="{rel(depth)}assets/badges/{ASSET[name]}" '
            f'width="{round(float(w) * scale)}" height="{BADGE_HEIGHT}" '
            f'alt="{e(C.STRINGS[lang]["cta_get"])}" decoding="async" />')


def phone(src, alt, depth, lazy=True, priority=False):
    # The label is what a reader in reduced-data mode sees instead of the
    # screenshot, so it has to be the same sentence the image was showing.
    return f"""<div class="phone">
        <div class="phone-shell">
          <div class="phone-screen" data-reduced-label="{e(alt)}">
            <picture>
              {picture(src, alt, depth, PHONE_SIZES, 640, 320, lazy, priority)}
            </picture>
            <span class="phone-island"></span>
          </div>
        </div>
      </div>"""


# --------------------------------------------------------------------------
# home
# --------------------------------------------------------------------------

SHOTS = ["home.jpg", "risk.jpg", "help.jpg", "support.jpg", "privacy.jpg"]


def watch(depth):
    alt = ("The watch app's Safety screen, offering an emergency call and a way "
           "to ping your phone.")
    return f"""<div class="watch">
        <div class="watch-shell">
          <div class="watch-screen">
            <picture>
              {picture("watch.png", alt, depth, "(max-width: 620px) 46vw, 190px", 416, 208)}
            </picture>
          </div>
        </div>
      </div>"""


def diagram(lang):
    s = C.STRINGS[lang]
    return f"""<svg class="diagram" viewBox="0 0 520 150" role="img"
     aria-label="{e(s["diagram_title"])}">
  <rect class="d-box" x="8" y="46" width="104" height="58" rx="14"/>
  <text class="d-label" x="60" y="72" text-anchor="middle">{e(s["diagram_you"])}</text>
  <text class="d-dim" x="60" y="90" text-anchor="middle">{e(s["diagram_phone"])}</text>

  <path class="d-flow" d="M118 75 H186" stroke-width="2" fill="none" stroke-dasharray="5 5"/>
  <path class="d-flow" d="M180 70 l7 5 -7 5" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>

  <rect class="d-box" x="192" y="46" width="118" height="58" rx="14"/>
  <text class="d-label" x="251" y="72" text-anchor="middle">{e(s["diagram_icloud"])}</text>
  <text class="d-dim" x="251" y="90" text-anchor="middle">{e(s["diagram_optional"])}</text>

  <path class="d-stop" d="M330 75 H392" stroke-width="2" fill="none" stroke-dasharray="4 6" opacity="0.55"/>
  <g class="d-stop" stroke-width="2.4" stroke-linecap="round">
    <circle cx="361" cy="75" r="13" fill="none"/>
    <path d="M352.5 66.5 L369.5 83.5"/>
  </g>

  <rect class="d-box" x="400" y="46" width="112" height="58" rx="14" opacity="0.45"/>
  <text class="d-label" x="456" y="72" text-anchor="middle" opacity="0.6">{e(s["diagram_server"])}</text>
  <text class="d-dim" x="456" y="90" text-anchor="middle" opacity="0.6">{e(s["diagram_none"])}</text>
</svg>"""


# Each footnote is a claim and the place in the source that settles it. Keyed
# rather than numbered, because the page has already been recut twice and a
# positional index goes stale silently: the last cut left three footnotes
# listed with nothing pointing at them and two markers aimed at rows that no
# longer existed. Numbers are assigned at render time, in the order the page
# actually uses them, and a note nobody cites is never printed.
FOOTNOTES = [
    ("network",  REPO + "/search?q=URLSession&type=code", "search: URLSession"),
    ("cloudkit", REPO + "/blob/main/ChillMate/ChillMateModelContainer.swift#L81", "ChillMateModelContainer.swift:81"),
    ("pin",      REPO + "/blob/main/ChillMate/AppLockView.swift#L441", "AppLockView.swift:441"),
    ("switcher", REPO + "/blob/main/ChillMate/AppLockView.swift#L26", "AppLockView.swift:26"),
    ("backup",   REPO + "/blob/main/ChillMate/EncryptedBackupService.swift#L72", "EncryptedBackupService.swift:72"),
    ("discreet", REPO + "/blob/main/ChillMate/SecurityHealthCheckView.swift#L18", "SecurityHealthCheckView.swift:18"),
    ("ondevice", REPO + "/blob/main/ChillMate/OnDeviceAffirmationService.swift#L8", "OnDeviceAffirmationService.swift:8"),
    ("combos",   REPO + "/blob/main/ChillMate/SubstanceInteractions.swift#L59", "SubstanceInteractions.swift:59"),
    ("helplines", REPO + "/blob/main/ChillMate/SupportDirectoryViews.swift#L69", "SupportDirectoryViews.swift:69"),
]
FOOTNOTE_KEYS = [key for key, _, _ in FOOTNOTES]

# Which spec row cites which note.
SPEC_FOOTNOTES = {4: "network", 6: "helplines", 7: "combos", 8: "ondevice",
                  9: "cloudkit", 10: "pin"}
# Which privacy check cites which note, by position in the (now three-item) list.
CHECK_FOOTNOTES = {0: "pin", 1: "backup", 2: "discreet"}


class Footnotes:
    """Numbers the notes a page cites, in the order it cites them."""

    def __init__(self):
        self.used = []
        self.counts = {}

    def cite(self, key):
        if key not in FOOTNOTE_KEYS:
            raise KeyError(f"unknown footnote {key!r}")
        if key not in self.used:
            self.used.append(key)
        number = self.used.index(key) + 1
        # A claim can be cited from more than one chapter, and four of them are:
        # "no networking" is footnoted from the statement, the proof and the
        # spec table. Each marker therefore needs an id of its own. Emitting
        # `fnref-1` three times is invalid HTML, and it silently breaks the
        # return arrow, which lands on whichever copy the browser met first
        # rather than the one the reader actually left.
        seen = self.counts[key] = self.counts.get(key, 0) + 1
        return (f'<sup class="fn"><a href="#fn-{number}" id="fnref-{number}-{seen}" '
                f'aria-label="Footnote {number}">{number}</a></sup>')

    def render(self, strings):
        rows = ""
        for number, key in enumerate(self.used, start=1):
            index = FOOTNOTE_KEYS.index(key)
            _, url, label = FOOTNOTES[index]
            total = self.counts.get(key, 1)
            # One arrow per place the note is cited, numbered when there is more
            # than one, so a reader who followed the third marker can get back
            # to the third marker.
            back = " ".join(
                f'<a href="#fnref-{number}-{seen}" '
                f'aria-label="Back to text{f" {seen}" if total > 1 else ""}">'
                f'&#8617;{seen if total > 1 else ""}</a>'
                for seen in range(1, total + 1)
            )
            rows += (f'          <li id="fn-{number}"><div>{e(strings["footnotes"][index])} '
                     f'<a href="{url}"><code>{e(label)}</code></a> '
                     f'{back}</div></li>\n')
        return rows


def chapter(body, ident="", invert=False, extra="", inner="inner"):
    classes = "chapter" + (" chapter--invert" if invert else "") + (f" {extra}" if extra else "")
    ident = f' id="{ident}"' if ident else ""
    return f'\n  <section class="{classes}"{ident}>\n    <div class="{inner}">\n{body}    </div>\n  </section>\n'


def demo_payload(lang):
    """The app's own interaction table, in this language, for the live demo."""
    raw = json.loads((Path(__file__).resolve().parent / "interactions.json")
                     .read_text(encoding="utf-8"))
    s = C.STRINGS[lang]
    return {
        "levels": {key: value[lang] for key, value in raw["levels"].items()},
        "riskLabels": {key: value[lang] for key, value in raw["riskLabels"].items()},
        "medication": [{"key": m["key"], "label": m["label"][lang], "aliases": m["aliases"]}
                       for m in raw["medication"]],
        "assessments": {key: {"title": spec["title"][lang],
                              "levels": {lv: text[lang] for lv, text in spec["levels"].items()}}
                        for key, spec in raw["assessments"].items()},
        "copy": {
            "empty": s["demo_empty"],
            "noneTitle": s["demo_none_title"],
            "noneBody": s["demo_none_body"],
            "medsHit": s["demo_meds_hit"],
            "medsNone": s["demo_meds_none"],
        },
        "rules": [{"substances": r["substances"], "level": r["level"],
                   "warning": r["warning"][lang]} for r in raw["rules"]],
    }, raw["substances"], raw["timings"]


def demo_body(lang, depth):
    """The risk checker itself, so the home page and its own page share one copy.

    It was inlined in `build_home`. Giving it a page of its own meant either
    duplicating forty lines of markup or lifting them out, and duplicated markup
    is how the two copies quietly stop agreeing.
    """
    s = C.STRINGS[lang]
    payload, substances, timings = demo_payload(lang)
    chips = "".join(
        f'            <button type="button" class="demo-chip" data-substance="{e(name)}" '
        f'aria-pressed="false">{e(name)}</button>\n'
        for name in substances
    )
    timing_buttons = "".join(
        f'            <button type="button" class="demo-chip" data-timing="{item["key"]}" '
        f'aria-pressed="{"true" if i == 0 else "false"}">{e(item["label"][lang])}</button>\n'
        for i, item in enumerate(timings)
    )
    return f"""      <div class="demo demo--wide panel" data-demo style="margin-top:clamp(26px,3vw,44px)">
        <div>
          <p class="eyebrow">{e(s["demo_pick"])}</p>
          <div class="demo-picker">
{chips}          </div>

          <p class="eyebrow" style="margin-top:26px">{e(s["demo_meds_label"])}</p>
          <input class="demo-input" type="text" data-demo-meds autocomplete="off"
                 spellcheck="false" placeholder="{e(s["demo_meds_ph"])}"
                 aria-label="{e(s["demo_meds_label"])}" />
          <p class="meds-out" data-demo-meds-out role="status" aria-live="polite"></p>

          <p class="eyebrow" style="margin-top:22px">{e(s["demo_timing_label"])}</p>
          <div class="demo-picker" role="group" aria-label="{e(s["demo_timing_label"])}">
{timing_buttons}          </div>

          <div class="demo-actions">
            <button type="button" class="btn btn-ghost" data-demo-try>{icon("flask")}{e(s["demo_try"])}</button>
            <button type="button" class="chip-btn" data-demo-reset aria-label="{e(s["demo_reset"])}">{e(s["demo_reset"])}</button>
            <button type="button" class="chip-btn" data-demo-share hidden
                    data-copied-label="{e(s["demo_shared"])}">{icon("doc")}{e(s["demo_share"])}</button>
            <button type="button" class="chip-btn" onclick="window.print()" aria-label="{e(s["demo_print"])}">{icon("print")}{e(s["demo_print"])}</button>
            <span class="copy-done"></span>
          </div>
        </div>
        <div>
          <div class="demo-out" data-demo-out role="status" aria-live="polite" aria-atomic="true"></div>
          <p class="meta">{e(s["demo_note"])}</p>
        </div>
      </div>
      <script type="application/json" id="cm-interactions">{json.dumps(payload, ensure_ascii=False)}</script>
"""


def build_home(lang):
    s = C.STRINGS[lang]
    depth = 0 if lang == "en" else 1
    r = rel(depth)
    canonical = page_urls("home")[lang]
    support = (r + "support/") if lang == "en" else "./support/"
    # This used to be a mailto that put the reader in their own mail client to
    # send a blank message and wait for a reply. Now there is an app to install,
    # so the ask is the install.
    get = APP_STORE_URL

    out = head(lang, s["home_title"], s["home_desc"], canonical, depth, "home",
               body_class="exhibition")
    out += header(lang, depth, "home", "home")

    # ---- sticky sub-nav, revealed once the hero is behind you
    chapters = "".join(
        f'        <a href="#{ident}">{e(label)}</a>\n' for ident, label in s["nav_chapters"]
    )
    out += f"""
  <nav class="subnav" data-subnav aria-label="{e(s["walk_eyebrow"])}">
    <div class="inner">
      <span class="title">ChillMate</span>
{chapters}      <a class="btn btn-primary" href="{get}">{e(s["cta_get_short"])}</a>
    </div>
  </nav>
"""

    # ---- 1. hero
    out += chapter(f"""      <h1>{e(no_orphan(s["h1"]))}</h1>
      <div class="hero-cols">
        <div>
          <p class="lede">{t(s["lede"])}</p>
          <div class="cta-row">
            <a class="badge-link" href="{get}">{store_badge(lang, depth)}</a>
            <a class="btn btn-ghost" href="#inside">{icon("phone")}{e(s["cta_see"])}</a>
          </div>
          <p class="status-note">{icon("info")}{t(s["status_note"])}</p>
          <a class="scroll-cue" href="#who">{e(s["scroll_cue"])}{icon("chev")}</a>
        </div>
        <div class="hero-phone-big">
          {phone(SHOTS[0], s["walk"][0][1], depth, lazy=False, priority=True)}
        </div>
      </div>
""", extra="hero-full")

    # The second chapter used to be three enormous zeros: 0 servers, 0 accounts,
    # 0 trackers. It was the first thing after the hero, and it sold the wrong
    # thing to the wrong person. A reader deciding whether this app is for them
    # does not open with a question about server architecture, and three noughts
    # answer a question they have not asked yet. The same facts still appear, in
    # the privacy chapter, where the reader has arrived wanting them and where
    # they read as reassurance rather than as a boast.

    # ---- 2. who it is for
    points = "".join(
        f'            <li>{icon("check")}<span>{t(point)}</span></li>\n'
        for point in s["audience_points"]
    )
    out += chapter(f"""      <div class="split">
        <div>
          <p class="eyebrow">{e(s["audience_eyebrow"])}</p>
          <h2>{e(no_orphan(s["audience_h2"]))}</h2>
          <p>{t(s["audience_p"])}</p>
          <p>{s["audience_chill"]}</p>
        </div>
        <div class="split-panel">
          <ul class="checks stagger">
{points}          </ul>
        </div>
      </div>
""", ident="who")

    # ---- 3. the scroll-driven walk
    steps = ""
    frames = ""
    for i, (eyebrow, title, body) in enumerate(s["walk"]):
        marker = ""
        steps += f"""
          <div class="walk-step">
            <p class="eyebrow">{e(eyebrow)}</p>
            {phone(SHOTS[i], title, depth)}
            <h2>{e(no_orphan(title))}</h2>
            <p>{t(body)}{marker}</p>
          </div>
"""
        frames += ('              <picture>\n                '
                   + picture(SHOTS[i], title, depth, PHONE_SIZES, 640, 320)
                   + '\n              </picture>\n')

    out += chapter(f"""      <p class="eyebrow">{e(s["walk_eyebrow"])}</p>
      <h2>{e(no_orphan(s["walk_h2"]))}</h2>
      <div class="track" data-walk>
        <div class="stage" aria-hidden="true">
          <div class="stage-phone">
            <div class="phone">
              <div class="phone-shell">
                <div class="phone-screen" data-reduced-label="{e(s["walk_h2"])}">
{frames}                  <span class="phone-island"></span>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="beats-col">{steps}        </div>
      </div>
""", ident="inside", invert=True, extra="walk-scroll")

    # ---- 4. the playable risk checker
    checker = (r + "risk-checker/") if lang == "en" else "./risk-checker/"
    out += chapter(f"""      <p class="eyebrow">{e(s["demo_eyebrow"])}</p>
      <h2>{e(no_orphan(s["demo_h2"]))}</h2>
      <p>{t(s["demo_p"])}</p>
{demo_body(lang, depth)}      <div class="cta-row">
        <a class="btn btn-ghost" href="{checker}">{icon("ext")}{e(s["demo_h2"].rstrip("."))}</a>
      </div>
""", ident="try", invert=True)

    # ---- 5. the second statement, carrying the strongest refusal
    #
    # The refusals moved to their own page, but this one is the spine of the
    # product and belongs where everybody sees it.
    out += chapter(f"""      <div class="statement-grid stagger" style="grid-template-columns:1fr">
        <div><b class="statement-line">{e(s["statement2_big"])}</b></div>
      </div>
      <p>{t(s["statement2_note"])}</p>
""", ident="never", invert=True, extra="statement")

    # ---- 6. privacy, the diagram, and the proof
    checks = "".join(
        f'            <li>{icon("check")}<span>{t(c)}</span></li>\n'
        for c in s["privacy_checks"]
    )
    out += chapter(f"""      <div class="split">
        <div>
          <p class="eyebrow">{e(s["privacy_eyebrow"])}</p>
          <h2>{e(no_orphan(s["privacy_h2"]))}</h2>
          <p>{t(s["privacy_intro"])}</p>
          <ul class="checks stagger">
{checks}          </ul>
          <div class="cta-row">
            <a class="btn btn-ghost" href="{r}privacy/">{icon("shield")}{e(s["privacy_link"])}</a>
          </div>
        </div>
        <div class="split-panel">
          <p class="eyebrow">{e(s["diagram_title"])}</p>
          {diagram(lang)}
        </div>
      </div>
""", ident="privacy")

    # ---- 7. specifications
    rows = ""
    for i, (label, value) in enumerate(s["specs"]):
        marker = ""
        rows += f"        <tr><th scope=\"row\">{e(label)}</th><td>{e(value)}{marker}</td></tr>\n"
    out += chapter(f"""      <p class="eyebrow">{e(s["specs_eyebrow"])}</p>
      <h2>{e(no_orphan(s["specs_h2"]))}</h2>
      <table class="specs">
        <tbody>
{rows}        </tbody>
      </table>
""", ident="specs", invert=True)

    # ---- 8. the closing ask
    #
    # The page used to end on the disclaimer: nine chapters of persuasion and
    # then a legal notice, with nothing to do. This is the ask, and it keeps
    # offering the checker and the crisis numbers beside it, because those are
    # useful to someone who is not going to install anything today.
    out += chapter(f"""      <p class="eyebrow">{e(s["close_eyebrow"])}</p>
      <h2>{e(no_orphan(s["close_h2"]))}</h2>
      <p class="lede">{t(s["close_p"])}</p>
      <div class="cta-row">
        <a class="badge-link" href="{get}">{store_badge(lang, depth)}</a>
        <a class="btn btn-ghost" href="#try">{icon("flask")}{e(s["demo_eyebrow"])}</a>
        <a class="btn btn-ghost" href="{support}">{icon("life")}{e(s["support_help_eyebrow"])}</a>
      </div>
""", ident="close", invert=True, extra="chapter--close")

    # ---- 9. the one disclaimer
    #
    # The footnote apparatus that used to live here moved to How it works, next
    # to the material it actually supports. What has to stay on every page is
    # this.
    out += chapter(f"""      <div class="callout">
        {icon("alert")}
        <p>{t(s["disclaimer"])}</p>
      </div>
""", ident="disclaimer", inner="inner narrow")

    out += footer(lang, depth)
    return out, canonical


# --------------------------------------------------------------------------
# support
# --------------------------------------------------------------------------

def action_label(lang, url):
    s = C.STRINGS[lang]
    if not url:
        return None
    if url.startswith("tel:"):
        return f'{s["call"]} {url[4:]}'
    host = url.split("//", 1)[-1].split("/", 1)[0]
    if host.startswith("www."):
        host = host[4:]
    return f'{s["open"]} {host}'


def country_panel(lang, code):
    s = C.STRINGS[lang]
    data = C.COUNTRIES[code]
    rows = ""
    for cat, name, url in data["items"]:
        title = name or s[f"cat_{cat}"]
        detail = s[f"cat_{cat}_d"]
        if not name and not url:
            detail = detail + " " + s["cat_generic_local"]
        label = action_label(lang, url)
        # A service keeps the name it actually has. Tagging it with its own
        # language is what stops a screen reader reading "Zelfmoordpreventie"
        # with English phonetics on the English page.
        name_lang = C.COUNTRY_LANG[code]
        tag = f'<span lang="{name_lang}">{e(title)}</span>' if (
            name and name_lang != lang) else e(title)
        head_html = f'<div class="t">{tag}'
        if url and not url.startswith("tel:"):
            head_html += icon("ext")
        head_html += "</div>"
        inner = (f'{head_html}<div class="d">{e(s[f"cat_{cat}"])} · {e(detail)}'
                 + (f' <strong>{e(label)}</strong>' if label else "") + "</div>")
        if url:
            rows += f'        <a class="res" href="{e(url)}">{inner}</a>\n'
        else:
            rows += f'        <div class="res">{inner}</div>\n'

    number = data["emergency"] or s["support_emergency_local"]
    return f"""      <div class="country-panel" data-country="{code}">
        <p class="emergency-line">{icon("alert", style="color:var(--danger)")}
          <span>{e(s["support_emergency_is"])} <b>{e(number)}</b></span>
        </p>
        <div class="grid two">
{rows}        </div>
      </div>
"""


def build_support(lang):
    s = C.STRINGS[lang]
    depth = 1 if lang == "en" else 2
    r = rel(depth)
    canonical = page_urls("support")[lang]

    out = head(lang, s["support_title"], s["support_desc"], canonical, depth, "support",
               body_class="support-page")
    out += header(lang, depth, "support", "support")

    faq = ""
    for question, answer in s["faq"]:
        faq += f"""        <details>
          <summary>{e(question)}<svg class="chev" aria-hidden="true"><use href="#i-chev"/></svg></summary>
          <div class="body"><p>{e(answer)}</p></div>
        </details>
"""

    options = "".join(
        f'          <option value="{code}">{e(C.COUNTRY_NAMES[lang][code])}</option>\n'
        for code in C.COUNTRY_ORDER
    )
    panels = "".join(country_panel(lang, code) for code in C.COUNTRY_ORDER)

    out += f"""
  <h1>{e(no_orphan(s["support_h1"]))}</h1>
  <p class="lede">{t(s["support_lede"])}</p>

  <div class="callout urgent" role="note">
    {icon("alert")}
    <p>{s["support_urgent"]}</p>
  </div>

  <section class="section">
    <p class="eyebrow">{e(s["support_help_eyebrow"])}</p>
    <div class="card" data-countries>
      <h2 id="services">{icon("life", style="color:var(--purple)")}{e(no_orphan(s["support_help_h2"]))}
        <a class="anchor" href="#services" aria-label="{e(s["support_help_h2"])}">#</a>
      </h2>
      <p>{t(s["support_help_p"])}</p>

      <div class="picker-row">
        <label for="country">{e(s["support_country_label"])}</label>
        <select id="country">
{options}        </select>
        <button type="button" class="chip-btn" onclick="window.print()" aria-label="{e(s["support_print"])}">{icon("print")}{e(s["support_print"])}</button>
      </div>

{panels}    </div>
  </section>

  <section class="section">
    <p class="eyebrow">{e(s["support_faq_eyebrow"])}</p>
    <div class="card">
      <div class="faq">
{faq}      </div>
    </div>
  </section>

  <section class="section">
    <p class="eyebrow">{e(s["support_contact_eyebrow"])}</p>
    <div class="card">
      <h2>{icon("mail", style="color:var(--primary)")}{e(s["support_contact_h2"])}</h2>
      <p>{s["support_contact_p"].format(email=f'<a href="mailto:{EMAIL}">{EMAIL}</a>')}
        <button type="button" class="copy" data-copy="{EMAIL}" data-copied-label="{e(s["copied"])}"
                hidden aria-label="{e(s["copy"])}">{icon("doc")}</button><span class="copy-done"></span>
      </p>
      <div class="contact-row">
        <a class="btn btn-primary" href="mailto:{EMAIL}">{icon("mail")}{e(s["support_email_btn"])}</a>
        <a class="btn btn-ghost" href="{REPO}/issues">{icon("bug")}{e(s["support_issue_btn"])}</a>
      </div>
    </div>
  </section>

  <section class="section">
    <div class="callout calm">
      {icon("shield")}
      <p>{e(s["policy_en_note"])} <a href="{r}privacy/">{e(s["privacy_link"])}</a></p>
    </div>
    <div class="callout">
      {icon("alert")}
      <p>{e(s["disclaimer"])}</p>
    </div>
  </section>
"""
    # Nine real questions with real answers, marked up as such. This is how a
    # search for "is ChillMate private" reaches the answer rather than the
    # home page.
    faq_ld = {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "inLanguage": C.LANG_TAGS[lang],
        "mainEntity": [
            {"@type": "Question", "name": question,
             "acceptedAnswer": {"@type": "Answer", "text": answer}}
            for question, answer in s["faq"]
        ],
    }
    out = out.replace("</head>", '  <script type="application/ld+json">'
                      + json.dumps(faq_ld, ensure_ascii=False) + "</script>\n</head>", 1)

    out += footer(lang, depth)
    return out, canonical


# --------------------------------------------------------------------------
# English-only pages
# --------------------------------------------------------------------------

def git(args, timeout=45, attempts=3):
    """Run a git command, retrying a stalled one before giving up.

    Building this site deletes and recreates several hundred files in docs/.
    Whatever watches this directory reacts to that by contending on the tree
    hard enough that git calls which normally take 20ms have been observed
    timing out at 60s, repeatedly, and then running at 20ms again minutes
    later with nothing changed. It is not the pathspec, not rename detection
    and not the git-lfs filter in the global config; all three were measured
    and cleared. It is transient and it is outside this script.

    So: try, wait, try again. A stall should cost a slow build, not a failed
    one, and a genuine breakage still surfaces after the last attempt.
    """
    import subprocess
    import time
    last = None
    for attempt in range(attempts):
        try:
            return subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                                  text=True, timeout=timeout, check=True).stdout.strip()
        except Exception as failure:
            last = failure
            if attempt + 1 < attempts:
                time.sleep(2 * (attempt + 1))
    raise last


@functools.lru_cache(maxsize=1)
def policy_history():
    """Every commit that has ever touched the privacy page, from git.

    A privacy policy is a promise that can be quietly edited. Almost nobody can
    show you the edits. This repository can, so it does: the list below is read
    out of git at build time, not typed in, which means it cannot fall out of
    step with what actually happened.
    """
    try:
        raw = git(["log", "--format=%h\x1f%ad\x1f%s", "--date=short",
                   "--", "docs/privacy/index.html"])
    except Exception as failure:
        # Outside a checkout there is genuinely no history and the page says so.
        # Inside one there always is, so falling back here would put "no history
        # available" directly under a paragraph promising the whole history.
        # That is worse than not building, so refuse.
        if (ROOT / ".git").exists():
            raise SystemExit(
                f"policy_history: git failed inside a checkout after retries "
                f"({failure}).\nThe privacy page would have shipped with an empty "
                f"history table. Build again once the tree is quiet."
            )
        return []
    rows = [tuple(parts) for parts in (line.split("\x1f") for line in raw.splitlines())
            if len(parts) == 3]
    if not rows and (ROOT / ".git").exists():
        raise SystemExit(
            "policy_history: git ran but returned nothing for "
            "docs/privacy/index.html, which has a long history. Refusing to "
            "ship an empty history table."
        )
    return rows


@functools.lru_cache(maxsize=1)
def source_checksum() -> tuple[str, int, str]:
    """A fingerprint of the app's Swift source, and the commit it came from.

    The privacy page says the app makes no network calls. That claim is about a
    specific pile of code, and without naming which pile it is a claim about
    nothing in particular: anybody checking it a year from now is reading a
    different repository. This pins it. Recompute the digest from the same files
    and you can tell whether you are looking at what was audited.
    """
    import hashlib
    targets = ("ChillMate", "ChillMateWatchApp", "ChillMateWatchAppWidget")
    swift = sorted(f for target in targets
                   for f in ROOT.glob(f"{target}/**/*.swift")
                   if "DerivedData" not in str(f))
    digest = hashlib.sha256()
    for path in swift:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(path.read_bytes())
    try:
        commit = git(["rev-parse", "--short", "HEAD"])
    except Exception:
        commit = "unknown"
    return digest.hexdigest()[:16], len(swift), commit


def build_privacy():
    lang, depth = "en", 1
    checksum, swift_count, commit = source_checksum()
    HISTORY = policy_history()
    history_rows = "".join(
        f'          <tr><td>{e(when)}</td><td>{e(subject)}</td>'
        f'<td><a href="{REPO}/commit/{sha}"><code>{e(sha)}</code></a></td></tr>\n'
        for sha, when, subject in HISTORY
    ) or '          <tr><td colspan="3">No history available in this build.</td></tr>\n'

    canonical = BASE_PATH + "privacy/"
    title = "ChillMate · Privacy Policy"
    desc = ("ChillMate's privacy policy, plus the honest detail: every network call the app "
            "makes, what a data breach could expose, and where to read the code.")

    out = head(lang, title, desc, canonical, depth)
    out += header(lang, depth, "privacy")
    out += f"""
  <h1>Privacy&nbsp;Policy</h1>
  <p class="lede">ChillMate keeps your information on your iPhone, where you control it. There are no servers collecting your data. There are no ad or analytics trackers. Nothing about you is ever sold or shared.</p>
  <p class="meta">Last updated: {UPDATED} · Applies to the ChillMate iOS app and this website.</p>

  <div class="card">
    <h2 id="short">{icon("shield", style="color:var(--primary)")}The short&nbsp;version
      <a class="anchor" href="#short" aria-label="Link to this section">#</a></h2>
    <ul>
      <li><strong>On your phone.</strong> Your profile, logs, plans and notes are stored on your iPhone.</li>
      <li><strong>No trackers.</strong> No ad networks, no analytics, no tracking code from anyone else.</li>
      <li><strong>Nothing sold.</strong> Your personal and health information is never sold or shared.</li>
      <li><strong>You are in control.</strong> You choose what to add and what to sync. You can delete all of it whenever you want.</li>
    </ul>
  </div>

  <div class="card">
    <h2 id="network">{icon("code", style="color:var(--mint)")}Every connection the app&nbsp;makes
      <a class="anchor" href="#network" aria-label="Link to this section">#</a></h2>
    <p>Most privacy policies describe intentions. This one lists what actually leaves the device, which is both shorter and easier to check.</p>
    <p>ChillMate's own code makes <strong>no internet connections at all</strong>: no <code>URLSession</code>, no analytics, no crash reporter, no remote settings. Everything in the table below is either an Apple service talking to your own account, or something you tapped.</p>
    <p class="meta">Checked against {swift_count} Swift files, commit <a href="{REPO}/commit/{commit}"><code>{commit}</code></a>, whose combined SHA-256 begins <code>{checksum}</code>. Recompute it from the same files and you can tell whether you are reading the code this page describes.</p>
    <div class="table-scroll">
      <table>
        <caption>Checked against ChillMate {VERSION} (build {BUILD}), across all {swift_count} Swift files in the app targets.</caption>
        <thead>
          <tr><th scope="col">What</th><th scope="col">Goes where</th><th scope="col">When</th></tr>
        </thead>
        <tbody>
          <tr><td>iCloud sync (CloudKit)</td><td>Your own private iCloud database</td><td>Only if you turn iCloud on. Apple holds it, and I cannot read it.</td></tr>
          <tr><td>Encrypted backup file</td><td>Your own iCloud Drive</td><td>Only if you turn backups on, or export a file yourself.</td></tr>
          <tr><td>Apple Watch mirror</td><td>Your own watch, directly</td><td>If you pair a watch. Device to device, over Watch Connectivity.</td></tr>
          <tr><td>Apple Health</td><td>Stays on the device</td><td>Only the categories you approve. HealthKit is local storage, not a service.</td></tr>
          <tr><td>An optional donation</td><td>Apple's In-App Purchase</td><td>Only if you tap it. Apple takes the payment, and I never see card details.</td></tr>
          <tr><td>A link you tap</td><td>Safari, to that site</td><td>Only on your tap. ChillMate does not fetch those pages itself.</td></tr>
          <tr><td>A call or message you send</td><td>Your phone app, your messages app</td><td>Only on your tap, and you see the message before it goes.</td></tr>
          <tr><td><strong>Anything to a ChillMate server</strong></td><td><strong>Nowhere</strong></td><td><strong>Never. There is no such server.</strong></td></tr>
        </tbody>
      </table>
    </div>
    <p><a href="{REPO}">Read the source</a> if you would like to check any of this for yourself.</p>
  </div>

  <div class="card">
    <h2 id="collected">{icon("doc", style="color:var(--purple)")}Category by&nbsp;category
      <a class="anchor" href="#collected" aria-label="Link to this section">#</a></h2>
    <p>These are the categories Apple asks every developer about. ChillMate's answer is the same in all of them.</p>
    <div class="table-scroll">
      <table>
        <thead><tr><th scope="col">Category</th><th scope="col">Collected by ChillMate</th><th scope="col">Linked to you</th><th scope="col">Used to track you</th></tr></thead>
        <tbody>
          <tr><td>Health &amp; Fitness</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
          <tr><td>Sensitive Info</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
          <tr><td>Contact Info</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
          <tr><td>Contacts</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
          <tr><td>Location</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
          <tr><td>User Content</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
          <tr><td>Identifiers</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
          <tr><td>Usage Data</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
          <tr><td>Diagnostics</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
          <tr><td>Purchases</td><td class="no">No</td><td class="no">No</td><td class="no">No</td></tr>
        </tbody>
      </table>
    </div>
    <p>To be exact about the word. ChillMate <em>stores</em> a great deal on your phone, including health and other sensitive things you type in. It <em>collects</em> none of it. Collecting would mean taking it off your device and holding it somewhere you cannot reach.</p>
  </div>

  <div class="card">
    <h2 id="compare">{icon("hand", style="color:var(--pink)")}What a wellbeing app usually&nbsp;knows
      <a class="anchor" href="#compare" aria-label="Link to this section">#</a></h2>
    <p>This is not an accusation against anyone in particular. It is what the ordinary, entirely above-board version of an app like this holds, because holding it is how that version works.</p>
    <div class="table-scroll">
      <table>
        <thead><tr><th scope="col">Question</th><th scope="col">The usual answer</th><th scope="col">ChillMate</th></tr></thead>
        <tbody>
          <tr><th scope="row">Who can read your entries?</th><td>You, and whoever holds the database</td><td><span class="yes">Only you</span></td></tr>
          <tr><th scope="row">What does a breach expose?</th><td>Everything on the server</td><td><span class="yes">Nothing. There is no server.</span></td></tr>
          <tr><th scope="row">What can be handed over on request?</th><td>Your account and its contents</td><td><span class="yes">Nothing is held to hand over</span></td></tr>
          <tr><th scope="row">What happens if it is acquired?</th><td>The new owner inherits the data</td><td><span class="yes">There is no data to inherit</span></td></tr>
          <tr><th scope="row">What does an email address unlock?</th><td>Your account</td><td><span class="yes">There is no account</span></td></tr>
          <tr><th scope="row">Who sees which screens you open?</th><td>An analytics provider</td><td><span class="yes">Nobody. There is no analytics.</span></td></tr>
          <tr><th scope="row">Can the policy change later?</th><td>Yes, and the data is already collected</td><td><span class="yes">It can change, but there is still nothing collected</span></td></tr>
        </tbody>
      </table>
    </div>
    <p>There is an honest cost to the right-hand column. If you lose the phone and have no backup, nobody can get your data back for you. That is the same property, seen from the other side.</p>
  </div>

  <div class="card">
    <h2 id="threat">{icon("hand", style="color:var(--amber)")}What this is really designed&nbsp;against
      <a class="anchor" href="#threat" aria-label="Link to this section">#</a></h2>
    <p>Most privacy pages talk about breaches and hackers. For an app like this, the realistic risk is closer to home: <strong>someone picking up your unlocked phone.</strong> A partner, a housemate, a family member, a colleague glancing at a notification.</p>
    <p>So the app has its own Face ID or PIN lock, on top of the phone's. Notifications can be worded so the lock screen says nothing revealing. One tap blanks the screen to a moon. And ChillMate hides what is on screen when you swap apps, and while your screen is being recorded or mirrored.</p>
    <p>Having no server has a useful side effect. If I were breached, nothing about you would come out, because I hold nothing. The trade is worth saying out loud: if you lose the phone and have no backup, the data is gone. That is deliberate, and it is why an encrypted backup is one setting away.</p>
  </div>

  <div class="card">
    <h2 id="history">{icon("doc", style="color:var(--primary)")}Every change this page has ever&nbsp;had
      <a class="anchor" href="#history" aria-label="Link to this section">#</a></h2>
    <p>A privacy policy is a promise that can be edited quietly, and almost nowhere lets you check whether it was. This one is in a public repository, so here is its whole history, read out of git when this page was built rather than typed in by hand.</p>
    <div class="table-scroll">
      <table>
        <caption>{len(HISTORY)} change{"" if len(HISTORY) == 1 else "s"} since this page first existed.</caption>
        <thead><tr><th scope="col">When</th><th scope="col">What changed</th><th scope="col">Commit</th></tr></thead>
        <tbody>
{history_rows}        </tbody>
      </table>
    </div>
    <p>Compare any two versions yourself in <a href="{REPO}/commits/main/docs/privacy/index.html">the file's history</a>.</p>
  </div>

  <div class="card">
    <h2 id="ifitchanged">{icon("hand", style="color:var(--amber)")}What it would take to start collecting your&nbsp;data
      <a class="anchor" href="#ifitchanged" aria-label="Link to this section">#</a></h2>
    <p>Worth being concrete, because "I will never" is easy to say. The version of that claim that means anything is about how the app is built, not about how good my intentions are.</p>
    <p>Collecting anything would take a lot. I would have to write a server and run it somewhere. I would have to add accounts, so records could be tied to people. I would have to add networking code to an app that has none. And all of it would go through App Review, with a privacy label that changed from nothing to something.</p>
    <p>It is not a setting somebody could flip, and it is not a line somebody could sneak in. It is a different app, built differently, and the first commit would be public on the day it was written.</p>
    <p>That is the actual protection. Not a promise about what I intend, but a shape that makes the other thing expensive and visible.</p>
  </div>

  <div class="card">
    <h2 id="saves">{icon("mail", style="color:var(--mint)")}What ChillMate can&nbsp;save</h2>
    <ul>
      <li>Your profile, photo, medication notes, trusted contact, home address, settings, and preferences.</li>
      <li>Private logs, sleep notes, health-related entries and test reminders, plans, journal entries, check-ins, and emergency-card details.</li>
      <li>Optional information you choose to add from Apple Health, Contacts, Photos, or Location Services.</li>
    </ul>
    <p>Some of the entries you choose to add are health-related and sensitive. They are stored only on your device, under your control.</p>
  </div>

  <div class="card">
    <h2 id="use">{icon("lock", style="color:var(--purple)")}How your information is&nbsp;used</h2>
    <ul>
      <li>To show your private overview, reminders, follow-ups, emergency shortcuts, and wellbeing reflections.</li>
      <li>To sync with Apple Health only for the categories you approve in iOS settings.</li>
      <li>To create encrypted backups only when you turn backup features on.</li>
    </ul>
    <p>All of this happens on your phone. ChillMate never sends what you write to me.</p>
  </div>

  <div class="card">
    <h2 id="never">{icon("hand", style="color:var(--pink)")}What ChillMate does&nbsp;not do</h2>
    <ul>
      <li>No ads, no selling personal information, and no sharing of your health details for marketing.</li>
      <li>No medical diagnosis, treatment decisions, or advice on whether anything is safe.</li>
      <li>No messages are sent to your contacts unless you choose to send them.</li>
    </ul>
  </div>

  <div class="card">
    <h2 id="where">{icon("cloud", style="color:var(--amber)")}Where your data is&nbsp;stored</h2>
    <p><strong>On your iPhone.</strong> Data is kept in the app's private storage, protected by iOS file protection and, if you enable it, an extra app lock (Face ID or PIN).</p>
    <p><strong>Optional iCloud.</strong> If you turn on iCloud backup or sync, ChillMate stores your data in <em>your own</em> private iCloud account through Apple's CloudKit and iCloud Drive. Apple encrypts it, and only you can reach it. I have no access to it at all.</p>
    <p><strong>No servers of mine.</strong> There is no ChillMate server anywhere that receives or stores your personal information.</p>
  </div>

  <div class="card">
    <h2 id="watch">{icon("watch", style="color:var(--mint)")}Apple&nbsp;Watch</h2>
    <p>If you pair an Apple Watch, ChillMate copies part of your data to it, so the watch still works when your phone is out of reach. That means your streak and daily score, any running dose timers, your watch settings, your emergency number, and the <strong>name and phone number of your trusted contact</strong>, so the watch can call them without your phone.</p>
    <p>This goes straight between your phone and your watch, on your own two devices. It does not pass through my servers, because there are none.</p>
    <p>Two things worth knowing. Your trusted contact's details belong to somebody else, and they end up on a second device, so only add someone who would be comfortable with that. And ChillMate's app lock protects the <em>phone</em> app. On the watch, your watch passcode and wrist detection do that job instead.</p>
    <p>Clearing your trusted contact in Settings, or unpairing the watch, removes this mirrored data.</p>
  </div>

  <div class="card">
    <h2 id="permissions">{icon("shield", style="color:var(--primary)")}Device&nbsp;permissions</h2>
    <p>Each permission is optional and only used for the purpose you grant it:</p>
    <ul>
      <li><strong>Apple Health.</strong> Read and write only the categories you allow (such as sleep, heart rate, HRV, and workouts).</li>
      <li><strong>Contacts.</strong> Only to let you pick a trusted contact. The lookup happens on your device.</li>
      <li><strong>Photos.</strong> Only to set a profile picture you choose.</li>
      <li><strong>Location.</strong> Only to attach a location to a log or include your current location in an emergency message you send.</li>
      <li><strong>Notifications.</strong> For the reminders and check-ins you turn on. Discreet wording can be enabled so lock-screen text stays vague.</li>
    </ul>
  </div>

  <div class="card">
    <h2 id="payments">{icon("tag", style="color:var(--mint)")}Payments and&nbsp;donations</h2>
    <p>ChillMate is free. If you choose to donate, that goes entirely through Apple's In-App Purchase. Apple takes the payment, and I never see your card or account details. Donations unlock nothing, and they change nothing about what data is collected.</p>
  </div>

  <div class="card">
    <h2 id="control">{icon("lock", style="color:var(--purple)")}Your control and&nbsp;deletion</h2>
    <ul>
      <li>You can delete logs, plans, reminders, timers, journal entries, and your whole account from inside the app.</li>
      <li>Deleting the app removes its local data from your iPhone. iCloud data can be removed from iCloud settings or from within the app's backup controls.</li>
      <li>iOS permission controls for Health, Location, Notifications, Contacts, and Photos remain available in the Settings app at any time.</li>
    </ul>
    <p>Because ChillMate does not collect your data on a server, there is no remote profile to ask for, correct, or erase. You already hold all of it. If you are in the EU or EEA, your GDPR rights (access, correction, erasure, portability, objection) are met directly by these controls on your phone.</p>
  </div>

  <div class="card">
    <h2 id="children">{icon("info", style="color:var(--pink)")}Children</h2>
    <p>ChillMate is intended for adults only. You must be 18 or older to create a profile and use the app.</p>
  </div>

  <div class="callout">
    {icon("alert")}
    <p>ChillMate is a wellbeing and reflection tool, not a medical service. It does not diagnose, treat, or tell you whether anything is safe. For any health, medication, or mental-health questions, speak with a qualified professional. If someone may be in immediate danger, call your local emergency number.</p>
  </div>

  <div class="card">
    <h2 id="changes">{icon("doc", style="color:var(--primary)")}Changes to this&nbsp;policy</h2>
    <p>If this policy changes, the updated version will be posted on this page with a new "last updated" date. Material changes will also be noted in the app or in the <a href="../changelog/">changelog</a>.</p>
    <p>There is a <a href="../nl/privacy/" hreflang="nl" lang="nl">Nederlandse vertaling</a>, because most of the people this app is for read Dutch first. This English text governs: if the two ever disagree, the English one is what was meant and the Dutch one has a bug. Only these two exist, because a translation is a promise to keep it in step, and two is what I can honestly keep.</p>
  </div>

  <div class="card">
    <h2 id="contact">{icon("mail", style="color:var(--mint)")}Contact</h2>
    <p>Questions about privacy? Email <a href="mailto:{EMAIL}">{EMAIL}</a>. For anything security-related, see the <a href="../security/">security page</a>.</p>
  </div>
"""
    out += footer(lang, depth)
    return out, canonical


def build_howto(lang):
    """The chapters the front page could not carry without repeating itself.

    Everything here was on the home page and earned its place, but the home
    page was saying the same four things in seven different chapters. This is
    the depth, given a page where it is the point rather than the padding.
    """
    s = C.STRINGS[lang]
    notes = Footnotes()
    fn = notes.cite
    depth = 1 if lang == "en" else 2
    r = rel(depth)
    canonical = page_urls("howto")[lang]
    home = r if lang == "en" else ("../" * (depth - 1) if depth > 1 else "./")

    out = head(lang, s["howto_title"], s["howto_desc"], canonical, depth, "howto",
               body_class="exhibition no-hero")
    out += header(lang, depth, "howto", "howto")

    links = "".join(
        f'        <a href="#{ident}">{e(label)}</a>\n'
        for ident, label in [("night", s["night_eyebrow"]), ("refuse", s["refuse_eyebrow"]),
                             ("foryou", s["foryou_eyebrow"]), ("features", s["features_eyebrow"]),
                             ("watch", "Apple Watch")]
    )
    out += f"""
  <nav class="subnav" data-subnav aria-label="{e(s["howto_h1"])}">
    <div class="inner">
      <span class="title">{e(s["howto_h1"])}</span>
{links}      <a class="btn btn-primary" href="{home}">{e(s["howto_back"])}</a>
    </div>
  </nav>
"""

    # ---- the shape of a night
    beats = ""
    for label, title, body in s["night"]:
        beats += f"""        <div class="beat">
          <p class="eyebrow">{e(label)}</p>
          <h3>{e(no_orphan(title))}</h3>
          <p>{t(body)}</p>
        </div>
"""
    out += chapter(f"""      <h1>{e(no_orphan(s["howto_h1"]))}</h1>
      <p class="lede">{t(s["howto_lede"])}</p>

      <p class="eyebrow" style="margin-top:clamp(44px,6vw,84px)">{e(s["night_eyebrow"])}</p>
      <h2>{e(no_orphan(s["night_h2"]))}</h2>
      <div class="beats stagger">
{beats}      </div>
""", ident="night")

    # ---- what it refuses to do
    refusals = "".join(
        f'          <li>{icon("hand")}<div><b>{t(title)}</b><span>{t(body)}</span></div></li>\n'
        for title, body in s["refuse"]
    )
    out += chapter(f"""      <p class="eyebrow">{e(s["refuse_eyebrow"])}</p>
      <h2>{e(no_orphan(s["refuse_h2"]))}</h2>
      <p>{t(s["refuse_p"])}</p>
      <ul class="refusals stagger">
{refusals}      </ul>
      <p class="meta">{t(s["footnotes_intro"])}{fn("network")}{fn("cloudkit")}</p>
""", ident="refuse", invert=True)

    # ---- is this for you
    scenarios = "".join(
        f'          <li>{icon("check")}<span>{t(line)}</span></li>\n' for line in s["foryou"]
    )
    out += chapter(f"""      <p class="eyebrow">{e(s["foryou_eyebrow"])}</p>
      <h2>{e(no_orphan(s["foryou_h2"]))}</h2>
      <ul class="scenarios stagger">
{scenarios}      </ul>
      <p>{t(s["foryou_not"])}</p>
""", ident="foryou")

    # ---- everything that is in it
    tiles = ""
    for ico, tint, title, body in s["features"]:
        tiles += f"""        <div class="feature">
          <div class="chip {tint}">{icon(ico)}</div>
          <h3>{e(no_orphan(title))}</h3>
          <p>{t(body)}</p>
        </div>
"""
    out += chapter(f"""      <p class="eyebrow">{e(s["features_eyebrow"])}</p>
      <div class="grid three stagger">
{tiles}      </div>
""", ident="features", invert=True)

    # ---- the watch, and the languages
    out += chapter(f"""      <div class="hero-cols" style="margin-top:0">
          <div>
            <p class="eyebrow">Apple Watch</p>
            <h2>{e(no_orphan(s["watch_h3"]))}</h2>
            <p>{t(s["watch_p"])}{fn("switcher")}</p>
          </div>
          <div>{watch(depth)}</div>
      </div>

      <h3 style="margin-top:clamp(48px,6vw,86px)">{e(no_orphan(s["proof_h2"]))}</h3>
      <p>{t(s["proof_p"])}</p>
      <p>{s["proof_fact"]}{fn("network")}</p>
      <div class="cta-row">
        <a class="btn btn-ghost" href="{REPO}">{icon("github")}{e(s["proof_cta_repo"])}</a>
        <a class="btn btn-ghost" href="{r}privacy/">{icon("shield")}{e(s["privacy_link"])}</a>
      </div>
      <p class="meta" style="margin-top:14px">{e(s["proof_caption"])}</p>

      <h3 style="margin-top:clamp(48px,6vw,86px)">{e(no_orphan(s["langs_h3"]))}</h3>
      <p>{t(s["langs_p"])}</p>

      <div class="cta-row" style="margin-top:clamp(40px,5vw,72px)">
        <a class="btn btn-ghost" href="{home}">{icon("chev")}{e(s["howto_back"])}</a>
      </div>

      <div class="footnotes" style="margin-top:clamp(40px,5vw,72px)">
        <p class="eyebrow">{e(s["footnotes_title"])}</p>
        <ol>
{notes.render(s)}        </ol>
      </div>
""", ident="watch")

    out += footer(lang, depth)
    return out, canonical


def build_privacy_nl():
    """The Dutch policy. Same ids as the English one, so anchors line up."""
    lang, depth = "nl", 2
    canonical = BASE_PATH + "nl/privacy/"
    P = privacy_nl

    out = head(lang, P.TITLE, P.DESC, canonical, depth, "privacy")
    out += header(lang, depth, "privacy", "privacy")
    out += f"""
  <h1>{e(no_orphan(P.H1))}</h1>
  <p class="lede">{e(P.LEDE)}</p>
  <p class="meta">{e(P.META.format(updated=UPDATED))}</p>

  <div class="callout calm" role="note">
    {icon("info")}
    <p><strong>{e(P.GOVERNS_TITLE)}.</strong> {P.GOVERNS_BODY}</p>
  </div>
"""
    for anchor, ico, colour, heading, body in P.SECTIONS:
        filled = body.format(version=VERSION, build=BUILD, repo=REPO, email=EMAIL)
        out += f"""
  <div class="card">
    <h2 id="{anchor}">{icon(ico, style=f"color:{colour}")}{e(no_orphan(heading))}
      <a class="anchor" href="#{anchor}" aria-label="Link naar dit onderdeel">#</a></h2>
{filled}  </div>
"""
    out += f"""
  <div class="callout">
    {icon("alert")}
    <p>{e(C.STRINGS["nl"]["disclaimer"])}</p>
  </div>
"""
    out += footer(lang, depth)
    return out, canonical


RELEASES = [
    ("4.2.1", "422", "2026-08-11", "August 2026", "Fixes, and one that mattered", [
        "Fixed a crash on opening the app after upgrading from 4.2.0, caused by two schema versions sharing a checksum.",
        "Choosing a language inside the app no longer drops your region, so dates, numbers and 24-hour time stay right.",
        "Translated the last untranslated strings, including every combination-checker warning, in all five languages.",
        "Accessibility fixes: high contrast now reaches card surfaces, the one-handed layout toggle does something again, and reduced motion is honoured in more places.",
        "Continuous integration runs and passes for the first time.",
    ]),
    ("4.1.0", "410", "2026-07-14", "July 2026", "A home that knows the moment", [
        "Redesigned home: tools grouped into four moments, before you go, while you are out, aftercare and health, and your patterns.",
        "It arranges itself. When a dose timer is running, or it is the morning after, the tool you need rises to the top.",
        "Get help now is pinned to the top, so breathing, grounding and emergency calls are never something to hunt for.",
        "Three calm tabs: Home, History and More. Calendar and journal now live together under History.",
        "Optional weekend night check-ins on Friday and Saturday, with one-tap I am safe or Get help.",
        "Choose exactly which reminders you want during setup.",
    ]),
    ("4.0.0", "400", "2026-06-24", "June 2026", "The Apple Watch update", [
        "All-new Apple Watch app: streak, live dose timers, hydration, discreet check-ins and a breathing exercise.",
        "Safety screen on the watch: call your trusted contact or emergency services in one tap.",
        "Watch face complications and Smart Stack support.",
        "Support directory now also covers the United States, Ireland and Australia, with the right emergency number everywhere in the app.",
        "ChillMate hides its contents in the App Switcher and while your screen is recorded or mirrored.",
        "Insights: a five-week overview map, your personal best streak, and how you sleep after clear nights, over 30 or 90 days.",
        "Aftercare mood can sync to Apple Health's State of Mind, and sleep fills in automatically.",
        "Export your private summary as a PDF for a doctor's visit.",
        "The watch app speaks Dutch, German, French and Spanish.",
    ]),
]


def combination_table(lang):
    """The 30 documented combinations, rendered as HTML rather than hidden in JSON.

    The checker page carried 196 visible words and kept every warning inside a
    `<script type="application/json">` blob. That is invisible to a crawler and
    to anyone with JavaScript off, which means the single most useful thing on
    this site could not be found by somebody searching for exactly it. A person
    typing "GHB and alcohol" into a search engine at two in the morning is the
    reader this whole project is for.

    So the table is static, sorted worst first, and the demo above it is the
    progressive enhancement rather than the only way in.
    """
    raw = json.loads((Path(__file__).resolve().parent / "interactions.json")
                     .read_text(encoding="utf-8"))
    s = C.STRINGS[lang]
    order = {"critical": 0, "serious": 1, "caution": 2}
    rules = sorted(raw["rules"], key=lambda r: (order.get(r["level"], 9),
                                                r["substances"]))
    rows = ""
    for rule in rules:
        pair = " + ".join(rule["substances"])
        level = raw["levels"][rule["level"]][lang]
        rows += (f'          <tr>\n'
                 f'            <th scope="row">{e(pair)}</th>\n'
                 f'            <td><span class="pill pill--{rule["level"]}">{e(level)}</span></td>\n'
                 f'            <td>{e(rule["warning"][lang])}</td>\n'
                 f'          </tr>\n')

    groups = "".join(
        f'          <li><b>{e(group["label"][lang])}</b> '
        f'<span>{e(", ".join(group["aliases"][:6]))}</span></li>\n'
        for group in raw["medication"]
    )
    return f"""      <h2 id="combinations">{e(no_orphan(s["combos_h2"]))}</h2>
      <p>{t(s["demo_note"])}</p>
      <div class="table-scroll">
        <table class="combos">
          <caption>{e(s["proof_caption"])}</caption>
          <thead>
            <tr><th scope="col">{e(s["demo_pick"])}</th>
                <th scope="col">{e(s["demo_assess_label"])}</th>
                <th scope="col">{e(s["demo_h2"].rstrip("."))}</th></tr>
          </thead>
          <tbody>
{rows}          </tbody>
        </table>
      </div>

      <h2 id="medication" style="margin-top:clamp(40px,5vw,72px)">{e(no_orphan(s["combos_meds_h2"]))}</h2>
      <ul class="med-groups">
{groups}      </ul>
"""


def build_checker(lang):
    """The risk checker on a URL of its own.

    It is the strongest thing on the site and it was buried as the fourth
    chapter of a long page, which meant it could not be linked to, shared, or
    indexed as the thing it is. Somebody who wants to know whether two things
    mix should be able to arrive at exactly that and nothing else.
    """
    s = C.STRINGS[lang]
    depth = 1 if lang == "en" else 2
    r = rel(depth)
    canonical = page_urls("checker")[lang]
    home = r if lang == "en" else ("../" * (depth - 1) if depth > 1 else "./")
    title = f'ChillMate · {s["demo_h2"].rstrip(".")}'

    out = head(lang, title, s["demo_p"], canonical, depth, "checker",
               body_class="exhibition no-hero")
    out += header(lang, depth, "", "checker")
    out += chapter(f"""      <p class="eyebrow">{e(s["demo_eyebrow"])}</p>
      <h1>{e(no_orphan(s["demo_h2"]))}</h1>
      <p class="lede">{t(s["demo_p"])}</p>
{demo_body(lang, depth)}
      <div class="callout" style="margin-top:clamp(34px,4vw,60px)">
        {icon("alert")}
        <p>{t(s["disclaimer"])}</p>
      </div>

{combination_table(lang)}
      <div class="cta-row" style="margin-top:clamp(28px,3vw,44px)">
        <a class="btn btn-ghost" href="{home}">{icon("chev")}{e(s["howto_back"])}</a>
      </div>
""", ident="checker")
    out += footer(lang, depth)
    return out, canonical


def build_changelog():
    lang, depth = "en", 1
    canonical = BASE_PATH + "changelog/"
    title = "ChillMate · Changelog"
    desc = "What changed in each release of ChillMate."

    out = head(lang, title, desc, canonical, depth)
    out += header(lang, depth, "")
    out += """
  <h1>What&nbsp;changed</h1>
  <p class="lede">Every release, in the order it shipped. The full release notes for each version, in all five languages, live in the repository.</p>
"""
    for version, build, iso, when, headline, items in RELEASES:
        bullets = "".join(f"        <li>{i}</li>\n" for i in items)
        out += f"""
  <div class="card">
    <h2 id="v{version.replace('.', '-')}">{icon("tag", style="color:var(--primary)")}{version} · {headline}
      <a class="anchor" href="#v{version.replace('.', '-')}" aria-label="Link to {version}">#</a></h2>
    <p class="meta">Build {build} · {when}</p>
    <ul>
{bullets}    </ul>
  </div>
"""
    out += f"""
  <div class="card">
    <h2>{icon("github", style="color:var(--mint)")}Everything&nbsp;else</h2>
    <p>Earlier versions, and the per-language release notes, are in <a href="{REPO}/tree/main/Marketing">the Marketing folder</a> of the repository.</p>
    <p>Prefer not to check back? <a href="feed.xml">Subscribe to the feed</a>. It is a plain Atom file, it asks for no address, and I never learn that you are reading it.</p>
  </div>
"""
    out += footer(lang, depth)
    return out, canonical


def build_feed():
    """An Atom feed for the changelog.

    A free app with no account has no way to tell you it changed, and an email
    list would mean holding addresses, which is the one thing this whole project
    is arranged not to do. A feed costs nothing and asks for nothing.
    """
    entries = ""
    for version, build, iso, when, headline, items in RELEASES:
        summary = " ".join(re.sub(r"<[^>]+>", "", i) for i in items)
        entries += f"""  <entry>
    <title>ChillMate {version}: {e(headline)}</title>
    <link href="{BASE_URL}changelog/#v{version.replace('.', '-')}" />
    <id>tag:thijsverstapen.github.io,{iso}:chillmate-{version}</id>
    <updated>{iso}T12:00:00Z</updated>
    <summary>{e(summary)}</summary>
  </entry>
"""
    latest = RELEASES[0][2]
    return f"""<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>ChillMate releases</title>
  <subtitle>What changed in each release of ChillMate.</subtitle>
  <link href="{BASE_URL}changelog/feed.xml" rel="self" />
  <link href="{BASE_URL}changelog/" />
  <id>{BASE_URL}changelog/</id>
  <updated>{latest}T12:00:00Z</updated>
  <author><name>Thijs Verstappen</name></author>
{entries}</feed>
"""


def build_press():
    lang, depth = "en", 1
    canonical = BASE_PATH + "press/"
    title = "ChillMate · Press kit"
    desc = "Icon, screenshots, boilerplate and facts about ChillMate, free to use."

    out = head(lang, title, desc, canonical, depth)
    out += header(lang, depth, "")
    shots = "".join(
        f'      <a class="res" href="../assets/shots/{name}"><div class="t">{label}{icon("ext")}</div>'
        f'<div class="d">PNG</div></a>\n'
        for name, label in [("home.jpg", "Home"), ("risk.jpg", "Risk checker"),
                            ("help.jpg", "Panic support"), ("support.jpg", "Support"),
                            ("privacy.jpg", "Privacy dashboard"), ("watch.png", "Apple Watch")]
    )
    out += f"""
  <h1>Press&nbsp;kit</h1>
  <p class="lede">Everything here can be used freely to write about ChillMate. If you need something that is not here, ask and it will be made.</p>

  <div class="card">
    <h2 id="download">{icon("doc", style="color:var(--primary)")}Download&nbsp;everything
      <a class="anchor" href="#download" aria-label="Link to this section">#</a></h2>
    <p>Icon, all five screenshots, the share image and the boilerplate text, in one archive.</p>
    <div class="contact-row">
      <a class="btn btn-primary" href="chillmate-press-kit.zip" download>{icon("doc")}Press kit (.zip)</a>
    </div>
  </div>

  <div class="card">
    <h2 id="facts">{icon("info", style="color:var(--mint)")}The&nbsp;facts</h2>
    <div class="table-scroll">
      <table>
        <tbody>
          <tr><th scope="row">Name</th><td>ChillMate</td></tr>
          <tr><th scope="row">What it is</th><td>A private wellbeing, safety and reflection app for iPhone and Apple Watch</td></tr>
          <tr><th scope="row">Price</th><td>Free. No ads, no subscription, no paid tier. You can donate if you want to, which unlocks nothing.</td></tr>
          <tr><th scope="row">Platform</th><td>iOS 26 and later, with a native Apple Watch app</td></tr>
          <tr><th scope="row">Version</th><td>{VERSION} (build {BUILD})</td></tr>
          <tr><th scope="row">Languages</th><td>English, Dutch, German, French, Spanish</td></tr>
          <tr><th scope="row">Data collected</th><td>None. There is no server and no account.</td></tr>
          <tr><th scope="row">Source</th><td><a href="{REPO}">Open source on GitHub</a></td></tr>
          <tr><th scope="row">Made by</th><td>One developer, in the Netherlands</td></tr>
          <tr><th scope="row">Contact</th><td><a href="mailto:{EMAIL}">{EMAIL}</a></td></tr>
        </tbody>
      </table>
    </div>
  </div>

  <div class="card">
    <h2 id="boilerplate">{icon("doc", style="color:var(--purple)")}Boilerplate</h2>
    <p><strong>One line.</strong> ChillMate is a calm, private place to look after yourself, with everything kept on your own iPhone.</p>
    <p><strong>One paragraph.</strong> ChillMate keeps your logs, reflections, plans, reminders and personal-safety tools in one private overview on your iPhone and Apple Watch. It has no account, no server and no trackers, so nothing about you is held anywhere you cannot reach. Alongside the private log there are breathing and grounding tools, a risk checker for combinations, discreet check-in timers, and a safe route home. It also carries a directory of real crisis and health services for your country, which works with no signal. It is free, open source, and made by one developer in the Netherlands.</p>
  </div>

  <div class="card">
    <h2 id="assets">{icon("tag", style="color:var(--pink)")}Individual&nbsp;assets</h2>
    <div class="grid two">
      <a class="res" href="../assets/icon-512.png"><div class="t">App icon{icon("ext")}</div><div class="d">PNG, 512 &times; 512</div></a>
      <a class="res" href="../assets/og.png"><div class="t">Share image{icon("ext")}</div><div class="d">PNG, 1200 &times; 630</div></a>
{shots}    </div>
  </div>

  <div class="callout">
    {icon("alert")}
    <p>Please do not describe ChillMate as medical software, a diagnostic tool, or a crisis service. It supports reflection and planning, and it points to real services rather than replacing them.</p>
  </div>
"""
    out += footer(lang, depth)
    return out, canonical


def build_security():
    lang, depth = "en", 1
    canonical = BASE_PATH + "security/"
    title = "ChillMate · Security"
    desc = "How to report a security problem in ChillMate, and what the app is designed to withstand."

    out = head(lang, title, desc, canonical, depth)
    out += header(lang, depth, "")
    out += f"""
  <h1>Security</h1>
  <p class="lede">If you have found something, tell me. There is no bounty programme and no legal team, just an address that a person reads.</p>

  <div class="card">
    <h2 id="report">{icon("mail", style="color:var(--primary)")}Reporting a&nbsp;problem
      <a class="anchor" href="#report" aria-label="Link to this section">#</a></h2>
    <p>Email <a href="mailto:{EMAIL}">{EMAIL}</a> with "security" in the subject. Include what you did, what happened, and the version you were on. A rough proof of concept helps more than a scanner report.</p>
    <p>You will get an acknowledgement, a fix if the finding stands, and credit in the <a href="../changelog/">changelog</a> if you want it. Please give it a reasonable window before publishing, and do not test against anyone else's device or data.</p>
    <p class="meta">Machine-readable version: <a href="{BASE_PATH}.well-known/security.txt"><code>/.well-known/security.txt</code></a></p>
  </div>

  <div class="card">
    <h2 id="surface">{icon("shield", style="color:var(--mint)")}What the attack surface actually&nbsp;is
      <a class="anchor" href="#surface" aria-label="Link to this section">#</a></h2>
    <p>Most of the usual answers do not apply here, which is worth stating plainly rather than claiming as a virtue.</p>
    <ul>
      <li><strong>No server.</strong> There is no API, no database and no admin panel to attack, because none exist.</li>
      <li><strong>No accounts.</strong> No password reset flow, no session tokens, no account takeover.</li>
      <li><strong>No third-party SDKs</strong> receiving your data, so no supply chain of analytics vendors.</li>
      <li><strong>Sync is Apple's.</strong> iCloud sync and iCloud Drive backups run in your own account under Apple's encryption.</li>
    </ul>
    <p>Here is what is left, and what is genuinely worth probing. The app lock, meaning the PBKDF2-derived PIN held in the Keychain plus Face ID. The encrypted backup format. The phone to watch mirror. What the widgets and Live Activity show on a locked screen. And whether the discreet notification wording ever leaks something it should not.</p>
  </div>

  <div class="card">
    <h2 id="compelled">{icon("hand", style="color:var(--amber)")}If I were compelled to hand something&nbsp;over
      <a class="anchor" href="#compelled" aria-label="Link to this section">#</a></h2>
    <p>Almost nobody puts this in writing, so here it is. If a court, a police force or any other authority ordered me to produce a user's data, <strong>I would have nothing to produce.</strong> Not because I would refuse, but because there is no copy: no server, no account, no database, no logs tying a person to anything.</p>
    <p>What I could be compelled to do is change the app, so that future versions collect something. That would be a public commit in a public repository. It would go through App Review, with a privacy label that changed from nothing to something. And it could not reach backwards to data that was never taken. If you ever see that commit with no explanation next to it, something has gone wrong, and you should stop trusting this page.</p>
    <p>I have received no such order. If that sentence ever disappears from this page, take it seriously.</p>
  </div>

  <div class="card">
    <h2 id="audit">{icon("check", style="color:var(--mint)")}An open invitation to audit&nbsp;it
      <a class="anchor" href="#audit" aria-label="Link to this section">#</a></h2>
    <p>I would rather be told I am wrong than be believed by default. If you work in security, harm reduction or digital rights and want to look properly, this is the scope that would help most.</p>
    <ul>
      <li>Whether the app really makes no network calls, on device, under instrumentation rather than by reading the source.</li>
      <li>The PIN derivation and Keychain handling, and whether the legacy migration path leaks anything.</li>
      <li>The encrypted backup format, and whether a backup file discloses anything without the key.</li>
      <li>What the widgets, complications and Live Activity expose on a locked screen.</li>
      <li>Whether discreet notification wording ever leaks a category it should not.</li>
    </ul>
    <p>Email <a href="mailto:{EMAIL}">{EMAIL}</a>. I cannot pay, I can give you a build, answer questions quickly, and publish what you find whether or not it is flattering.</p>
  </div>

  <div class="card">
    <h2 id="analytics">{icon("chart", style="color:var(--primary)")}How I know whether this site&nbsp;works
      <a class="anchor" href="#analytics" aria-label="Link to this section">#</a></h2>
    <p>I do not, mostly, and that is a deliberate trade. This site runs no analytics, sets no cookies, and loads nothing from a third party, so there is no dashboard telling me which chapter people stop reading.</p>
    <p>What exists is whatever GitHub records when it serves the files, which I do not control and do not process. It is a real cost: I am designing partly in the dark. It is still the right trade for a site whose readers may not want a record of having visited a page about chemsex safety.</p>
  </div>

  <div class="card">
    <h2 id="scope">{icon("info", style="color:var(--purple)")}Out of&nbsp;scope</h2>
    <ul>
      <li>Issues in iOS, iCloud, or Apple's frameworks. Report those to Apple.</li>
      <li>Findings that need an already-unlocked, already-jailbroken device.</li>
      <li>Missing hardening headers on this static site with no login and no forms.</li>
      <li>Reports generated wholesale by an automated scanner with no verification.</li>
    </ul>
  </div>
"""
    out += footer(lang, depth)
    return out, canonical


def build_404():
    lang = "en"
    a = BASE_PATH + "assets/"
    return f"""<!DOCTYPE html>
<html lang="en" data-sw-scope="{BASE_PATH}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ChillMate · Page not found</title>
  <meta name="description" content="That page is not here. The things people usually want are." />
  <meta name="robots" content="noindex" />
  <meta name="theme-color" content="#0e1430" />
  <meta name="referrer" content="strict-origin-when-cross-origin" />
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; font-src 'self'; connect-src 'self'; form-action 'none'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'" />
  <link rel="icon" href="{a}mark.svg" type="image/svg+xml" />
  <link rel="apple-touch-icon" href="{a}icon-180.png" />
{JS_BOOT}
  <style>{CRITICAL_CSS}</style>
  <link rel="stylesheet" href="{a}{ASSET["style.css"]}" />
</head>
<body>
{SPRITE}
<main class="wrap" id="main">
  <header class="site-head">
    <a class="brand" href="{BASE_PATH}" aria-label="ChillMate">
      <svg class="mark draw" aria-hidden="true"><use href="#i-mark"/></svg>
      <span class="name">Chill<em>Mate</em></span>
    </a>
  </header>

  <h1>That page is not&nbsp;here.</h1>
  <p class="lede">Which is annoying if you were looking for something specific. These are the pages people usually want.</p>

  <div class="grid two" style="margin-top:26px">
    <a class="res" href="{BASE_PATH}"><div class="t">{icon("mark", cls="icon")}Home</div><div class="d">What ChillMate is, and what it looks like.</div></a>
    <a class="res" href="{BASE_PATH}support/"><div class="t">{icon("life")}Support and help</div><div class="d">Crisis lines and health services for your country, plus common questions.</div></a>
    <a class="res" href="{BASE_PATH}privacy/"><div class="t">{icon("shield")}Privacy policy</div><div class="d">Every connection the app makes, listed.</div></a>
    <a class="res" href="{BASE_PATH}changelog/"><div class="t">{icon("tag")}Changelog</div><div class="d">What shipped, and when.</div></a>
    <a class="res" href="{REPO}"><div class="t">{icon("github")}Source code</div><div class="d">The whole app, in public.</div></a>
  </div>

  <div class="callout urgent" style="margin-top:30px">
    {icon("alert")}
    <p><strong>If this is urgent, do not keep browsing.</strong> Call your local emergency number, or open <a href="{BASE_PATH}support/#services">the list of real services</a>.</p>
  </div>

  <footer>
    <a href="{BASE_PATH}">Home</a>
    <span class="sep" aria-hidden="true">·</span>
    <a href="mailto:{EMAIL}">{EMAIL}</a>
    <span class="made">ChillMate {VERSION}</span>
  </footer>
</main>
<script src="{a}{ASSET["site.js"]}" defer></script>
</body>
</html>
"""


# --------------------------------------------------------------------------
# non-HTML files
# --------------------------------------------------------------------------

def service_worker() -> str:
    """The caching layer, since there will not be a CDN in front of this.

    GitHub Pages sends `Cache-Control: max-age=600` on everything and offers no
    way to change it, so ten minutes after a visit the browser starts asking for
    every file again. Without a CDN to override that, the service worker is the
    only place the caching can happen.

    So it splits the difference by URL rather than treating everything alike:

      * Fingerprinted assets are cache-first and never revalidated. The hash is
        in the filename, so if the bytes change the URL changes, and a stale
        answer is impossible by construction.
      * Pages are network-first, because a page has no hash and its content is
        the thing most likely to be wrong if it is stale.
      * Anything that fails falls back to the cache, and a failed page request
        falls back to the support page, which is the one worth reaching when the
        network is gone.
    """
    return f"""/* Built by tools/build_site.py. Do not edit here.

   The crisis numbers on the support page are needed exactly when a network is
   least dependable, so that page is precached on first visit. */

const CACHE = 'chillmate-{VERSION}-{BUILD}-{ASSET["style.css"].split('.')[1]}';
const CORE = [
  '{BASE_PATH}',
  '{BASE_PATH}support/',
  '{BASE_PATH}risk-checker/',
  '{BASE_PATH}assets/{ASSET["style.css"]}',
  '{BASE_PATH}assets/{ASSET["chapters.css"]}',
  '{BASE_PATH}assets/{ASSET["site.js"]}',
  '{BASE_PATH}assets/mark.svg',
];

/* A fingerprinted name carries an eight-character hex digest, so its contents
   can never change under the same URL. Those are safe to serve from the cache
   without asking. */
// Anything with a content hash in its name can never change under that name,
// so it is safe to serve from the cache forever. `svg` is on the list for the
// App Store badges; the unhashed `mark.svg` does not match this and keeps
// going through the normal path.
const IMMUTABLE = /\.[0-9a-f]{{8}}\.(css|js|avif|jpg|png|svg|woff2)$/;

self.addEventListener('install', (event) => {{
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(CORE))
      .then(() => self.skipWaiting())
  );
}});

self.addEventListener('activate', (event) => {{
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
}});

self.addEventListener('fetch', (event) => {{
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (IMMUTABLE.test(url.pathname)) {{
    event.respondWith(
      caches.match(event.request).then((hit) => hit || fetch(event.request).then((response) => {{
        if (response && response.status === 200) {{
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(event.request, copy));
        }}
        return response;
      }}))
    );
    return;
  }}

  event.respondWith(
    fetch(event.request)
      .then((response) => {{
        if (response && response.status === 200 && response.type === 'basic') {{
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(event.request, copy));
        }}
        return response;
      }})
      .catch(() => caches.match(event.request)
        .then((hit) => hit || caches.match('{BASE_PATH}support/')))
  );
}});
"""

MANIFEST = {
    "name": "ChillMate",
    "short_name": "ChillMate",
    "description": "A calm, private place to look after yourself.",
    "start_url": BASE_PATH,
    "scope": BASE_PATH,
    "display": "standalone",
    "background_color": "#0b1022",
    "theme_color": "#0e1430",
    "icons": [
        {"src": BASE_PATH + "assets/icon-192.png", "sizes": "192x192", "type": "image/png"},
        {"src": BASE_PATH + "assets/icon-512.png", "sizes": "512x512", "type": "image/png"},
        {"src": BASE_PATH + "assets/icon-512.png", "sizes": "512x512", "type": "image/png",
         "purpose": "maskable"},
    ],
}

SECURITY_TXT = f"""Contact: mailto:{EMAIL}
Expires: 2027-08-11T00:00:00.000Z
Preferred-Languages: en, nl
Canonical: {BASE_URL}.well-known/security.txt
Policy: {BASE_URL}security/
"""

ROBOTS = f"""User-agent: *
Allow: /

Sitemap: {BASE_URL}sitemap.xml
"""

# Google Search Console proves you own a site by asking for a file back at a
# path only its owner could put something at. The name and the one line inside
# both have to match what Google issued, byte for byte, so this is a verbatim
# copy and not a template: no trailing newline, nothing interpolated.
#
# It lives here rather than being dropped into docs/ by hand because main()
# clears everything in docs/ except assets/ on every run, so a hand-placed file
# survives exactly until the next build and then verification quietly lapses.
#
# This verifies the URL-prefix property for BASE_URL only. github.io is a
# shared host and the domain-level property would need a file at the host root,
# which belongs to a different repository.
GOOGLE_VERIFY_FILE = "googlee86e55f3d19408b6.html"
GOOGLE_VERIFY_BODY = "google-site-verification: googlee86e55f3d19408b6.html"


def structured_data():
    return {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "ChillMate",
        "applicationCategory": "HealthApplication",
        "operatingSystem": "iOS 26, watchOS",
        "softwareVersion": VERSION,
        "url": BASE_URL,
        # `url` is where you read about it, `installUrl` is where you get it.
        # Search engines treat those as different questions and it is the second
        # one a person is asking by the time they see this.
        "installUrl": APP_STORE_URL,
        "downloadUrl": APP_STORE_URL,
        "description": C.STRINGS["en"]["home_desc"],
        "inLanguage": [C.LANG_TAGS[l] for l in C.LANGS],
        "isAccessibleForFree": True,
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "EUR",
                   "url": APP_STORE_URL, "availability": "https://schema.org/InStock"},
        "author": {"@type": "Person", "name": "Thijs Verstappen"},
        "image": BASE_URL + "assets/og.png",
        "privacyPolicy": BASE_URL + "privacy/",
    }


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def main():
    urls = []

    # Rebuild the fingerprint map first, and sweep away the previous build's
    # hashed copies so they do not accumulate one file per edit forever.
    for stale in (list(ASSETS.glob("*.*.*"))
                  + list((ASSETS / "shots").glob("*.*.*"))
                  + list((ASSETS / "badges").glob("*.*.*"))):
        if re.fullmatch(r".+\.[0-9a-f]{8}\.(css|js|avif|jpg|png|svg)", stale.name):
            stale.unlink()
    ASSET.update(asset_map())

    # Read everything that comes out of git BEFORE touching docs/.
    #
    # These used to run inside build_privacy(), which happens after the wipe
    # below. Deleting several hundred files at once makes the sync daemon on
    # this directory thrash, and git calls made during that storm were timing
    # out at twenty seconds while the same command takes twenty milliseconds on
    # a quiet tree. The result was a privacy page whose history table silently
    # collapsed to nothing. Nothing here depends on the build output, so there
    # is no reason to ask git anything after the wipe.
    policy_history()
    source_checksum()

    # Wipe generated output, keeping the hand-authored assets folder.
    for child in DOCS.iterdir():
        if child.name == "assets":
            continue
        shutil.rmtree(child) if child.is_dir() else child.unlink()

    ld = ('\n  <script type="application/ld+json">'
          + json.dumps(structured_data(), ensure_ascii=False) + "</script>")

    for lang in C.LANGS:
        body, canonical = build_home(lang)
        if lang == "en":
            body = body.replace("</head>", ld + "\n</head>", 1)
        target = DOCS / "index.html" if lang == "en" else DOCS / lang / "index.html"
        write(target, body)
        urls.append((canonical, "1.0"))

        body, canonical = build_howto(lang)
        target = (DOCS / "how-it-works" / "index.html" if lang == "en"
                  else DOCS / lang / "how-it-works" / "index.html")
        write(target, body)
        urls.append((canonical, "0.8"))

        body, canonical = build_checker(lang)
        target = (DOCS / "risk-checker" / "index.html" if lang == "en"
                  else DOCS / lang / "risk-checker" / "index.html")
        write(target, body)
        urls.append((canonical, "0.9"))

        body, canonical = build_support(lang)
        target = DOCS / "support" / "index.html" if lang == "en" else DOCS / lang / "support" / "index.html"
        write(target, body)
        urls.append((canonical, "0.9"))

    body, canonical = build_privacy_nl()
    write(DOCS / "nl" / "privacy" / "index.html", body)
    urls.append((canonical, "0.7"))

    for builder, folder in [(build_privacy, "privacy"),
                            (build_changelog, "changelog"), (build_press, "press"),
                            (build_security, "security")]:
        body, canonical = builder()
        write(DOCS / folder / "index.html", body)
        urls.append((canonical, "0.7"))

    write(DOCS / "changelog" / "feed.xml", build_feed())
    write(DOCS / "404.html", build_404())
    write(DOCS / "robots.txt", ROBOTS)
    write(DOCS / GOOGLE_VERIFY_FILE, GOOGLE_VERIFY_BODY)
    write(DOCS / "sw.js", service_worker())
    write(DOCS / "manifest.webmanifest", json.dumps(MANIFEST, indent=2, ensure_ascii=False) + "\n")
    write(DOCS / ".well-known" / "security.txt", SECURITY_TXT)

    # GitHub Pages otherwise hands docs/ to Jekyll, which ignores files and
    # folders beginning with a dot. That would silently drop /.well-known/.
    write(DOCS / ".nojekyll", "")

    entries = "".join(
        f"  <url><loc>{SITE_ORIGIN}{path}</loc><lastmod>{UPDATED}</lastmod>"
        f"<priority>{priority}</priority></url>\n"
        for path, priority in urls
    )
    write(DOCS / "sitemap.xml",
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
          + entries + "</urlset>\n")

    # Press kit
    kit = DOCS / "press" / "chillmate-press-kit.zip"
    kit.parent.mkdir(parents=True, exist_ok=True)
    boiler = (
        "ChillMate press kit\n"
        f"Version {VERSION} (build {BUILD})\n\n"
        "One line\n"
        "ChillMate is a calm, private place to look after yourself, with everything kept on your own iPhone.\n\n"
        "One paragraph\n"
        "ChillMate keeps your logs, reflections, plans, reminders and personal-safety tools in one private "
        "overview on your iPhone and Apple Watch. It has no account, no server and no trackers, so nothing "
        "about you is held anywhere you cannot reach. Alongside the private log there are breathing and "
        "grounding tools, a risk checker for combinations, discreet check-in timers, and a safe route "
        "home. It also carries a directory of real crisis and health services for your country, which "
        "works with no signal. It is free, open source, and made by one developer in the Netherlands.\n\n"
        f"Site: {BASE_URL}\nSource: {REPO}\nContact: {EMAIL}\n\n"
        "Please do not describe ChillMate as medical software, a diagnostic tool, or a crisis service.\n"
    )
    with zipfile.ZipFile(kit, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("README.txt", boiler)
        archive.write(ASSETS / "icon-512.png", "icon-512.png")
        archive.write(ASSETS / "og.png", "share-image-1200x630.png")
        for name in SHOTS + ["watch.png"]:
            archive.write(ASSETS / "shots" / name, f"screenshots/{name}")

    print(f"Built {len(urls)} pages into {DOCS.relative_to(ROOT)}/")
    for path, _ in urls:
        print(f"  {path}")

    # The reading-level budget, enforced here rather than merely written down.
    # People read these pages tired, anxious, or in their fourth language, so
    # plain wording is a requirement of the product; a requirement nobody checks
    # is one that quietly stops holding. Run after writing, so a failure still
    # leaves you the output to look at.
    import readability
    failures = readability.report(quiet=True)
    if failures:
        print(f"\nReading level regressed in {len(failures)} place(s):")
        for failure in failures:
            print(f"  {failure}")
        print("Run `python3 tools/readability.py --verbose` for the offending sentences.")
        raise SystemExit(1)
    print("\nReading level: every surface inside budget.")


if __name__ == "__main__":
    main()
