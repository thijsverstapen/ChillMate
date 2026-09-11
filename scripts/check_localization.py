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
    # The Live Activity extension's catalog was checked for completeness and its
    # sources were not checked against it at all, so a literal added here was
    # under no gate. That extension draws the Lock Screen and the Dynamic Island,
    # which is the most-read surface in the app and the one a person looks at
    # when they are least able to translate in their head.
    ("ChillMateLiveActivityExtension", ROOT / "ChillMateLiveActivityExtension/Localizable.xcstrings"),
]

# Explicit localization, plus the places Apple takes a `LocalizedStringResource`.
#
# These match the *prefix* only and stop at the opening quote. The literal itself
# is then read by `scan_literal`, because a regex cannot read a Swift string: an
# interpolation may contain string literals of its own
# (`"\\(count) picture\\(count == 1 ? "" : "s") attached"`), and a pattern that
# stops at the first quote captures a fragment and silently checks the wrong text.
LITERAL_PREFIXES = [
    re.compile(r'String\(\s*localized:\s*(?=")'),
    # A widget's name and blurb in the gallery. These are `LocalizedStringResource`
    # parameters, so Xcode extracts them into the catalog like any other string —
    # but nothing checked they were there, and they are the only words a person
    # reads while deciding whether to add the widget at all.
    re.compile(r'\.configurationDisplayName\(\s*(?=")'),
    re.compile(r'\.displayName\(\s*(?=")'),
    re.compile(r'\.description\(\s*(?=")'),
    # App Intents. Every one of these is read aloud by Siri or shown in the
    # Shortcuts gallery, and none of them was under any gate — the titles happened
    # to be translated because somebody added them by hand.
    #
    # `DisplayRepresentation` is included even though most of the app's are drug
    # and brand names that read the same in five languages: "Unknown" and "Other"
    # sit in the same list and do not, and they were reaching the Shortcuts
    # parameter picker in English. A name that translates to itself costs one
    # catalog entry; a name that does not and is unchecked costs a reader.
    re.compile(r'\bIntentDescription\(\s*(?=")'),
    re.compile(r'LocalizedStringResource\s*=\s*(?=")'),
    re.compile(r'\bshortTitle:\s*(?=")'),
    re.compile(r'\bParameter\(\s*title:\s*(?=")'),
    re.compile(r'\bDisplayRepresentation\(\s*title:\s*(?=")'),
]

# An App Intents parameter summary. `Summary("Check \\(\\.$first) with \\(\\.$second)")`
# is extracted as "Check ${first} with ${second}", so the key-path form has to be
# rewritten before the generic interpolation stripping blanks it away — otherwise
# both sides reduce to "Check  with " and the check passes on nothing.
SUMMARY_PREFIX = re.compile(r'\bSummary\(\s*(?=")')
PARAMETER_KEYPATH = re.compile(r'\\\(\\\.\$(\w+)\)')

UNICODE_ESCAPE = re.compile(r"\\u\{([0-9A-Fa-f]+)\}")


# SwiftUI controls whose first argument is a label the framework localizes.
#
# Matching a fixed shape was not enough. `Text("Home")` was checked and
# `Text(arrived ? "Home" : "Getting home")` was not, because the pattern wanted a
# quote straight after the bracket — a literal only had to sit inside a ternary
# to escape the gate entirely. Picker, Toggle, TextField and Stepper labels were
# not checked at all, and VoiceOver reads every one of them.
#
# So the first argument is extracted by bracket counting and every literal inside
# it is checked, whatever shape it is in. Only the first: `Label("Log water",
# systemImage: "drop.fill")` must not put an SF Symbol name under translation.
LABELLED_CALLS = ("Text", "Label", "Button", "Picker", "Toggle", "TextField", "Stepper", "NavigationLink")
LABELLED_CALL = re.compile(r"\b(" + "|".join(LABELLED_CALLS) + r")\(")


def scan_literal(text, quote_index):
    """The contents of the Swift string literal whose opening quote is at
    `quote_index`.

    Interpolation-aware, so `"\\(n) picture\\(n == 1 ? "" : "s") attached"` comes
    back whole rather than truncated at the first inner quote.
    """
    index = quote_index + 1
    start = index
    while index < len(text):
        character = text[index]
        if character == "\\":
            if index + 1 < len(text) and text[index + 1] == "(":
                index = skip_interpolation(text, index + 1)
                continue
            index += 2
            continue
        if character == '"':
            return text[start:index]
        index += 1
    return text[start:]


