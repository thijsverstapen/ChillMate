#!/usr/bin/env python3
"""Add keys to a String Catalog with all four translations in one go.

Reads a JSON file of the shape:

    {
      "Some key": {
        "comment": "where it appears",
        "nl": "...", "de": "...", "fr": "...", "es": "..."
      },
      "%lld things": {
        "comment": "...",
        "plural": {
          "nl": {"one": "%lld ding", "other": "%lld dingen"},
          ...
        }
      }
    }

English is the key itself and is never stored, which is how a String Catalog
works. Existing keys are left alone rather than overwritten, so re-running is
safe. `scripts/check_localization.py` is the gate this feeds.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGUAGES = ("de", "es", "fr", "nl")


def main() -> int:
    additions = json.loads(pathlib.Path(sys.argv[1]).read_text())
    catalog_path = ROOT / (sys.argv[2] if len(sys.argv) > 2 else "ChillMate/Localizable.xcstrings")
    catalog = json.loads(catalog_path.read_text())
    strings = catalog["strings"]

    added = skipped = 0
    for key, spec in additions.items():
        if key in strings:
            skipped += 1
            continue

        localizations = {}
        for language in LANGUAGES:
            if "plural" in spec:
                forms = spec["plural"][language]
                localizations[language] = {
                    "variations": {
                        "plural": {
                            form: {"stringUnit": {"state": "translated", "value": value}}
                            for form, value in forms.items()
                        }
                    }
                }
            else:
                localizations[language] = {
                    "stringUnit": {"state": "translated", "value": spec[language]}
                }

        entry = {"localizations": localizations}
        if spec.get("comment"):
            entry["comment"] = spec["comment"]
        strings[key] = entry
        added += 1

    catalog["strings"] = dict(sorted(strings.items()))
    catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
    print(f"{catalog_path.name}: added {added}, already present {skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
