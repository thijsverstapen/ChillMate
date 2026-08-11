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

import html
import json
import os
import re
import shutil
import zipfile
from pathlib import Path

import site_content as C

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
ASSETS = DOCS / "assets"

SITE_ORIGIN = "https://thijsverstapen.github.io"
BASE_PATH = "/ChillMate/"
BASE_URL = SITE_ORIGIN + BASE_PATH
REPO = "https://github.com/thijsverstapen/ChillMate"
EMAIL = "chillmate@icloud.com"
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


def slug(text: str) -> str:
    value = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return value or "section"


def icon(name: str, cls: str = "icon", style: str = "") -> str:
    attrs = f' class="{cls}"' if cls else ""
    attrs += f' style="{style}"' if style else ""
    return f'<svg{attrs} aria-hidden="true"><use href="#i-{name}"/></svg>'


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
  <symbol id="i-sun" viewBox="0 0 24 24" {_STROKE}>
    <circle cx="12" cy="12" r="4"/>
    <path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.2 5.2l1.4 1.4M17.4 17.4l1.4 1.4M18.8 5.2l-1.4 1.4M6.6 17.4l-1.4 1.4"/>
  </symbol>
  <symbol id="i-moon" viewBox="0 0 24 24" {_STROKE}>
    <path d="M20 13.5A8 8 0 1110.5 4a6.5 6.5 0 009.5 9.5z"/>
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

# Runs before first paint so a reader who chose light does not get a dark
# flash first. Kept inline and tiny for exactly that reason.
THEME_BOOT = ("<script>try{var t=localStorage.getItem('cm-theme');"
              "if(t)document.documentElement.setAttribute('data-theme',t)}catch(e){}</script>")


def page_urls(key: str) -> dict:
    """Every language's URL for a page key, for hreflang and the switcher."""
    if key == "home":
        return {lang: BASE_PATH + ("" if lang == "en" else lang + "/") for lang in C.LANGS}
    if key == "support":
        return {lang: BASE_PATH + ("support/" if lang == "en" else lang + "/support/") for lang in C.LANGS}
    return {}


