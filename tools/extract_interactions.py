#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lift the risk checker's combination table out of the app, into the website.

The website's playable risk checker is only worth anything if it says exactly
what the app says. So nothing here is retyped: the rules are parsed out of
`ChillMate/SubstanceInteractions.swift` and the translations are read out of
`ChillMate/Localizable.xcstrings`, which means the demo cannot drift from the
product and cannot quietly soften a warning.

    python3 tools/extract_interactions.py

Writes tools/interactions.json, which is committed so a site build needs no
access to the Swift sources.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT = ROOT / "ChillMate" / "SubstanceInteractions.swift"
MEDS = ROOT / "ChillMate" / "MedicationRiskData.swift"
CHECKER = ROOT / "ChillMate" / "CombinationRiskCheckerView.swift"
SUBSTANCE = ROOT / "ChillMate" / "Substance.swift"
CATALOG = ROOT / "ChillMate" / "Localizable.xcstrings"
OUT = Path(__file__).resolve().parent / "interactions.json"

LANGS = ["en", "nl", "de", "fr", "es"]

# The three severities, as the app spells them.
LEVEL_LABELS = {
    "caution": "Worth noting",
    "serious": "Significant risk",
    "critical": "High-risk combination",
}

# Everything the picker offers. "Unknown" and "Other" are in the app's enum but
# carry no documented interactions, so they would only ever produce an empty
# result on the web and are left out of the demo.
PICKABLE = ["Cannabis", "Alcohol", "MDMA", "3MMC", "Ketamine", "GHB", "GBL",
            "Cocaine", "Poppers", "Kamagra", "Viagra", "Psychedelics"]


def load_catalog() -> dict:
    """{source string: {lang: translation}} from the String Catalog."""
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    out = {}
    for key, entry in data.get("strings", {}).items():
        locs = entry.get("localizations", {})
        if not locs:
            continue
        by_lang = {}
        for lang, payload in locs.items():
            unit = payload.get("stringUnit", {})
            if unit.get("value"):
                by_lang[lang] = unit["value"]
        if by_lang:
            out[key] = by_lang
    return out


def translations(catalog: dict, english: str) -> dict:
    """Every language for one source string, falling back to English."""
    found = catalog.get(english, {})
    return {lang: found.get(lang, english) for lang in LANGS}


def substance_names() -> dict:
    """Swift case name to the display string, e.g. threeMMC -> 3MMC."""
    text = SUBSTANCE.read_text(encoding="utf-8")
    body = text[text.index("enum Substance"):]
    body = body[:body.index("var id:")]
    return dict(re.findall(r'case\s+(\w+)\s*=\s*"([^"]+)"', body))


def parse_rules(names: dict) -> list:
    text = SWIFT.read_text(encoding="utf-8")
    rules = []
    pattern = re.compile(
        r"SubstanceInteraction\(\s*"
        r"substances:\s*\[([^\]]+)\],\s*"
        r"level:\s*\.(\w+),\s*"
        r'warning:\s*String\(localized:\s*"((?:[^"\\]|\\.)*)"\)',
        re.S,
    )
    for raw_substances, level, warning in pattern.findall(text):
        cases = re.findall(r"\.(\w+)", raw_substances)
        display = [names[c] for c in cases if c in names]
        if len(display) != len(cases):
            missing = [c for c in cases if c not in names]
            sys.exit(f"Unknown substance case(s) in the interaction table: {missing}")
        rules.append({
            "substances": sorted(display),
            "level": level,
            "english": warning.encode().decode("unicode_escape"),
        })
    return rules


def medication_categories(catalog: dict) -> list:
    """Every medication group the checker recognises, with its search terms.

    Small enough to carry whole (eight groups, about sixty aliases), which is
    what lets the website match a typed prescription the same way the app does
    rather than approximating it.
    """
    text = MEDS.read_text(encoding="utf-8")

    labels = {}
    block = text[text.index("var label: String"):text.index("var aliases")]
    for case, value in re.findall(r'case \.(\w+):\s*\n\s*String\(localized: "([^"]+)"\)', block):
        labels[case] = value

    aliases = {}
    block = text[text.index("var aliases"):text.index("enum MedicationRiskDatabase")]
    for case, body in re.findall(r'case \.(\w+):\s*\n\s*\[(.*?)\]', block, re.S):
        aliases[case] = re.findall(r'"([^"]+)"', body)

    return [{"key": key, "label": translations(catalog, labels[key]), "aliases": aliases.get(key, [])}
            for key in labels if aliases.get(key)]


def assessment_details(catalog: dict) -> dict:
    """The three standing checks, and what the app says at each level."""
    text = CHECKER.read_text(encoding="utf-8")
    out = {}
    for key, prop in [("serotonin", "serotoninDetail"),
                      ("dehydration", "dehydrationDetail"),
                      ("stimulant", "stimulantDetail")]:
        block = text[text.index(f"var {prop}: String"):]
        block = block[:block.index("\n    }")]
        levels = {}
        for level, value in re.findall(r'case \.(\w+):\s*\n\s*String\(localized: "((?:[^"\\]|\\.)*)"\)', block):
            levels[level] = translations(catalog, value.encode().decode("unicode_escape"))
        out[key] = levels
    return out


ASSESSMENT_TITLES = {
    "serotonin": "Serotonin syndrome",
    "dehydration": "Dehydration",
    "stimulant": "Stimulant overload",
}
RISK_LABELS = {"lower": "No known", "caution": "Caution", "high": "Higher risk"}
TIMINGS = [("sameSession", "Same session"), ("withinSixHours", "6 h"), ("withinDay", "24 h")]


def main():
    for path in (SWIFT, SUBSTANCE, CATALOG):
        if not path.exists():
            sys.exit(f"missing {path}")

    catalog = load_catalog()
    names = substance_names()
    rules = parse_rules(names)
    if not rules:
        sys.exit("parsed zero interaction rules; the Swift shape must have changed")

    payload = {
        "note": ("Generated by tools/extract_interactions.py from "
                 "ChillMate/SubstanceInteractions.swift. Do not edit by hand."),
        "substances": PICKABLE,
        "levels": {key: translations(catalog, label)
                   for key, label in LEVEL_LABELS.items()},
        "medication": medication_categories(catalog),
        "assessments": {
            key: {"title": translations(catalog, ASSESSMENT_TITLES[key]), "levels": levels}
            for key, levels in assessment_details(catalog).items()
        },
        "riskLabels": {k: translations(catalog, v) for k, v in RISK_LABELS.items()},
        "timings": [{"key": k, "label": translations(catalog, v)} for k, v in TIMINGS],
        "rules": [{"substances": r["substances"],
                   "level": r["level"],
                   "warning": translations(catalog, r["english"])}
                  for r in rules],
    }

    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    by_level = {}
    for rule in payload["rules"]:
        by_level[rule["level"]] = by_level.get(rule["level"], 0) + 1
    translated = sum(
        1 for r in payload["rules"]
        if all(r["warning"][l] != r["warning"]["en"] for l in ("nl", "de", "fr", "es"))
    )
    print(f"{len(payload['rules'])} rules  {by_level}")
    print(f"{len(payload['medication'])} medication groups, "
          f"{sum(len(m['aliases']) for m in payload['medication'])} search terms")
    print(f"{len(payload['assessments'])} standing assessments")
    print(f"{translated} fully translated into all four other languages")
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
