#!/usr/bin/env python3
"""Fail when a UserDefaults key is written as a bare string literal.

Keys used to be repeated at each call site, and a typo bound silently to a
different key that read back as false or "" rather than failing, which is how
the reduce-motion setting came to be advertised app-wide while only onboarding
read it. DefaultsKey (and WidgetSharedKey, for keys crossing target boundaries)
is the registry; this keeps new code from drifting back.

Every product target is scanned, not just the app. The phone app, the watch app,
the watch complication and the Live Activity extension read and write the same
App Group suite, so a key spelled slightly differently at one end is exactly the
drift this exists to catch, and those three extension targets were the ones the
check could not see: it globbed ChillMate/*.swift alone.

A key hidden behind a local constant (`private let hydrationCountKey =
"watchHydrationCount"`) is just as invisible to the registry as one written at
the call site, so declarations are matched too, not only call sites.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Every target that ships code. Test targets are deliberately absent: a test may
# legitimately write a raw key to set up or assert on stored state.
TARGETS = [
    "ChillMate",
    "ChillMateWatchApp",
    "ChillMateWatchAppWidget",
    "ChillMateLiveActivityExtension",
]

# Literals that are not UserDefaults keys despite matching a pattern.
ALLOWED = {
    # UIPrintPageRenderer KVC, not defaults.
    "paperRect",
    "printableRect",
    # Legacy keys, read only by the migration path that deletes them.
    "appPINHash",
    "appPINSalt",
    # Keychain account, not a defaults key.
    "encryptedBackupDeviceID",
}

# The registries themselves, which exist to hold these literals.
EXEMPT_FILES = {"DefaultsKeys.swift", "WidgetSharedKeys.swift"}

# Matched line by line. Each pattern captures the key literal in group 1.
PATTERNS = [
    re.compile(r'@AppStorage\(\s*"([^"]*)"'),
    re.compile(r'forKey:\s*"([^"]*)"'),
    re.compile(r'suiteName:\s*"([^"]*)"'),
    # A constant whose name ends in "Key" (or is exactly "key") holding a string
    # literal is a defaults key by every convention this codebase uses. Requiring
    # the name to *end* there keeps `keychainService` and friends out.
    re.compile(r'\b(?:let|var)\s+(?:[A-Za-z_][A-Za-z0-9_]*Key|key)\b\s*(?::\s*String\s*)?=\s*"([^"]*)"'),
]

# `register(defaults:)` seeds a whole dictionary of keys at once and is normally
# written across several lines, so it is matched against the whole file.
REGISTER = re.compile(r"register\(defaults:\s*\[(.*?)\]", re.S)
DICTIONARY_KEY = re.compile(r'"([^"]*)"\s*:')


def is_violation(literal):
    """True when this captured literal is a key that belongs in the registry.

    Interpolated literals ("spotlightHash-\\(id)") are skipped: a computed key
    cannot be a plain registry constant, so flagging it could only nag, never
    suggest a fix, and it is also how the NSCache keys produce false matches.
    """
    return literal not in ALLOWED and "\\(" not in literal and literal != ""


def scan(path):
    """Yield 'file:line: match' for every bare key literal in one Swift file."""
    text = path.read_text()
    relative = path.relative_to(ROOT)

    for number, line in enumerate(text.split("\n"), 1):
        for pattern in PATTERNS:
            for match in pattern.finditer(line):
                if is_violation(match.group(1)):
                    yield f"{relative}:{number}: {match.group(0).strip()}"

    for block in REGISTER.finditer(text):
        line = text.count("\n", 0, block.start()) + 1
        for match in DICTIONARY_KEY.finditer(block.group(1)):
            if is_violation(match.group(1)):
                yield f"{relative}:{line}: register(defaults:) key {match.group(0)}"


violations = []
for target in TARGETS:
    directory = ROOT / target
    if not directory.is_dir():
        print(f"  skip (absent): {target}")
        continue

    files = sorted(directory.rglob("*.swift"))
    print(f"  {target}: {len(files)} Swift files")
    for source in files:
        if source.name in EXEMPT_FILES:
            continue
        violations.extend(scan(source))

if violations:
    print("\nUserDefaults keys must come from DefaultsKey or WidgetSharedKey:")
    for violation in violations:
        print(f"  - {violation}")
    sys.exit(1)

print("\nDefaults-key check passed.")
