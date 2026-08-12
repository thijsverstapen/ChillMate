#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Measure how hard the site is to read, and fail the build if it gets harder.

Why this exists.

ChillMate is read by people who are tired, anxious, coming down, worried about a
test result, or reading their fourth language. Every one of those states costs
you reading comprehension. A sentence that is merely *elegant* on a good day is
a sentence somebody bounces off at four in the morning, and the bounce happens
on the page that was supposed to help.

So reading level is a product requirement here, not a style preference, and a
requirement nobody measures is a requirement nobody keeps. This script turns it
into a number.

    python3 tools/readability.py            # report
    python3 tools/readability.py --check    # exit 1 if a page is too hard

The number is Flesch-Kincaid grade level: roughly the years of schooling a
reader needs to follow the text on the first pass. Plain-language guidance for
health information is grade 8 or below; UK government guidance for public
services is grade 9. This site targets **grade 9**, and the safety-critical
pages target **grade 8**, because those are the ones people read in a hurry.

The formula is crude. It counts syllables and sentence lengths and understands
nothing, so it can be gamed by chopping good sentences in half. It is used here
the way a smoke alarm is used: not as a judge of prose, but as something that
goes off when a page has quietly filled with subordinate clauses again.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import site_content as C  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

# Grade level each surface has to stay under.
LIMITS = {
    "home": 9.0,
    "how it works": 9.0,
    "support": 8.0,      # crisis numbers and what to do in an emergency
    "faq": 9.0,
    "privacy": 11.0,     # a near-legal document, held to a looser bar
    "about": 10.0,
    "security": 12.0,    # written for people who audit software
    "press": 11.0,
}

VOWELS = "aeiouy"


def syllables(word: str) -> int:
    """Rough syllable count. Wrong on individual words, fine in aggregate."""
    word = re.sub(r"[^a-z]", "", word.lower())
    if not word:
        return 0
    if len(word) <= 3:
        return 1
    # Silent trailing e, but not in "the", "she", or a consonant + "le".
    word = re.sub(r"(?:[^laeiouy]es|ed|[^laeiouy]e)$", "", word)
    word = re.sub(r"^y", "", word)
    count = len(re.findall(r"[aeiouy]{1,2}", word))
    return max(1, count)


def sentences(text: str) -> list[str]:
    # Protect the abbreviations that otherwise invent sentence breaks.
    guarded = re.sub(r"\b(e\.g|i\.e|Mr|Mrs|Dr|St|vs|approx|etc)\.", r"\1<dot>", text)
    parts = re.split(r"(?<=[.!?])\s+", guarded)
    return [p.replace("<dot>", ".").strip() for p in parts if p.strip()]


def words(text: str) -> list[str]:
    return re.findall(r"[A-Za-z][A-Za-z'-]*", text)


def strip_markup(text: str) -> str:
    """Plain prose out of a string that may carry HTML or a placeholder."""
    text = re.sub(r"<[^>]+>", " ", text)
    text = text.replace("{email}", "an email address")
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def score(text: str) -> dict:
    """Flesch-Kincaid grade and Flesch reading ease for a block of prose."""
    sents = sentences(text)
    wordlist = words(text)
    if not sents or len(wordlist) < 10:
        return {}
    syl = sum(syllables(w) for w in wordlist)
    wps = len(wordlist) / len(sents)
    spw = syl / len(wordlist)
    return {
        "grade": 0.39 * wps + 11.8 * spw - 15.59,
        "ease": 206.835 - 1.015 * wps - 84.6 * spw,
        "words": len(wordlist),
        "sentences": len(sents),
        "wps": wps,
    }


# --------------------------------------------------------------------------
# pulling the prose out of the sources
# --------------------------------------------------------------------------

# Keys that are labels, not prose: a button or a table cell has no sentence
# structure, so scoring it only adds noise.
SKIP_PREFIX = ("nav_", "cat_", "diagram_", "demo_meds_", "demo_timing", "demo_share",
               "demo_shared", "demo_print", "demo_reset", "demo_pick", "demo_assess",
               "support_email_btn", "support_issue_btn", "support_print",
               "support_country_label", "support_emergency", "og_foot",
               "proof_cta_", "privacy_link", "faq_teaser_link", "scroll_cue",
               "howto_back", "cta_", "copy", "copied", "call", "open", "skip",
               "to_top", "made", "lang_label", "home_title", "support_title",
               "howto_title", "statement")