def skip_interpolation(text, open_paren):
    """The index just past the `)` closing an interpolation, nested strings and
    all."""
    index = open_paren + 1
    depth = 0
    while index < len(text):
        character = text[index]
        if character == '"':
            index = skip_string(text, index)
            continue
        if character == "(":
            depth += 1
        elif character == ")":
            if depth == 0:
                return index + 1
            depth -= 1
        index += 1
    return index


def skip_string(text, quote_index):
    """The index just past the closing quote of a string literal."""
    index = quote_index + 1
    while index < len(text):
        character = text[index]
        if character == "\\":
            if index + 1 < len(text) and text[index + 1] == "(":
                index = skip_interpolation(text, index + 1)
                continue
            index += 2
            continue
        if character == '"':
            return index + 1
        index += 1
    return index


def top_level_literals(source):
    """Every string literal in `source` that is not nested inside another one.

    A literal inside an interpolation is part of the enclosing string as far as
    translation goes — the `"" : "s"` plural hack is the common case — so it is
    covered by the outer literal and must not be reported on its own.
    """
    literals = []
    index = 0
    while index < len(source):
        if source[index] == '"':
            literals.append((scan_literal(source, index), index))
            index = skip_string(source, index)
            continue
        index += 1
    return literals



def first_argument(text, open_paren):
    """The source of a call's first argument, given the index of its '('.

    A plain bracket counter is not enough and a quote-aware one is not either.
    Swift string interpolation nests a *code* context inside a *string* context —
    `Text(a ? String(localized: "x \\(y)") : "z")` — so a scanner that treats the
    first quote inside an interpolation as closing the string desynchronises and
    returns half an argument. That produced fragments like `") : String(localized: "`
    as candidate user-facing strings.

    So the state is a stack: strings push, interpolations push a nested code
    context, and only the outermost code context decides where the argument ends.
    """
    start = open_paren + 1
    index = start
    depth = 0
    stack = []
    while index < len(text):
        character = text[index]

        if stack and stack[-1][0] == "string":
            if character == "\\":
                if index + 1 < len(text) and text[index + 1] == "(":
                    stack.append(["interp", 0])
                    index += 2
                    continue
                index += 2
                continue
            if character == '"':
                stack.pop()
            index += 1
            continue

        if character == '"':
            stack.append(["string"])
        elif character in "([{":
            if stack:
                stack[-1][1] += 1
            else:
                depth += 1
        elif character in ")]}":
            if stack:
                if stack[-1][1] == 0:
                    stack.pop()
                else:
                    stack[-1][1] -= 1
            elif depth == 0:
                return text[start:index]
            else:
                depth -= 1
        elif character == "," and depth == 0 and not stack:
            return text[start:index]
        index += 1
    return None


def labelled_literals(text):
    """Every user-facing literal in a SwiftUI control's label position.

    Yields (literal, source offset) pairs. `Text(verbatim:)` is skipped: that
    overload exists precisely to say "this is not language", and the app uses it
    for empty navigation titles.
    """
    for match in LABELLED_CALL.finditer(text):
        argument = first_argument(text, match.end() - 1)
        if argument is None or argument.lstrip().startswith("verbatim:"):
            continue
        for literal, _ in top_level_literals(argument):
            yield literal, match.start()


FORMAT_SPECIFIER = re.compile(r"%(?:\d+\$)?(?:@|lld|ld|d|f|\.\d+f)")


def strip_interpolations(text):
    """Replace every `\\(...)` with a placeholder, counting brackets.

    A regex cannot do this: real interpolations nest several levels deep, as in
    `\\(hours.formatted(.number.precision(.fractionLength(0...1))))`, and a pattern
    that only handles one level leaves a tail of stray brackets behind and makes
    every such string look like it is missing from the catalog.
    """
    out = []
    index = 0
    while index < len(text):
        if text.startswith("\\(", index):
            depth = 0
            cursor = index + 1
            while cursor < len(text):
                if text[cursor] == "(":
                    depth += 1
                elif text[cursor] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                cursor += 1
            out.append("\x00")
            index = cursor + 1
        else:
            out.append(text[index])
            index += 1
    return "".join(out)


