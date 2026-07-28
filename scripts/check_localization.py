#!/usr/bin/env python3
"""Verify the String Catalogs are complete and well formed.

Guards the class of defect found in the 4.2.1 audit: keys shipped with no
translation in four of five languages, a stray empty key, and format specifiers
that disagree between languages (which crashes at format time rather than
degrading).
"""
import json
import pathlib
import re
import sys

# The source language is deliberately excluded: in a String Catalog the key *is*
# the source string, so Xcode omits an explicit "en" entry for most keys.
REQUIRED = {"nl", "de", "fr", "es"}
CATALOGS = [
    pathlib.Path("ChillMate/Localizable.xcstrings"),
    pathlib.Path("ChillMate/InfoPlist.xcstrings"),
    pathlib.Path("ChillMateWatchApp/Localizable.xcstrings"),
]
SPECIFIER = re.compile(r"%(?:\d+\$)?(?:@|lld|ld|d|f|\.\d+f)")

failures = []


def check(path):
    if not path.exists():
        print(f"  skip (absent): {path}")
        return

    try:
        catalog = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        failures.append(f"{path}: invalid JSON — {error}")
        return

    strings = catalog.get("strings", {})
    if "" in strings:
        failures.append(f"{path}: contains an empty key")

    missing = 0
    mismatched = 0
    for key, entry in strings.items():
        # Keys flagged shouldTranslate=false (a bare number format, the app name)
        # are correct without translations.
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})

        absent = REQUIRED - set(localizations)
        if absent:
            missing += 1
            if missing <= 10:
                failures.append(f"{path}: {key[:60]!r} missing {sorted(absent)}")

        expected = len(SPECIFIER.findall(key))
        if expected == 0:
            continue
        for language, localization in localizations.items():
            unit = localization.get("stringUnit")
            if not unit:
                continue  # plural/device variations carry their own units
            found = len(SPECIFIER.findall(unit["value"]))
            if found != expected:
                mismatched += 1
                if mismatched <= 10:
                    failures.append(
                        f"{path}: {key[:44]!r} [{language}] has {found} format "
                        f"specifiers, key has {expected}"
                    )

    if missing > 10:
        failures.append(f"{path}: … and {missing - 10} more keys missing a language")
    if mismatched > 10:
        failures.append(f"{path}: … and {mismatched - 10} more specifier mismatches")

    print(f"  {path}: {len(strings)} keys, {missing} incomplete, {mismatched} mismatched")


for catalog_path in CATALOGS:
    check(catalog_path)

if failures:
    print("\nLocalization check failed:")
    for failure in failures:
        print(f"  - {failure}")
    sys.exit(1)

print("\nLocalization check passed.")