def head(lang, title, desc, canonical, depth, key="", extra_head="", body_class=""):
    a = rel(depth) + "assets/"
    css = (ASSETS / "style.css").read_text(encoding="utf-8")
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
  <meta name="theme-color" content="#0e1430" media="(prefers-color-scheme: dark)" />
  <meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)" />
  <link rel="canonical" href="{SITE_ORIGIN}{canonical}" />{alts}
  <link rel="icon" href="{a}mark.svg" type="image/svg+xml" />
  <link rel="apple-touch-icon" href="{a}icon-180.png" />
  <link rel="manifest" href="{BASE_PATH}manifest.webmanifest" />

  <meta property="og:site_name" content="ChillMate" />
  <meta property="og:title" content="{e(title)}" />
  <meta property="og:description" content="{e(desc)}" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="{SITE_ORIGIN}{canonical}" />
  <meta property="og:locale" content="{C.LANG_TAGS[lang]}" />
  <meta property="og:image" content="{BASE_URL}assets/og.png" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta property="og:image:alt" content="ChillMate. A calm, private place to look after yourself." />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="{e(title)}" />
  <meta name="twitter:description" content="{e(desc)}" />
  <meta name="twitter:image" content="{BASE_URL}assets/og.png" />
{THEME_BOOT}
  <style>{css}</style>{extra_head}
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
    privacy = r + "privacy/"
    support = (r + "support/") if lang == "en" else (("../" * (depth - 1) if depth > 1 else "./") + "support/")
    about = r + "about/"

    def item(href, label, ico, name):
        cur = ' aria-current="page"' if current == name else ""
        return f'      <a href="{href}"{cur}>{icon(ico) if ico else ""}{e(label)}</a>\n'

    nav = item(home, s["nav_home"], "", "home")
    nav += item(privacy, s["nav_privacy"], "shield", "privacy")
    nav += item(support, s["nav_support"], "life", "support")
    nav += item(about, s["nav_about"], "info", "about")
    nav += item(REPO, s["nav_github"], "github", "github")

    urls = page_urls(key) or page_urls("home")
    menu = ""
    for other in C.LANGS:
        cur = ' aria-current="true"' if other == lang else ""
        menu += (f'        <a lang="{C.LANG_TAGS[other]}" hreflang="{C.LANG_TAGS[other]}" '
                 f'href="{urls[other]}"{cur}>{e(C.LANG_NAMES[other])}</a>\n')

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
      <button type="button" class="chip-btn" data-theme-toggle hidden
              aria-pressed="false" title="{e(s["theme_hint"])}">
        <svg class="icon" aria-hidden="true"><use href="#i-sun"/></svg>
        <span data-theme-label>{e(s["theme_light"])}</span>
      </button>
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
<script src="{r}assets/site.js" defer></script>
</body>
</html>
"""


def phone(src, alt, depth, lazy=True, priority=False):
    r = rel(depth)
    loading = ' loading="lazy" decoding="async"' if lazy and not priority else ' decoding="async"'
    if priority:
        loading += ' fetchpriority="high"'
    return f"""<div class="phone">
        <div class="phone-shell">
          <div class="phone-screen">
            <img src="{r}assets/shots/{src}" width="560" height="1217" alt="{e(alt)}"{loading} />
            <span class="phone-island"></span>
          </div>
        </div>
      </div>"""


# --------------------------------------------------------------------------
# home
# --------------------------------------------------------------------------

SHOTS = ["home.png", "help.png", "privacy.png", "support.png", "more.png"]


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


def build_home(lang):
    s = C.STRINGS[lang]
    depth = 0 if lang == "en" else 1
    r = rel(depth)
    urls = page_urls("home")
    canonical = urls[lang]
    support = (r + "support/") if lang == "en" else "./support/"

    out = head(lang, s["home_title"], s["home_desc"], canonical, depth, "home")
    out += header(lang, depth, "home", "home")

    # hero
    out += f"""
  <section class="hero">
    <div>
      <h1>{e(no_orphan(s["h1"]))}</h1>
      <p class="lede">{e(s["lede"])}</p>

      <div class="cta-row">
        <a class="btn btn-primary" href="{support}">{icon("life")}{e(s["cta_support"])}</a>
        <a class="btn btn-ghost" href="#privacy">{icon("shield")}{e(s["cta_privacy"])}</a>
      </div>

      <p class="status-note">{icon("info")}{e(s["status_note"])}</p>
    </div>

    <div class="hero-phone-wrap">
      {phone(SHOTS[0], s["walk"][0][1], depth, lazy=False, priority=True)}
    </div>
  </section>
"""

    # the guided walk
    steps = ""
    frames = ""
    for i, (eyebrow, title, body) in enumerate(s["walk"]):
        steps += f"""
      <div class="walk-step reveal">
        <p class="eyebrow">{e(eyebrow)}</p>
        {phone(SHOTS[i], title, depth)}
        <h3>{e(no_orphan(title))}</h3>
        <p>{e(body)}</p>
      </div>
"""
        frames += (f'          <img src="{r}assets/shots/{SHOTS[i]}" width="560" height="1217" '
                   f'alt="{e(title)}" loading="lazy" decoding="async" />\n')

    out += f"""
  <section class="section">
    <p class="eyebrow">{e(s["walk_eyebrow"])}</p>
    <h2 id="inside">{e(no_orphan(s["walk_h2"]))}</h2>

    <div class="walk" data-walk>
      <div class="walk-stage" aria-hidden="true">
        <div class="phone">
          <div class="phone-shell">
            <div class="phone-screen">
{frames}              <span class="phone-island"></span>
            </div>
          </div>
        </div>
      </div>
      <div class="walk-steps">{steps}      </div>
    </div>
  </section>
"""

    # features
    tiles = ""
    for ico, tint, title, body in s["features"]:
        tiles += f"""      <div class="feature">
        <div class="chip {tint}">{icon(ico)}</div>
        <h3>{e(no_orphan(title))}</h3>
        <p>{e(body)}</p>
      </div>
"""
    out += f"""
  <section class="section reveal">
    <p class="eyebrow">{e(s["features_eyebrow"])}</p>
    <div class="grid three">
{tiles}    </div>
  </section>