# Which surface each key belongs to, so a page can be scored on its own.
SURFACE = {
    "home": ("h1", "lede", "home_desc", "og_sub", "status_note",
             "audience_h2", "audience_p", "audience_points", "audience_chill",
             "walk_h2", "walk", "demo_h2", "demo_p", "demo_none_title",
             "demo_none_body", "demo_empty", "demo_note",
             "statement2_big", "statement2_note", "privacy_intro",
             "privacy_checks", "disclaimer", "close_h2", "close_p"),
    "how it works": ("howto_lede", "night", "refuse_p", "refuse", "foryou_h2",
                     "foryou", "foryou_not", "features", "watch_h3", "watch_p",
                     "watch_quote", "langs_h3", "langs_p", "howto_desc",
                     "proof_h2", "proof_p", "proof_fact", "footnotes_intro",
                     "footnotes"),
    "support": ("support_h1", "support_lede", "support_urgent", "support_help_h2",
                "support_help_p", "support_contact_p", "support_desc",
                "policy_en_note"),
    "faq": ("faq",),
}


def flatten(value) -> list[str]:
    """Every string inside a value, whatever shape it is."""
    if isinstance(value, str):
        return [value]
    if isinstance(value, (list, tuple)):
        out = []
        for item in value:
            out.extend(flatten(item))
        return out
    return []


def surface_text(lang: str, surface: str, skip: set | None = None) -> str:
    strings = C.STRINGS[lang]
    parts = []
    for key in SURFACE[surface]:
        if key not in strings or (skip and key in skip):
            continue
        for piece in flatten(strings[key]):
            # CSS tokens and anchor ids ride along inside tuples; drop them.
            if re.fullmatch(r"[a-z][a-z0-9-]*", piece) and " " not in piece:
                continue
            parts.append(strip_markup(piece))
    return " ".join(p if p.endswith((".", "!", "?")) else p + "." for p in parts)


PAGE_FUNCS = {
    "privacy": "build_privacy",
    "about": "build_about",
    "security": "build_security",
    "press": "build_press",
}


def inline_page_text(func_name: str) -> str:
    """Prose out of one build_site.py page function, without running it."""
    source = (ROOT / "tools" / "build_site.py").read_text(encoding="utf-8")
    start = source.index(f"def {func_name}(")
    end = source.index("\ndef ", start + 1)
    body = source[start:end]

    # Only the paragraphs and list items a reader actually reads.
    chunks = re.findall(r"<(?:p|li)(?:\s[^>]*)?>(.*?)</(?:p|li)>", body, re.S)
    text = " ".join(strip_markup(c) for c in chunks)
    # f-string interpolations become placeholders rather than noise.
    text = re.sub(r"\{[^{}]*\}", "it", text)
    return re.sub(r"\s+", " ", text).strip()


def hardest(text: str, limit: int = 5) -> list[tuple[int, str]]:
    """The longest sentences, which are nearly always the ones to fix."""
    scored = [(len(words(s)), s) for s in sentences(text)]
    scored.sort(reverse=True, key=lambda pair: pair[0])
    return scored[:limit]


# --------------------------------------------------------------------------
# the things the grade formula cannot see
# --------------------------------------------------------------------------
#
# Flesch-Kincaid counts syllables and sentence lengths, so it rates this site
# far easier than it reads. It scored the old copy at grade 4 while that copy
# was still saying "Privacy here is not a setting. It is the shape of the app."
# Short words, common words, and almost no reader knows what it means.
#
# These three checks catch what the formula misses.

# Over this many words, a sentence is carrying more than one idea and a tired
# reader has to go back to the start of it.
LONG_SENTENCE = 20
LONG_SHARE_LIMIT = 0.18

# Terms a reader outside this world will not know. The value is the set of gloss
# phrases, any one of which counts as having explained the term. They have to be
# this specific: an earlier version accepted any nearby occurrence of the word
# "after", which every page contains, so PEP passed while being explained
# nowhere at all. An empty tuple means the term does not belong in prose here.
JARGON = {
    "PEP": ("pep is", "medicine you take after", "possible hiv exposure"),
    "PrEP": ("prep is", "pill that stops you getting hiv", "daily pill"),
    "harm reduction": ("harm reduction is", "harm reduction means", "safer-use"),
    # Kept rather than replaced with "scrambled": vagueness about encryption on
    # a page whose whole argument is privacy reads as evasion. The rule is that
    # the precise word stays and earns one plain sentence of explanation.
    "encrypted": ("unreadable to anyone without your key", "encrypted means"),
    "complication": ("watch face",),
    "Smart Stack": ("watch face",),
    "PBKDF2": (),
    "AES-GCM": (),
    "CloudKit": (),
    "URLSession": (),
    "SwiftData": (),
    "HealthKit": (),
}

# Keys whose whole job is to be technical: the footnote list points at source
# files, the spec table is a spec table, and `proof_fact` names the exact API
# whose absence is the claim. Naming `URLSession` there is the evidence, not
# jargon, and a reader who does not recognise it loses nothing by skipping it.
# Everywhere else, a term from JARGON has to arrive already explained.
TECHNICAL_KEYS = {"footnotes", "specs", "proof_fact", "footnotes_title",
                  "footnotes_intro"}

