#!/usr/bin/env python3
"""Refuse a SwiftUI view that no screen shows.

A view that is defined, tested and translated and then referenced by nothing is
the most convincing kind of dead code: every check around it is green. It
happened twice in one release. `SubstanceInteractionCard` rendered each
warning's provenance and was placed on no screen, so every warning reached the
reader with the same apparent authority. `JournalNightDraftCard` was the whole
of a feature — offering to fill in the night log from the journal — and it too
was on no screen, while the release notes described it as shipped. The suite
could see neither, because it tests what a view computes, not whether anything
puts the view in front of a person. Both were found by running the app.

A view counts as used when its name appears anywhere outside its own
declaration: constructed, passed as a type, named in a preview. That is a low
bar on purpose. The failure this catches is not "used rarely", it is "used
nowhere", and a stricter rule would drown it in noise.

One exception to the low bar: a `typealias` naming the view is not a use. It
puts nothing in front of anyone, and it is exactly how an orphan hides —
`SafetyNoticeCard` passed the first version of this check because
`typealias TestingOnlyNoticeCard = SafetyNoticeCard` mentioned it, and nothing
mentioned the alias.

`KNOWN_ORPHANS` held what was already orphaned when the check arrived, fifteen
views, all deleted in 5.1.0. Adding to it needs a reason written next to the
name.
"""

import re
import subprocess
import sys

TARGETS = (
    "ChillMate",
    "ChillMateWatchApp",
    "ChillMateWatchAppWidget",
    "ChillMateLiveActivityExtension",
)

# Empty since 5.1.0, when the fifteen views orphaned before this check existed
# were deleted. Anything added here needs its reason written beside it.
KNOWN_ORPHANS: set[str] = set()

# Generic parameters are allowed between the name and the colon. Without them a
# view like `struct LiquidGlassGroup<Content: View>: View` was never seen, and it
# sat unused for as long as the check had existed.
DECLARATION = re.compile(
    r"^(?:private |fileprivate )?struct (\w+)(?:<[^>{]*>)?\s*:\s*[^{]*\bView\b", re.MULTILINE
)


def swift_sources():
    listed = subprocess.run(
        ["git", "ls-files", "--", *TARGETS],
        capture_output=True, text=True, check=True,
    ).stdout.split("\n")
    return [path for path in listed if path.endswith(".swift")]


def main():
    sources = {}
    for path in swift_sources():
        with open(path, encoding="utf-8") as handle:
            sources[path] = handle.read()

    declared = []
    for path, text in sources.items():
        for name in DECLARATION.findall(text):
            declared.append((path, name))

    orphans = []
    for path, name in declared:
        reference = re.compile(rf"\b{re.escape(name)}\b")
        declaration = re.compile(rf"\bstruct {re.escape(name)}\b")
        used = False
        alias = re.compile(rf"^\s*(?:public |private |fileprivate )?typealias \w+\s*=\s*{re.escape(name)}\b.*$", re.MULTILINE)
        for other_path, other in sources.items():
            text = declaration.sub("", other) if other_path == path else other
            text = alias.sub("", text)
            if reference.search(text):
                used = True
                break
        if not used:
            orphans.append((path, name))

    new = [(p, n) for p, n in orphans if n not in KNOWN_ORPHANS]
    revived = sorted(KNOWN_ORPHANS - {n for _, n in orphans})

    print(f"  {len(declared)} views, {len(orphans)} referenced nowhere, "
          f"{len(orphans) - len(new)} of those already known")

    failed = False
    if new:
        failed = True
        print("\nViews that no screen shows:")
        for path, name in sorted(new):
            print(f"  - {path}: {name}")
        print("\nPut each on a screen, delete it, or — with a reason written "
              "beside it — add it to KNOWN_ORPHANS.")
    if revived:
        failed = True
        print("\nNo longer orphaned, so no longer allowed on the list:")
        for name in revived:
            print(f"  - {name}")
        print("\nRemove them from KNOWN_ORPHANS. A list that only grows is not a list.")

    if failed:
        sys.exit(1)
    print("\nOrphan-view check passed.")


if __name__ == "__main__":
    main()