def interpolation_shape(text):
    """A string reduced to its literal parts, with every placeholder blanked.

    `"Started a \\(hours) hour timer"` and `"Started a %lld hour timer"` reduce to
    the same thing, which is what lets a source literal be matched against the
    catalog key Xcode extracted from it without having to infer the argument's
    type from the source.
    """
    return FORMAT_SPECIFIER.sub("\x00", strip_interpolations(swift_literal_value(text)))


def swift_literal_value(raw):
    """The runtime string for a Swift literal, which is what Xcode uses as the key.

    `\\u{00A0}` matters: an onboarding headline binds its last two words with a
    non-breaking space, and a checker that compares the raw source text instead of
    the decoded value reports a false miss for it.
    """
    text = raw.replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t")
    text = UNICODE_ESCAPE.sub(lambda m: chr(int(m.group(1), 16)), text)
    return text.replace("\\\\", "\\")


# An enum rawValue rendered straight into the interface.
#
# `localizedDisplayName` exists precisely for this — it resolves a String-backed
# enum's rawValue through the catalog — and six places passed `.rawValue`
# instead. The translations were all sitting in the catalog; nothing was reading
# them, so Dutch readers got "Horny", "Lonely" and "Privacy & lock". Nothing
# caught it because a rawValue is not a literal, so no literal check could see it.
RAW_VALUE_RENDER = re.compile(
    r"(?:\b(?:title|subtitle|label|name|text|message):\s*|\bText\(\s*)"
    r"([A-Za-z_][\w]*(?:\.[A-Za-z_][\w]*)*\.rawValue)\b"
)


def check_raw_value_rendering(directory):
    """No enum rawValue may be rendered directly; use `localizedDisplayName`."""
    findings = []
    for source in sorted((ROOT / directory).glob("*.swift")):
        text = source.read_text()
        for match in RAW_VALUE_RENDER.finditer(text):
            line = text[:match.start()].count("\n") + 1
            findings.append(
                f"{directory}/*.swift: {source.name}:{line} renders {match.group(1)} "
                "directly; use .localizedDisplayName so the catalog translation is used"
            )
    return findings


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
    # Every catalog key reduced to its literal parts, so an interpolated source
    # literal can be matched against it without knowing the argument types.
    shapes = {interpolation_shape(key) for key in keys}

    checked = 0
    for source in sorted((ROOT / directory).glob("*.swift")):
        text = source.read_text()
        for match in SUMMARY_PREFIX.finditer(text):
            raw = scan_literal(text, match.end())
            if not raw.strip():
                continue
            checked += 1
            line = text[:match.start()].count("\n") + 1
            # No shape matching needed: a parameter summary's key is knowable
            # exactly, because the key path is extracted verbatim as ${name}.
            key = swift_literal_value(PARAMETER_KEYPATH.sub(r"${\1}", raw))
            if key not in keys:
                absent.setdefault(key, f"{source.name}:{line}")

        candidates = [
            (scan_literal(text, match.end()), match.start())
            for pattern in LITERAL_PREFIXES
            for match in pattern.finditer(text)
        ]
        candidates.extend(labelled_literals(text))

        for raw, offset in candidates:
                if not raw.strip() or not re.sub(r"[\s\W\x00]+", "", interpolation_shape(raw)):
                    continue
                checked += 1
                line = text[:offset].count("\n") + 1

                if "\\(" in raw:
                    # Nothing but placeholders and punctuation: no words to
                    # translate, the same rule `needs_no_translation` applies on
                    # the catalog side.
                    if not re.sub(r"[\s\W\x00]+", "", interpolation_shape(raw)):
                        continue
                    # Interpolation becomes a %@ / %lld key at extraction, and the
                    # source text cannot say which. So the literal parts are
                    # matched instead: a catalog key whose non-specifier text is
                    # identical is the same string.
                    #
                    # This used to be skipped entirely, which left every
                    # interpolated string ungated. Eight of them had been shipping
                    # in English, including the line telling somebody their PEP
                    # window was still open.
                    if interpolation_shape(raw) not in shapes:
                        absent.setdefault(swift_literal_value(raw), f"{source.name}:{line}")
                    continue

                key = swift_literal_value(raw)
                if key not in keys:
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
    failures.extend(check_raw_value_rendering(source_directory))

if failures:
    print("\nLocalization check failed:")
    for failure in failures:
        print(f"  - {failure}")
    sys.exit(1)

print("\nLocalization check passed.")