"""

    # privacy
    checks = "".join(
        f'        <li>{icon("check")}<span>{e(c)}</span></li>\n' for c in s["privacy_checks"]
    )
    out += f"""
  <section class="section reveal" id="privacy">
    <p class="eyebrow">{e(s["privacy_eyebrow"])}</p>
    <div class="card">
      <h2>{icon("lock", style="color:var(--mint)")}{e(no_orphan(s["privacy_h2"]))}</h2>
      <p>{e(s["privacy_intro"])}</p>
      <ul class="checks">
{checks}      </ul>

      <p class="eyebrow" style="margin-top:22px">{e(s["diagram_title"])}</p>
      {diagram(lang)}

      <p style="margin-top:18px"><a href="{r}privacy/">{e(s["privacy_link"])}</a></p>
    </div>
  </section>

  <section class="section reveal">
    <p class="eyebrow">{e(s["proof_eyebrow"])}</p>
    <div class="card">
      <h2>{icon("code", style="color:var(--primary)")}{e(no_orphan(s["proof_h2"]))}</h2>
      <p>{e(s["proof_p"])}</p>
      <p>{s["proof_fact"]}</p>
      <div class="cta-row">
        <a class="btn btn-ghost" href="{REPO}">{icon("github")}{e(s["proof_cta_repo"])}</a>
        <a class="btn btn-ghost" href="{REPO}/blob/main/ChillMate/ChillMateModelContainer.swift">{icon("doc")}{e(s["proof_cta_store"])}</a>
      </div>
      <p class="meta" style="margin-top:14px">{e(s["proof_caption"])}</p>
    </div>
  </section>

  <section class="section reveal">
    <div class="grid two">
      <div class="feature">
        <div class="chip tint-blue">{icon("watch")}</div>
        <h3>{e(no_orphan(s["watch_h3"]))}</h3>
        <p>{e(s["watch_p"])}</p>
      </div>
      <div class="feature">
        <div class="chip tint-mint">{icon("globe")}</div>
        <h3>{e(no_orphan(s["langs_h3"]))}</h3>
        <p>{e(s["langs_p"])}</p>
      </div>
    </div>
  </section>

  <section class="section">
    <div class="callout">
      {icon("alert")}
      <p>{e(s["closing_callout"])}</p>
    </div>
  </section>
"""
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
        head_html = f'<div class="t">{e(title)}'
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

    out = head(lang, s["support_title"], s["support_desc"], canonical, depth, "support")
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
  <p class="lede">{e(s["support_lede"])}</p>

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
      <p>{e(s["support_help_p"])}</p>

      <div class="picker-row">
        <label for="country">{e(s["support_country_label"])}</label>
        <select id="country">
{options}        </select>
        <button type="button" class="chip-btn" onclick="window.print()">{icon("print")}{e(s["support_print"])}</button>
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
  </section>
"""
    out += footer(lang, depth)
    return out, canonical


# --------------------------------------------------------------------------
# English-only pages
# --------------------------------------------------------------------------

