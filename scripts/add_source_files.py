#!/usr/bin/env python3
"""Add Swift sources to a ChillMate target in project.pbxproj.

The ChillMate app group is a classic PBXGroup (not a
PBXFileSystemSynchronizedRootGroup like ChillMateTests), so files dropped into
ChillMate/ are invisible to the build until they are registered in four places:
a PBXBuildFile, a PBXFileReference, the group's children, and the target's
PBXSourcesBuildPhase. This script does all four, idempotently.

A file can belong to several targets. `WidgetSharedKeys.swift` is the worked
example: one PBXFileReference, one entry in the group, and four PBXBuildFile
rows, one per target's Sources phase. That shape is what lets a single
definition cross the app, the watch app, and both extensions, which is the only
way two processes can be held to the same constant. Pass --target once per
target that should compile the file.

Resources (.xcstrings, assets) go through the app's Resources phase instead;
pass --resource for those.

A file is filed under one group, which is what resolves its path on disk, and
compiled into any number of targets. Those are separate choices: --group says
where the file lives, --target says who builds it.

Usage:  scripts/add_source_files.py Foo.swift Bar.swift
        scripts/add_source_files.py --target app --target liveactivity Shared.swift
        scripts/add_source_files.py --group liveactivity --target liveactivity Widget.swift
        scripts/add_source_files.py --resource InfoPlist.xcstrings
        (filenames are relative to the group's own directory, ChillMate/ by default)
"""
import re
import sys
from pathlib import Path

PBXPROJ = Path(__file__).resolve().parent.parent / "ChillMate.xcodeproj" / "project.pbxproj"

# ID space reserved for script-added sources, distinct from the D55F/C33D/E66F
# ranges Xcode and earlier manual edits already used.
BUILD_ID_PREFIX = "AAB1"
FILE_ID_PREFIX = "AAF1"

APP_RESOURCES_PHASE_ID = "A11B00000000000000000025"  # app target's Resources phase

# The PBXGroup a file is filed under, which is also what resolves its path: each
# group carries `path = <directory>` and the file reference is relative to it. A
# file added to the wrong group builds against a path that does not exist.
GROUPS = {
    "app": ("A11B00000000000000000020", "ChillMate"),
    "liveactivity": ("E66F00000000000000000020", "ChillMateLiveActivityExtension"),
    "watch": ("F88B00000000000000000020", "ChillMateWatchApp"),
    "uitests": ("FB13991735BCF9331F9CEB34", "ChillMateUITests"),
}

# Every target's Sources phase, keyed by the name you pass to --target. Read off
# the PBXNativeTarget buildPhases lists; ChillMateTests is absent because it is a
# synchronized group and registers its own files.
TARGET_SOURCES_PHASES = {
    "app": "A11B00000000000000000024",
    "liveactivity": "E66F00000000000000000030",
    "watch": "F88B00000000000000000030",
    "watchwidget": "9945F9912FFEC12300543BD4",
    "uitests": "75279D0CC745F76A05A98DFA",
}

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".xcstrings": "text.json.xcstrings",
    ".plist": "text.plist.xml",
    # The usage note offers --resource for assets, so the type it needs has to be
    # here; without it that path raised "unknown file type" instead.
    ".xcassets": "folder.assetcatalog",
}


def next_index(text, prefix):
    used = {int(m[len(prefix):], 16) for m in re.findall(prefix + r"[0-9A-F]{20}", text)}
    i = 1
    while i in used:
        i += 1
    return i


def make_id(prefix, index):
    return f"{prefix}{index:020X}"


def existing_file_id(text, filename):
    """The PBXFileReference id for this filename, or None."""
    match = re.search(
        r"([0-9A-F]{24}) /\* " + re.escape(filename) + r" \*/ = \{isa = PBXFileReference;",
        text,
    )
    return match.group(1) if match else None


