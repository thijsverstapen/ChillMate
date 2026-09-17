#!/usr/bin/env python3
"""Generate tools/interactions.json from the app's own interaction table.

The site kept a second, hand-maintained copy of the combination table. By
5.0.0 it had drifted badly: thirty rules against the app's ninety-one, and four
of those thirty rated a step *lower* than the app — including three pairs the
app had raised to critical. The risk-checker page is the one people reach by
searching "GHB and alcohol" at two in the morning, so the stale copy was the
one strangers saw.

This removes the class of problem rather than the instance. The rules, the
severities and all five languages come from `SubstanceInteractions.swift` and
`Localizable.xcstrings`; the corroboration column comes from
`InteractionChart.swift`. Everything else in the file — the medication groups,
the assessment copy, the timings — is hand-written and is carried through
untouched.

Run it after changing the table, then rebuild the site:

    python3 tools/build_interactions_json.py
    python3 tools/build_site.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGUAGES = ("en", "nl", "de", "fr", "es")

# Swift case name -> the display name the site uses, which is the enum's raw value.
RAW_VALUES = re.compile(r'case (\w+) = "([^"]+)"')

RULE = re.compile(
    r'substances: \[\.(\w+), \.(\w+)\],\s*\n'
    r'\s*level: \.(\w+),\s*\n'
    r'\s*warning: String\(localized: "((?:[^"\\]|\\.)*)"\)',
    re.MULTILINE,
)

CHART_ENTRY = re.compile(r'"([^"]+)": Entry\(grading: \.(\w+), isApproximate: (\w+)\)')

# Matches SubstanceInteraction.Corroboration. The site says the same thing the
# app's own rows say, in the same words.
CORROBORATION = {
    "matchesChart": {
        "en": "Matches TripSit’s combination chart",
        "nl": "Komt overeen met de combinatiekaart van TripSit",
        "de": "Stimmt mit TripSits Kombinationstabelle überein",
        "fr": "Correspond au tableau des combinaisons de TripSit",
        "es": "Coincide con la tabla de combinaciones de TripSit",
    },
    "matchesChartApproximately": {
        "en": "Matches TripSit’s chart for a closely related substance",
        "nl": "Komt overeen met TripSits kaart voor een nauw verwante stof",
        "de": "Stimmt mit TripSits Tabelle für einen nah verwandten Stoff überein",
        "fr": "Correspond au tableau de TripSit pour une substance proche",
        "es": "Coincide con la tabla de TripSit para una sustancia muy relacionada",
    },
    "ratedAboveChart": {
        "en": "Rated higher here than on TripSit’s chart",
        "nl": "Hier hoger ingeschat dan op TripSits kaart",
        "de": "Hier höher eingestuft als in TripSits Tabelle",
        "fr": "Évalué plus haut ici que sur le tableau de TripSit",
        "es": "Calificado más alto aquí que en la tabla de TripSit",
    },
    "notOnChart": {
        "en": "Not on TripSit’s chart",
        "nl": "Staat niet op TripSits kaart",
        "de": "Nicht in TripSits Tabelle",
        "fr": "Absent du tableau de TripSit",
        "es": "No está en la tabla de TripSit",
    },
}

GRADE_RANK = {"lowRisk": 0, "caution": 1, "serious": 2, "critical": 3}
LEVEL_RANK = {"caution": 1, "serious": 2, "critical": 3}


def catalog_lookup(strings, key):
    """All five languages for one catalog key.

    English is the key: a String Catalog stores no entry whose value equals it.
    """
    out = {"en": key}
    localizations = (strings.get(key) or {}).get("localizations", {})
    for language in LANGUAGES[1:]:
        unit = (localizations.get(language) or {}).get("stringUnit") or {}
        value = unit.get("value")
        if not value:
            raise SystemExit(f"no {language} translation for: {key[:70]}…")
        out[language] = value
    return out


def main() -> int:
    swift = (ROOT / "ChillMate/SubstanceInteractions.swift").read_text()
    substance_swift = (ROOT / "ChillMate/Substance.swift").read_text()
    chart_swift = (ROOT / "ChillMate/InteractionChart.swift").read_text()
    strings = json.loads((ROOT / "ChillMate/Localizable.xcstrings").read_text())["strings"]

    names = dict(RAW_VALUES.findall(substance_swift))
    chart = {k: (g, a == "true") for k, g, a in CHART_ENTRY.findall(chart_swift)}
    chart_keys = dict(re.findall(r'case \.(\w+): "(\w+)"', substance_swift))

    rules = []
    for first, second, level, warning in RULE.findall(swift):
        key = warning.replace('\\"', '"')
        pair = sorted([names[first], names[second]])

        chart_key = "+".join(sorted([chart_keys[first], chart_keys[second]]))
        entry = chart.get(chart_key)
        if entry is None:
            corroboration = "notOnChart"
        elif GRADE_RANK[entry[0]] == LEVEL_RANK[level]:
            corroboration = "matchesChartApproximately" if entry[1] else "matchesChart"
        else:
            corroboration = "ratedAboveChart"

        rules.append({
            "substances": pair,
            "level": level,
            "corroboration": corroboration,
            "warning": catalog_lookup(strings, key),
        })

    rules.sort(key=lambda r: (-LEVEL_RANK[r["level"]], r["substances"]))

    path = ROOT / "tools/interactions.json"
    data = json.loads(path.read_text())
    before = len(data["rules"])
    data["rules"] = rules
    data["corroborationLabels"] = CORROBORATION
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

    print(f"tools/interactions.json: {before} rules -> {len(rules)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