def build_privacy():
    lang, depth = "en", 1
    canonical = BASE_PATH + "privacy/"
    title = "ChillMate · Privacy Policy"
    desc = ("ChillMate's privacy policy, plus the honest detail: every network call the app "
            "makes, what a data breach could expose, and where to read the code.")

    out = head(lang, title, desc, canonical, depth)
    out += header(lang, depth, "privacy")
    out += f"""
  <h1>Privacy&nbsp;Policy</h1>
  <p class="lede">ChillMate is built privacy-first. Your information lives on your iPhone, under your control. We do not run servers that collect your data, we do not use advertising or analytics trackers, and we never sell or share your personal information.</p>
  <p class="meta">Last updated: {UPDATED} · Applies to the ChillMate iOS app and this website.</p>

  <div class="card">
    <h2 id="short">{icon("shield", style="color:var(--primary)")}The short&nbsp;version
      <a class="anchor" href="#short" aria-label="Link to this section">#</a></h2>
    <ul>
      <li><strong>On your device.</strong> Your profile, logs, plans, and notes are stored locally on your iPhone.</li>
      <li><strong>No trackers.</strong> No third-party advertising, analytics, or tracking SDKs.</li>
      <li><strong>Nothing sold.</strong> We never sell or share your personal or health information.</li>
      <li><strong>You are in control.</strong> You decide what to add, what to sync, and you can delete everything at any time.</li>
    </ul>
  </div>

  <div class="card">
    <h2 id="network">{icon("code", style="color:var(--mint)")}Every connection the app&nbsp;makes
      <a class="anchor" href="#network" aria-label="Link to this section">#</a></h2>
    <p>Privacy policies usually describe intentions. This is the list of what actually leaves the device, which is a shorter and more checkable thing.</p>
    <p>ChillMate's own code contains <strong>no networking at all</strong>: no <code>URLSession</code>, no analytics SDK, no crash reporter, no remote config. Everything below is either an Apple service talking to your own account, or something you tapped.</p>
    <div class="table-scroll">
      <table>
        <caption>Checked against ChillMate {VERSION} (build {BUILD}), across all 82 Swift files in the repository.</caption>
        <thead>
          <tr><th scope="col">What</th><th scope="col">Goes where</th><th scope="col">When</th></tr>
        </thead>
        <tbody>
          <tr><td>iCloud sync (CloudKit)</td><td>Your own private iCloud database</td><td>Only if you turn iCloud on. Apple holds it; the developer cannot read it.</td></tr>
          <tr><td>Encrypted backup file</td><td>Your own iCloud Drive</td><td>Only if you turn backups on, or export a file yourself.</td></tr>
          <tr><td>Apple Watch mirror</td><td>Your own watch, directly</td><td>If you pair a watch. Device to device, over Watch Connectivity.</td></tr>
          <tr><td>Apple Health</td><td>Stays on the device</td><td>Only the categories you approve. HealthKit is local storage, not a service.</td></tr>
          <tr><td>The optional tip</td><td>Apple's In-App Purchase</td><td>Only if you tap it. Apple takes the payment; we never see card details.</td></tr>
          <tr><td>A link you tap</td><td>Safari, to that site</td><td>Only on your tap. ChillMate does not fetch those pages itself.</td></tr>
          <tr><td>A call or message you send</td><td>Your phone app, your messages app</td><td>Only on your tap, and you see the message before it goes.</td></tr>
          <tr><td><strong>Anything to a ChillMate server</strong></td><td><strong>Nowhere</strong></td><td><strong>Never. There is no such server.</strong></td></tr>
        </tbody>
      </table>
    </div>
    <p><a href="{REPO}">Read the source</a> if you would rather check than believe.</p>
  </div>

  <div class="card">
    <h2 id="collected">{icon("doc", style="color:var(--purple)")}Category by&nbsp;category
      <a class="anchor" href="#collected" aria-label="Link to this section">#</a></h2>
    <p>These are the categories Apple asks every developer about. ChillMate's answer is the same in all of them, which is the point.</p>
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
    <p>To be exact about the word: ChillMate <em>stores</em> a great deal on your phone, including health and sensitive information you type in. It <em>collects</em> none of it, in the sense of taking it off your device and holding it somewhere you cannot reach.</p>
  </div>

  <div class="card">
    <h2 id="threat">{icon("hand", style="color:var(--amber)")}What we actually designed&nbsp;against
      <a class="anchor" href="#threat" aria-label="Link to this section">#</a></h2>
    <p>Most privacy pages talk about breaches and hackers. For an app like this, the realistic risk is closer to home: <strong>someone picking up your unlocked phone.</strong> A partner, a housemate, a family member, a colleague glancing at a notification.</p>
    <p>That is why the app has a Face ID or PIN lock of its own, on top of the phone's, why notifications can be worded so the lock screen says nothing revealing, why the screen can be paused to a blank moon in one tap, and why ChillMate hides its contents in the App Switcher and while your screen is recorded or mirrored.</p>
    <p>The design consequence of having no server is that a breach of the developer exposes nothing, because there is nothing held. The trade-off is honest too: if you lose the phone and have no backup, the data is gone. That is the deal, and it is deliberate.</p>
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
    <p>All of this processing happens on your device. ChillMate does not send your content to the developer.</p>
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
    <p><strong>Optional iCloud.</strong> If you turn on iCloud backup or sync, ChillMate stores your data in <em>your own</em> private iCloud account through Apple's CloudKit and iCloud Drive. It is protected by Apple's encryption and is accessible only to you. The developer has no access to it.</p>
    <p><strong>No developer servers.</strong> ChillMate has no backend that receives or stores your personal information.</p>
  </div>

  <div class="card">
    <h2 id="watch">{icon("watch", style="color:var(--mint)")}Apple&nbsp;Watch</h2>
    <p>If you pair an Apple Watch, ChillMate mirrors part of your data to the watch app so it still works when your phone is out of reach: your recovery streak and daily score, any running dose timers, your watch settings, your emergency number, and the <strong>name and phone number of your trusted contact</strong>, so the watch can reach them without your phone.</p>
    <p>This goes directly between your phone and your watch over Apple's Watch Connectivity, on your own devices. It does not pass through our servers, because there are none.</p>
    <p>Two things worth knowing. The trusted contact's details belong to another person and end up on a second device, so add someone only if they would be comfortable with that. And ChillMate's app lock protects the <em>phone</em> app. The watch app is protected by your watch's own passcode and wrist detection instead.</p>
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
    <h2 id="payments">{icon("tag", style="color:var(--mint)")}Payments and&nbsp;tips</h2>
    <p>ChillMate is free. An optional tip is handled entirely by Apple's In-App Purchase system. Apple processes the payment; the developer never receives your card or account details. Tips do not unlock features and do not change what data is collected.</p>
  </div>

  <div class="card">
    <h2 id="control">{icon("lock", style="color:var(--purple)")}Your control and&nbsp;deletion</h2>
    <ul>
      <li>You can delete logs, plans, reminders, timers, journal entries, and your whole account from inside the app.</li>
      <li>Deleting the app removes its local data from your iPhone. iCloud data can be removed from iCloud settings or from within the app's backup controls.</li>
      <li>iOS permission controls for Health, Location, Notifications, Contacts, and Photos remain available in the Settings app at any time.</li>
    </ul>
    <p>Because ChillMate does not collect your data on a server, there is no remote profile to request, correct, or erase. You already hold and control all of it. If you are in the EU/EEA, your GDPR rights (access, rectification, erasure, portability, objection) are satisfied directly through these on-device controls.</p>
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
    <p>This policy is published in English only, so that there is one authoritative text rather than five translations that can drift apart.</p>
  </div>

  <div class="card">
    <h2 id="contact">{icon("mail", style="color:var(--mint)")}Contact</h2>
    <p>Questions about privacy? Email <a href="mailto:{EMAIL}">{EMAIL}</a>. For anything security-related, see the <a href="../security/">security page</a>.</p>
  </div>
"""
    out += footer(lang, depth)
    return out, canonical


