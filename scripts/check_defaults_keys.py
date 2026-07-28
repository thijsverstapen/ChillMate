#!/usr/bin/env python3
"""Fail when a UserDefaults key is written as a bare string literal.

Keys used to be repeated at each call site, and a typo bound silently to a
different key that read back as false or "" rather than failing — which is how
the reduce-motion setting came to be advertised app-wide while only onboarding
read it. DefaultsKey (and WidgetSharedKey, for keys crossing target boundaries)
is the registry; this keeps new code from drifting back.
"""
import pathlib
import re
import sys

APP = pathlib.Path("ChillMate")

# Literals that are not UserDefaults keys despite matching the pattern.
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

# Files allowed to hold literals: the registries themselves, and the settings
# reset list, which needs the historical names of keys no longer declared.
EXEMPT_FILES = {"DefaultsKeys.swift", "WidgetSharedKeys.swift"}

PATTERNS = [
    re.compile(r'@AppStorage\("([^"]+)"\)'),
    re.compile(r'forKey:\s*"([^"]+)"'),
    re.compile(r'suiteName:\s*"([^"]+)"'),
]

violations = []
for path in sorted(APP.glob("*.swift")):
    if path.name in EXEMPT_FILES:
        continue
    for number, line in enumerate(path.read_text().split("\n"), 1):
        # The account-deletion routine lists historical key names on purpose.
        if "removeObject(forKey: key)" in line:
            continue
        for pattern in PATTERNS:
            for match in pattern.finditer(line):
                if match.group(1) in ALLOWED:
                    continue
                violations.append(f"{path}:{number}: {match.group(0)}")

if violations:
    print("UserDefaults keys must come from DefaultsKey or WidgetSharedKey:")
    for violation in violations:
        print(f"  - {violation}")
    sys.exit(1)

print("Defaults-key check passed.")
