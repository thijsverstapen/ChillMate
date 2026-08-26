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

ROOT = pathlib.Path(__file__).resolve().parent.parent

# The source language is deliberately excluded: in a String Catalog the key *is*
# the source string, so Xcode omits an explicit "en" entry for most keys.
REQUIRED = {"nl", "de", "fr", "es"}
# Every catalog that ships. The watch complication's was missing, so the strings
# on the one surface a user glances at without unlocking were unchecked.
CATALOGS = [
    ROOT / "ChillMate/Localizable.xcstrings",
    ROOT / "ChillMate/InfoPlist.xcstrings",
    ROOT / "ChillMateWatchApp/Localizable.xcstrings",
    ROOT / "ChillMateWatchAppWidget/Localizable.xcstrings",
    # Added in 4.3.0. The Live Activity extension shipped with no catalog at
    # all, so its strings were English on every device and nothing caught it.
    ROOT / "ChillMateLiveActivityExtension/Localizable.xcstrings",
]
SPECIFIER = re.compile(r"%(?:\d+\$)?(?:@|lld|ld|d|f|\.\d+f)")

failures = []


def needs_no_translation(key, entry):
    """True for keys there is genuinely nothing to translate in.

    Two forms: the ones Xcode marks shouldTranslate=false (the app name), and the
    ones that are pure format specifiers once stripped ("%lld", "%@ %@"), which
    the watch complication ships untranslated because there is no word in them.
    """
    if entry.get("shouldTranslate") is False:
        return True
    return not SPECIFIER.sub("", key).strip()


def is_translated(localizations, language):
    """True when this language carries usable text for the key.

    A language present but holding an empty string is a missing translation
    wearing a disguise: it ships as a blank label rather than falling back to
    English. Entries with variations (plurals, device sizes) carry no top-level
    stringUnit and are taken at face value.
    """
    localization = localizations.get(language)
    if localization is None:
        return False
    unit = localization.get("stringUnit")
    if unit is None:
        return True
    return bool(unit.get("value", "").strip())


def check(path):
    label = path.relative_to(ROOT)

    if not path.exists():
        print(f"  skip (absent): {label}")
        return

    try:
        catalog = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        failures.append(f"{label}: invalid JSON, {error}")
        return

    strings = catalog.get("strings", {})
    if "" in strings:
        failures.append(f"{label}: contains an empty key")

    missing = 0
    mismatched = 0
    for key, entry in strings.items():
        if needs_no_translation(key, entry):
            continue
        localizations = entry.get("localizations", {})

        absent = {
            language for language in REQUIRED
            if not is_translated(localizations, language)
        }
        if absent:
            missing += 1
            if missing <= 10:
                failures.append(f"{label}: {key[:60]!r} missing {sorted(absent)}")

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
                        f"{label}: {key[:44]!r} [{language}] has {found} format "
                        f"specifiers, key has {expected}"
                    )

    if missing > 10:
        failures.append(f"{label}: and {missing - 10} more keys missing a language")
    if mismatched > 10:
        failures.append(f"{label}: and {mismatched - 10} more specifier mismatches")

    print(f"  {label}: {len(strings)} keys, {missing} incomplete, {mismatched} mismatched")


# Source directories whose localized literals must resolve in the named catalog.
SOURCE_CATALOGS = [
    ("ChillMate", ROOT / "ChillMate/Localizable.xcstrings"),
    ("ChillMateWatchApp", ROOT / "ChillMateWatchApp/Localizable.xcstrings"),
    ("ChillMateWatchAppWidget", ROOT / "ChillMateWatchAppWidget/Localizable.xcstrings"),
]

# The four shapes that localize a bare literal. SwiftUI localizes Text, Label and
# Button labels implicitly, so a literal in any of them is just as user-facing as
# an explicit String(localized:).
LITERAL_PATTERNS = [
    re.compile(r'String\(\s*localized:\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'\bText\(\s*"((?:[^"\\]|\\.)*)"\s*\)'),
    re.compile(r'\bLabel\(\s*"((?:[^"\\]|\\.)*)"\s*,'),
    re.compile(r'\bButton\(\s*"((?:[^"\\]|\\.)*)"\s*\)'),
]
UNICODE_ESCAPE = re.compile(r"\\u\{([0-9A-Fa-f]+)\}")


def swift_literal_value(raw):
    """The runtime string for a Swift literal, which is what Xcode uses as the key.

    `\\u{00A0}` matters: an onboarding headline binds its last two words with a
    non-breaking space, and a checker that compares the raw source text instead of
    the decoded value reports a false miss for it.
    """
    text = raw.replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t")
    text = UNICODE_ESCAPE.sub(lambda m: chr(int(m.group(1), 16)), text)
    return text.replace("\\\\", "\\")


def check_sources(directory, catalog_path):
    """Every localized literal in source must exist as a catalog key.

    The completeness check above only inspects keys that are already in the
    catalog, so a string that never got extracted was invisible to it: fully
    translated catalog, and the string still renders in English for every other
    language. That is how 27 strings shipped untranslated, 14 of them the risk
    checker's combination warnings, which is the last place to silently fall back
    to a language the reader may not have.
    """
    label = f"{directory}/*.swift"
    if not catalog_path.exists():
        return

    keys = set(json.loads(catalog_path.read_text()).get("strings", {}))
    absent = {}
    checked = 0
    for source in sorted((ROOT / directory).glob("*.swift")):
        text = source.read_text()
        for pattern in LITERAL_PATTERNS:
            for match in pattern.finditer(text):
                raw = match.group(1)
                # Interpolation resolves to the %lld / %@ key Xcode extracts, which
                # cannot be derived from the source text, so it is left to the
                # specifier check above.
                if "\\(" in raw or not raw.strip():
                    continue
                checked += 1
                key = swift_literal_value(raw)
                if key not in keys:
                    line = text[:match.start()].count("\n") + 1
                    absent.setdefault(key, f"{source.name}:{line}")

    for key, where in list(absent.items())[:10]:
        failures.append(f"{label}: {where} {key[:60]!r} is not in the catalog")
    if len(absent) > 10:
        failures.append(f"{label}: and {len(absent) - 10} more literals not in the catalog")

    print(f"  {label}: {checked} localized literals, {len(absent)} not in catalog")


for catalog_path in CATALOGS:
    check(catalog_path)

for source_directory, source_catalog in SOURCE_CATALOGS:
    check_sources(source_directory, source_catalog)

if failures:
    print("\nLocalization check failed:")
    for failure in failures:
        print(f"  - {failure}")
    sys.exit(1)

print("\nLocalization check passed.")
