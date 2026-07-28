#!/usr/bin/env python3
"""Add Swift sources to the ChillMate app target in project.pbxproj.

The ChillMate app group is a classic PBXGroup (not a
PBXFileSystemSynchronizedRootGroup like ChillMateTests), so files dropped into
ChillMate/ are invisible to the build until they are registered in four places:
a PBXBuildFile, a PBXFileReference, the group's children, and the target's
PBXSourcesBuildPhase. This script does all four, idempotently.

Resources (.xcstrings, assets) go through the Resources phase instead; pass
--resource for those.

Usage:  scripts/add_source_files.py Foo.swift Bar.swift
        scripts/add_source_files.py --resource InfoPlist.xcstrings
        (paths are relative to the ChillMate/ source directory)
"""
import re
import sys
from pathlib import Path

PBXPROJ = Path(__file__).resolve().parent.parent / "ChillMate.xcodeproj" / "project.pbxproj"

# ID space reserved for script-added sources, distinct from the D55F/C33D/E66F
# ranges Xcode and earlier manual edits already used.
BUILD_ID_PREFIX = "AAB1"
FILE_ID_PREFIX = "AAF1"

APP_GROUP_ID = "A11B00000000000000000020"        # /* ChillMate */ PBXGroup
APP_SOURCES_PHASE_ID = "A11B00000000000000000024"    # app target's Sources phase
APP_RESOURCES_PHASE_ID = "A11B00000000000000000025"  # app target's Resources phase

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".xcstrings": "text.json.xcstrings",
    ".plist": "text.plist.xml",
}


def next_index(text, prefix):
    used = {int(m[len(prefix):], 16) for m in re.findall(prefix + r"[0-9A-F]{20}", text)}
    i = 1
    while i in used:
        i += 1
    return i


def make_id(prefix, index):
    return f"{prefix}{index:020X}"


def add_file(text, filename, resource=False):
    if f"/* {filename} */" in text:
        print(f"  skip (already registered): {filename}")
        return text

    phase_name = "Resources" if resource else "Sources"
    phase_id = APP_RESOURCES_PHASE_ID if resource else APP_SOURCES_PHASE_ID
    ext = filename[filename.rfind("."):]
    file_type = FILE_TYPES.get(ext)
    if file_type is None:
        raise SystemExit(f"unknown file type for {filename}; add it to FILE_TYPES")

    build_id = make_id(BUILD_ID_PREFIX, next_index(text, BUILD_ID_PREFIX))
    file_id = make_id(FILE_ID_PREFIX, next_index(text, FILE_ID_PREFIX))

    # 1. PBXBuildFile
    text = text.replace(
        "/* End PBXBuildFile section */",
        f"\t\t{build_id} /* {filename} in {phase_name} */ = {{isa = PBXBuildFile; "
        f"fileRef = {file_id} /* {filename} */; }};\n"
        "/* End PBXBuildFile section */",
        1,
    )

    # 2. PBXFileReference
    text = text.replace(
        "/* End PBXFileReference section */",
        f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = {file_type}; path = {filename}; "
        'sourceTree = "<group>"; };\n'
        "/* End PBXFileReference section */",
        1,
    )

    # 3. Group children
    group_re = re.compile(
        r"(\t\t" + APP_GROUP_ID + r" /\* ChillMate \*/ = \{.*?children = \(\n)",
        re.S,
    )
    text, n = group_re.subn(rf"\1\t\t\t\t{file_id} /* {filename} */,\n", text, count=1)
    if n != 1:
        raise SystemExit(f"could not locate app group {APP_GROUP_ID}")

    # 4. Sources / Resources build phase
    phase_re = re.compile(
        r"(\t\t" + phase_id + r" /\* " + phase_name + r" \*/ = \{.*?files = \(\n)",
        re.S,
    )
    text, n = phase_re.subn(
        rf"\1\t\t\t\t{build_id} /* {filename} in {phase_name} */,\n", text, count=1
    )
    if n != 1:
        raise SystemExit(f"could not locate {phase_name} phase {phase_id}")

    print(f"  added: {filename} -> {phase_name}  (build {build_id}, file {file_id})")
    return text


def main(argv):
    resource = "--resource" in argv
    names = [a for a in argv if not a.startswith("--")]
    if not names:
        raise SystemExit(__doc__)
    text = PBXPROJ.read_text()
    for name in names:
        text = add_file(text, name, resource=resource)
    PBXPROJ.write_text(text)


if __name__ == "__main__":
    main(sys.argv[1:])