def build_about():
    lang, depth = "en", 1
    canonical = BASE_PATH + "about/"
    title = "ChillMate · About"
    desc = "Why ChillMate exists, who makes it, and the rules it is built to."

    out = head(lang, title, desc, canonical, depth)
    out += header(lang, depth, "about")
    out += f"""
  <h1>Why this&nbsp;exists</h1>
  <p class="lede">ChillMate is made by one person in the Netherlands. It is free, it has no ads, and it is open source. There is no company behind it and no plan to build one.</p>

  <div class="card">
    <h2 id="why">{icon("info", style="color:var(--primary)")}The thing it is trying to&nbsp;fix
      <a class="anchor" href="#why" aria-label="Link to this section">#</a></h2>
    <p>Plenty of apps will happily hold the most sensitive things about you: how you slept, what you took, who you were with, what you are worried about. Almost all of them keep a copy on a server, and almost all of them are honest that they do, in a paragraph nobody reads.</p>
    <p>ChillMate is the version of that app where the copy does not exist. Not encrypted-at-rest on someone's cloud, not anonymised, not retained for ninety days. There is no server, so there is nothing to leak, subpoena, sell, or change its mind about later.</p>
    <p>That constraint decides most of the design. It is why there is no account, why sync means <em>your</em> iCloud rather than ours, and why the app has to be genuinely useful offline, in a taxi, at four in the morning.</p>
  </div>

  <div class="card">
    <h2 id="rules">{icon("shield", style="color:var(--mint)")}The rules it is built&nbsp;to
      <a class="anchor" href="#rules" aria-label="Link to this section">#</a></h2>
    <ul class="checks">
      <li>{icon("check")}<span><strong>No server, no account.</strong> If a feature would need one, the feature is wrong, not the rule.</span></li>
      <li>{icon("check")}<span><strong>Nothing is ever sold.</strong> Not now, not at scale, not to a buyer later.</span></li>
      <li>{icon("check")}<span><strong>Free means free.</strong> The tip unlocks nothing. Every feature is available to everyone.</span></li>
      <li>{icon("check")}<span><strong>It never decides for you.</strong> ChillMate tells you what is known and hands the decision back.</span></li>
      <li>{icon("check")}<span><strong>Help before features.</strong> Crisis numbers, breathing and grounding work with no data, no signal, and no setup.</span></li>
      <li>{icon("check")}<span><strong>Open, so it can be checked.</strong> The claim on the front page is only worth something if you can read the code behind it.</span></li>
    </ul>
  </div>

  <div class="card">
    <h2 id="built">{icon("code", style="color:var(--purple)")}How it is&nbsp;built
      <a class="anchor" href="#built" aria-label="Link to this section">#</a></h2>
    <p>Swift and SwiftUI, SwiftData for storage, HealthKit, WidgetKit, App Intents and a native watchOS app. Everything on-device, including the written summaries, which use Apple's on-device Foundation Models rather than a hosted one.</p>
    <p>Version {VERSION} (build {BUILD}). It runs on iOS 26 and later, with an Apple Watch app, Home Screen and Lock Screen widgets, complications, Siri shortcuts and Spotlight.</p>
    <p>See the <a href="../changelog/">changelog</a> for what has landed, or the <a href="{REPO}">repository</a> for everything else.</p>
  </div>

  <div class="card">
    <h2 id="contact">{icon("mail", style="color:var(--mint)")}Get in&nbsp;touch
      <a class="anchor" href="#contact" aria-label="Link to this section">#</a></h2>
    <p>Email <a href="mailto:{EMAIL}">{EMAIL}</a>. One person reads it, so it is slower than a support desk and more useful than one.</p>
    <div class="contact-row">
      <a class="btn btn-primary" href="mailto:{EMAIL}">{icon("mail")}Email</a>
      <a class="btn btn-ghost" href="../press/">{icon("doc")}Press kit</a>
      <a class="btn btn-ghost" href="{REPO}">{icon("github")}Source</a>
    </div>
  </div>
"""
    out += footer(lang, depth)
    return out, canonical