def ensure_file_reference(text, filename, group="app"):
    """Register the file itself (reference + group membership) exactly once."""
    file_id = existing_file_id(text, filename)
    if file_id is not None:
        return text, file_id

    ext = filename[filename.rfind("."):]
    file_type = FILE_TYPES.get(ext)
    if file_type is None:
        raise SystemExit(f"unknown file type for {filename}; add it to FILE_TYPES")

    file_id = make_id(FILE_ID_PREFIX, next_index(text, FILE_ID_PREFIX))

    # str.replace returns the text untouched when the anchor is absent, so each
    # insertion is checked. A silent no-op here writes back a project that looks
    # fine and builds without the new file, which is the confusing failure this
    # script exists to avoid.
    reference_anchor = "/* End PBXFileReference section */"
    if reference_anchor not in text:
        raise SystemExit(f"could not locate {reference_anchor}")
    text = text.replace(
        reference_anchor,
        f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = {file_type}; path = {filename}; "
        'sourceTree = "<group>"; };\n'
        f"{reference_anchor}",
        1,
    )

    group_id, group_name = GROUPS.get(group, (None, None))
    if group_id is None:
        raise SystemExit(f"unknown group {group!r}; pick from {', '.join(GROUPS)}")

    group_re = re.compile(
        r"(\t\t" + group_id + r" /\* " + group_name + r" \*/ = \{.*?children = \(\n)",
        re.S,
    )
    text, n = group_re.subn(rf"\1\t\t\t\t{file_id} /* {filename} */,\n", text, count=1)
    if n != 1:
        raise SystemExit(f"could not locate group {group_name} ({group_id})")

    return text, file_id


def phase_contains(text, phase_id, phase_name, filename):
    """Whether this target's phase already lists the file."""
    block = re.search(
        r"\t\t" + phase_id + r" /\* " + phase_name + r" \*/ = \{.*?\n\t\t\};",
        text,
        re.S,
    )
    if block is None:
        raise SystemExit(f"could not locate {phase_name} phase {phase_id}")
    return f"/* {filename} in {phase_name} */" in block.group(0)


def ensure_membership(text, filename, file_id, phase_id, phase_name, target_label):
    """Compile the file into one target, if it is not already."""
    if phase_contains(text, phase_id, phase_name, filename):
        print(f"  skip (already in {target_label}): {filename}")
        return text

    build_id = make_id(BUILD_ID_PREFIX, next_index(text, BUILD_ID_PREFIX))

    build_anchor = "/* End PBXBuildFile section */"
    if build_anchor not in text:
        raise SystemExit(f"could not locate {build_anchor}")
    text = text.replace(
        build_anchor,
        f"\t\t{build_id} /* {filename} in {phase_name} */ = {{isa = PBXBuildFile; "
        f"fileRef = {file_id} /* {filename} */; }};\n"
        f"{build_anchor}",
        1,
    )

    phase_re = re.compile(
        r"(\t\t" + phase_id + r" /\* " + phase_name + r" \*/ = \{.*?files = \(\n)",
        re.S,
    )
    text, n = phase_re.subn(
        rf"\1\t\t\t\t{build_id} /* {filename} in {phase_name} */,\n", text, count=1
    )
    if n != 1:
        raise SystemExit(f"could not locate {phase_name} phase {phase_id}")

    print(f"  added: {filename} -> {target_label} {phase_name}  (build {build_id}, file {file_id})")
    return text


def add_file(text, filename, resource=False, targets=("app",), group="app"):
    text, file_id = ensure_file_reference(text, filename, group=group)

    if resource:
        return ensure_membership(
            text, filename, file_id, APP_RESOURCES_PHASE_ID, "Resources", "app"
        )

    for target in targets:
        phase_id = TARGET_SOURCES_PHASES.get(target)
        if phase_id is None:
            raise SystemExit(
                f"unknown target {target!r}; pick from {', '.join(TARGET_SOURCES_PHASES)}"
            )
        text = ensure_membership(text, filename, file_id, phase_id, "Sources", target)
    return text


def main(argv):
    resource = "--resource" in argv
    targets = []
    names = []
    group = "app"
    expecting = None
    for arg in argv:
        if expecting == "target":
            targets.append(arg)
            expecting = None
        elif expecting == "group":
            group = arg
            expecting = None
        elif arg == "--target":
            expecting = "target"
        elif arg == "--group":
            expecting = "group"
        elif arg.startswith("--target="):
            targets.append(arg.split("=", 1)[1])
        elif arg.startswith("--group="):
            group = arg.split("=", 1)[1]
        elif not arg.startswith("--"):
            names.append(arg)
    if expecting is not None:
        raise SystemExit(f"--{expecting} needs a value")
    if not names:
        raise SystemExit(__doc__)
    if not PBXPROJ.is_file():
        raise SystemExit(f"no project file at {PBXPROJ}")

    original = PBXPROJ.read_text()
    text = original
    for name in names:
        text = add_file(text, name, resource=resource, targets=targets or ("app",), group=group)

    # Every file was already registered, so leave the project's mtime alone
    # rather than rewriting it byte for byte and dirtying the working tree.
    if text == original:
        return
    PBXPROJ.write_text(text)


if __name__ == "__main__":
    main(sys.argv[1:])
