#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check the built site in docs/ before it goes anywhere.

Every rule here exists because the thing it checks has actually gone wrong on
this site at least once:

  * a chapter was cut and two footnote markers were left pointing at rows that
    no longer existed,
  * a sub-nav link pointed at an anchor that had been renamed,
  * `sips -Z` scaled a portrait screenshot by its long edge, so the markup kept
    claiming a width the file did not have,
  * a whole page went dark because a build error happened on GitHub's side,
    where there was no local way to see it coming.

So this runs locally, on the output, and reads only what a browser would read.

    python3 tools/validate_site.py

Exits non-zero if anything is broken, which is the point.
"""

from __future__ import annotations

import html
import re
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
BASE_PATH = "/ChillMate/"

# Text that is allowed to contain a dash-looking character because it is not
# prose: code samples, and the mid-dot used as a separator.
SKIP_TAGS = re.compile(r"<(script|style|code|pre)\b.*?</\1>", re.S | re.I)


def visible_text(markup: str) -> str:
    body = SKIP_TAGS.sub(" ", markup)
    body = re.sub(r"<[^>]+>", " ", body)
    return html.unescape(body)


# Google's site-verification file is named .html and is not one. It is a
# single line of text whose exact bytes Google dictates, so it has no lang, no
# title and no description, and every head rule below would fail it. Checking
# it as a page would mean either weakening those rules for real pages or
# editing the file, and editing it breaks verification.
NOT_A_PAGE = re.compile(r"^google[0-9a-f]+\.html$")


def pages() -> list[Path]:
    return sorted(p for p in DOCS.rglob("*.html") if not NOT_A_PAGE.fullmatch(p.name))


def resolve(page: Path, href: str) -> Path | None:
    """The file a browser would fetch for this href, or None if it is external."""
    split = urlsplit(href)
    if split.scheme or split.netloc:
        return None
    path = unquote(split.path)
    if not path:
        return None
    if path.startswith(BASE_PATH):
        target = DOCS / path[len(BASE_PATH):]
    elif path.startswith("/"):
        target = DOCS / path.lstrip("/")
    else:
        target = page.parent / path
    target = Path(*target.parts)  # normalise
    if str(target).endswith("/") or target.is_dir():
        target = target / "index.html"
    return target


def main():
    problems: list[str] = []
    checked_links = 0
    checked_anchors = 0
    files = pages()
    if not files:
        sys.exit("docs/ has no HTML. Run tools/build_site.py first.")

    for page in files:
        markup = page.read_text(encoding="utf-8")
        where = page.relative_to(ROOT)

        ids = re.findall(r'\sid="([^"]+)"', markup)
        duplicates = [name for name, count in Counter(ids).items() if count > 1]
        if duplicates:
            problems.append(f"{where}: duplicate id(s) {duplicates}")
        id_set = set(ids)

        # ---- head essentials
        if not re.search(r"<html[^>]+lang=", markup):
            problems.append(f"{where}: <html> has no lang")
        if not re.search(r"<title>[^<]+</title>", markup):
            problems.append(f"{where}: no title")
        if "404" not in page.name and not re.search(
                r'<meta name="description" content="[^"]{40,}"', markup):
            problems.append(f"{where}: missing or very short meta description")

        # ---- links
        for href in re.findall(r'\shref="([^"]+)"', markup):
            if href.startswith(("mailto:", "tel:", "#", "data:")):
                if href.startswith("#") and len(href) > 1:
                    checked_anchors += 1
                    if href[1:] not in id_set:
                        problems.append(f"{where}: anchor {href} has no target")
                continue
            target = resolve(page, href)
            if target is None:
                continue
            checked_links += 1
            if not target.exists():
                problems.append(f"{where}: dead link {href} -> {target.relative_to(ROOT)}")
            fragment = urlsplit(href).fragment
            if fragment and target.exists() and target.suffix == ".html":
                other = target.read_text(encoding="utf-8")
                if f'id="{fragment}"' not in other:
                    problems.append(f"{where}: {href} points at a missing anchor")

        # ---- images
        for tag in re.findall(r"<img\s[^>]*>", markup):
            src = re.search(r'src="([^"]+)"', tag)
            if not src:
                problems.append(f"{where}: <img> with no src")
                continue
            if 'alt="' not in tag:
                problems.append(f"{where}: <img src={src.group(1)}> has no alt")
            if "width=" not in tag or "height=" not in tag:
                problems.append(f"{where}: <img src={src.group(1)}> has no intrinsic size, "
                                f"which makes the page jump while it loads")
            asset = resolve(page, src.group(1))
            if asset is not None and not asset.exists():
                problems.append(f"{where}: missing image {src.group(1)}")

        # Every candidate a browser could pick, not just the `src` fallback.
        # An <img> whose src exists while its AVIF sibling does not is a page
        # that looks fine to whoever built it and is broken for everyone on a
        # current browser, because the modern <source> is the one they get.
        for tag in re.findall(r"<(?:img|source)\s[^>]*>", markup):
            candidates = re.search(r'srcset="([^"]+)"', tag)
            if not candidates:
                continue
            for candidate in candidates.group(1).split(","):
                url = candidate.strip().split(" ")[0]
                if not url:
                    continue
                asset = resolve(page, url)
                if asset is not None and not asset.exists():
                    problems.append(f"{where}: srcset points at missing {url}")
            if tag.startswith("<source") and 'type="' not in tag:
                problems.append(f"{where}: <source> with no type, so the browser "
                                f"cannot tell whether it can decode it")

        # ---- the dash rule, on what a reader actually sees
        text = visible_text(markup)
        for match in re.finditer(r"[^.!?]{0,60}(?:—|–|\w \- \w)[^.!?]{0,60}", text):
            problems.append(f"{where}: dash in prose: {match.group(0).strip()[:100]!r}")

    # ---- the non-HTML files that have to exist
    for required in ("sitemap.xml", "robots.txt", "manifest.webmanifest",
                     ".nojekyll", "sw.js", "404.html",
                     ".well-known/security.txt", "changelog/feed.xml"):
        if not (DOCS / required).exists():
            problems.append(f"docs/{required} is missing")

    # Every page in the sitemap has to be a page that exists, and every page
    # that exists should be in the sitemap. A URL listed but not built is a soft
    # 404 handed to a search engine.
    sitemap = (DOCS / "sitemap.xml").read_text(encoding="utf-8")
    listed = set(re.findall(r"<loc>[^<]*?(/ChillMate/[^<]*)</loc>", sitemap))
    built = {"/ChillMate/" + str(p.parent.relative_to(DOCS)).replace(".", "").lstrip("/")
             for p in files if p.name == "index.html"}
    built = {(u if u.endswith("/") else u + "/") for u in built}
    for url in sorted(listed - built):
        problems.append(f"sitemap lists {url}, which was not built")
    for url in sorted(built - listed):
        problems.append(f"{url} was built but is not in the sitemap")

    print(f"{len(files)} pages, {checked_links} links, {checked_anchors} in-page anchors")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(f"  {problem}")
        sys.exit(1)
    print("No broken links, no missing anchors, no structural problems.")


if __name__ == "__main__":
    main()