# Formal written forms a person would say out loud as a contraction. Not a rule
# so much as a thermometer: a page with none of these has usually drifted into
# a register that reads as an institution talking, not a person.
FORMAL = [r"\bit is\b", r"\bthat is\b", r"\bthere is\b", r"\byou are\b",
          r"\bdo not\b", r"\bdoes not\b", r"\bwill not\b", r"\bcannot\b",
          r"\bis not\b", r"\bhave not\b", r"\bI am\b", r"\byou will\b"]


def texture(text: str) -> dict:
    """Sentence length spread and register, which is what actually bites."""
    sents = sentences(text)
    if not sents:
        return {}
    lengths = [len(words(s)) for s in sents]
    long_ones = [s for s, n in zip(sents, lengths) if n > LONG_SENTENCE]
    formal = sum(len(re.findall(p, text, re.I)) for p in FORMAL)
    contractions = len(re.findall(r"\b\w+(?:'|’)(?:s|t|re|ve|ll|d|m)\b", text))
    return {
        "long": len(long_ones),
        "longShare": len(long_ones) / len(sents),
        "longest": max(lengths),
        "formal": formal,
        "contractions": contractions,
        "examples": long_ones[:3],
    }


def jargon_report() -> list[str]:
    """Unexplained jargon in the prose a newcomer actually reads.

    Scanned with the deliberately technical keys removed, so a term is only a
    problem when it turns up in a sentence somebody is expected to follow.
    """
    reader_facing = " ".join(
        surface_text("en", name, skip=TECHNICAL_KEYS)
        for name in ("home", "how it works", "support", "faq")
    ).lower()
    problems = []
    for term, glosses in JARGON.items():
        if term.lower() not in reader_facing:
            continue
        if not glosses:
            problems.append(f"{term}: technical term on a reader-facing page")
        elif not any(g in reader_facing for g in glosses):
            problems.append(f"{term}: used but never explained "
                            f"(expected one of {', '.join(glosses)})")
    return problems


def report(verbose: bool = False, quiet: bool = False) -> list[str]:
    """Print the table and return the list of budget failures.

    Split out of `main` so `build_site.py` can call it, which is what makes the
    limits in this file a rule rather than a wish. A budget nobody runs is a
    budget that has already been broken.
    """
    failures = []

    if not quiet:
        print(f"{'surface':<16}{'grade':>7}{'ease':>7}{'words':>7}"
              f"{'long':>7}{'max':>6}{'formal':>8}{'contr':>7}  limit")
        print("-" * 78)

    everything = [(name, surface_text("en", name)) for name in SURFACE]
    everything += [(name, inline_page_text(func)) for name, func in PAGE_FUNCS.items()]

    for name, text in everything:
        result = score(text)
        tex = texture(text)
        limit = LIMITS[name]

        over_grade = result["grade"] > limit
        # The long-sentence budget is only enforced on the pages a newcomer
        # reads. The privacy policy and the security page are reference
        # documents, where a precise long sentence beats three vague short ones.
        enforce_long = name in ("home", "how it works", "support", "faq")
        over_long = enforce_long and tex["longShare"] > LONG_SHARE_LIMIT

        if over_grade:
            failures.append(f"{name}: grade {result['grade']:.1f} over limit {limit:.0f}")
        if over_long:
            failures.append(f"{name}: {tex['longShare']:.0%} of sentences over "
                            f"{LONG_SENTENCE} words, limit {LONG_SHARE_LIMIT:.0%}")

        flag = "  OVER" if (over_grade or over_long) else ""
        if not quiet:
            print(f"{name:<16}{result['grade']:>7.1f}{result['ease']:>7.1f}"
                  f"{result['words']:>7}{tex['longShare']:>6.0%}{tex['longest']:>6}"
                  f"{tex['formal']:>8}{tex['contractions']:>7}  {limit:.0f}{flag}")

        if (verbose or over_long) and not quiet:
            for sentence in tex["examples"]:
                print(f"      {len(words(sentence)):>3}w  {sentence[:108]}")

    problems = jargon_report()
    failures.extend(problems)
    if not quiet:
        print()
        if problems:
            print("Unexplained jargon on reader-facing pages:")
            for problem in problems:
                print(f"  {problem}")
        else:
            print("No unexplained jargon on the reader-facing pages.")

    return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="exit 1 if any surface is over its budget")
    parser.add_argument("--verbose", action="store_true",
                        help="show the longest sentences on every surface")
    args = parser.parse_args()

    failures = report(verbose=args.verbose)

    print()
    if failures:
        print(f"{len(failures)} problem(s):")
        for failure in failures:
            print(f"  {failure}")
        if args.check:
            sys.exit(1)
    else:
        print("Every surface is inside its reading-level budget.")


if __name__ == "__main__":
    main()