RELEASES = [
    ("4.2.1", "422", "August 2026", "Fixes, and one that mattered", [
        "Fixed a crash on opening the app after upgrading from 4.2.0, caused by two schema versions sharing a checksum.",
        "Choosing a language inside the app no longer drops your region, so dates, numbers and 24-hour time stay right.",
        "Translated the last untranslated strings, including every combination-checker warning, in all five languages.",
        "Accessibility fixes: high contrast now reaches card surfaces, the one-handed layout toggle does something again, and reduced motion is honoured in more places.",
        "Continuous integration runs and passes for the first time.",
    ]),
    ("4.1.0", "410", "July 2026", "A home that knows the moment", [
        "Redesigned home: tools grouped into four moments, before you go, while you are out, aftercare and health, and your patterns.",
        "It arranges itself. When a dose timer is running, or it is the morning after, the tool you need rises to the top.",
        "Get help now is pinned to the top, so breathing, grounding and emergency calls are never something to hunt for.",
        "Three calm tabs: Home, History and More. Calendar and journal now live together under History.",
        "Optional weekend night check-ins on Friday and Saturday, with one-tap I am safe or Get help.",
        "Choose exactly which reminders you want during setup.",
    ]),
    ("4.0.0", "400", "June 2026", "The Apple Watch update", [
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
    for version, build, when, headline, items in RELEASES:
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
  </div>
"""
    out += footer(lang, depth)
    return out, canonical


def build_press():
    lang, depth = "en", 1
    canonical = BASE_PATH + "press/"
    title = "ChillMate · Press kit"
    desc = "Icon, screenshots, boilerplate and facts about ChillMate, free to use."

    out = head(lang, title, desc, canonical, depth)
    out += header(lang, depth, "")
    shots = "".join(
        f'      <a class="res" href="../assets/shots/{name}"><div class="t">{label}{icon("ext")}</div>'
        f'<div class="d">PNG, 560 px wide</div></a>\n'
        for name, label in [("home.png", "Home"), ("help.png", "Panic support"),
                            ("privacy.png", "Privacy dashboard"), ("support.png", "Support"),
                            ("more.png", "More")]
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
          <tr><th scope="row">Price</th><td>Free. No ads, no subscription, no paid tier. An optional tip unlocks nothing.</td></tr>
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
    <p><strong>One paragraph.</strong> ChillMate keeps your logs, reflections, plans, reminders and personal-safety tools in one private overview on your iPhone and Apple Watch. It has no account, no server and no trackers, so nothing about you is held anywhere you cannot reach. Alongside the private log it offers breathing and grounding tools, a combination checker, discreet check-in timers, a safe route home, and a country-aware directory of real crisis and health services that works offline. It is free, open source, and made by one developer in the Netherlands.</p>
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
    <p>What is left, and what is genuinely worth probing: the app lock (PBKDF2-derived PIN held in the Keychain, plus Face ID), the encrypted backup format, the phone to watch mirror, what the widgets and Live Activity expose on a locked screen, and whether the discreet notification wording ever leaks something it should not.</p>
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
    css = (ASSETS / "style.css").read_text(encoding="utf-8")
    return f"""<!DOCTYPE html>
<html lang="en" data-sw-scope="{BASE_PATH}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ChillMate · Page not found</title>
  <meta name="description" content="That page is not here. The things people usually want are." />
  <meta name="robots" content="noindex" />
  <meta name="theme-color" content="#0e1430" media="(prefers-color-scheme: dark)" />
  <meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)" />
  <link rel="icon" href="{a}mark.svg" type="image/svg+xml" />
  <link rel="apple-touch-icon" href="{a}icon-180.png" />
{THEME_BOOT}
  <style>{css}</style>
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
    <a class="res" href="{BASE_PATH}about/"><div class="t">{icon("info")}About</div><div class="d">Why this exists and who makes it.</div></a>
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
<script src="{a}site.js" defer></script>
</body>
</html>
"""


# --------------------------------------------------------------------------
# non-HTML files
# --------------------------------------------------------------------------

SW = f"""/* Keeps the support page reachable with no signal.

   The crisis numbers on that page are needed exactly when a network is least
   dependable, so they are cached on first visit and served from the cache when
   a fetch fails. Everything else is network-first and simply falls back. */

const CACHE = 'chillmate-{VERSION}-{BUILD}';
const CORE = [
  '{BASE_PATH}',
  '{BASE_PATH}support/',
  '{BASE_PATH}assets/site.js',
  '{BASE_PATH}assets/mark.svg',
];

self.addEventListener('install', (event) => {{
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(CORE)).then(() => self.skipWaiting()));
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
  event.respondWith(
    fetch(event.request)
      .then((response) => {{
        if (response && response.status === 200 && response.type === 'basic') {{
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(event.request, copy));
        }}
        return response;
      }})
      .catch(() => caches.match(event.request).then((hit) => hit || caches.match('{BASE_PATH}support/')))
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


def structured_data():
    return {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "ChillMate",
        "applicationCategory": "HealthApplication",
        "operatingSystem": "iOS 26, watchOS",
        "softwareVersion": VERSION,
        "url": BASE_URL,
        "description": C.STRINGS["en"]["home_desc"],
        "inLanguage": [C.LANG_TAGS[l] for l in C.LANGS],
        "isAccessibleForFree": True,
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "EUR"},
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

        body, canonical = build_support(lang)
        target = DOCS / "support" / "index.html" if lang == "en" else DOCS / lang / "support" / "index.html"
        write(target, body)
        urls.append((canonical, "0.9"))

    for builder, folder in [(build_privacy, "privacy"), (build_about, "about"),
                            (build_changelog, "changelog"), (build_press, "press"),
                            (build_security, "security")]:
        body, canonical = builder()
        write(DOCS / folder / "index.html", body)
        urls.append((canonical, "0.7"))

    write(DOCS / "404.html", build_404())
    write(DOCS / "robots.txt", ROBOTS)
    write(DOCS / "sw.js", SW)
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
        "about you is held anywhere you cannot reach. Alongside the private log it offers breathing and "
        "grounding tools, a combination checker, discreet check-in timers, a safe route home, and a "
        "country-aware directory of real crisis and health services that works offline. It is free, open "
        "source, and made by one developer in the Netherlands.\n\n"
        f"Site: {BASE_URL}\nSource: {REPO}\nContact: {EMAIL}\n\n"
        "Please do not describe ChillMate as medical software, a diagnostic tool, or a crisis service.\n"
    )
    with zipfile.ZipFile(kit, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("README.txt", boiler)
        archive.write(ASSETS / "icon-512.png", "icon-512.png")
        archive.write(ASSETS / "og.png", "share-image-1200x630.png")
        for name in SHOTS:
            archive.write(ASSETS / "shots" / name, f"screenshots/{name}")

    print(f"Built {len(urls)} pages into {DOCS.relative_to(ROOT)}/")
    for path, _ in urls:
        print(f"  {path}")


if __name__ == "__main__":
    main()
