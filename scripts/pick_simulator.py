#!/usr/bin/env python3
"""Print an xcodebuild -destination for the newest available iPhone simulator.

Hard-coding a device name ("iPhone 17 Pro") breaks whenever the CI runner image
changes its simulator set, and the app requires iOS 26, so the destination has to
be resolved from what the machine actually has. A GitHub macos-15 runner has
nothing in common with the developer's local simulator list beyond "some iPhone".

The destination goes to stdout and everything else to stderr, so the caller can
use DEST=$(scripts/pick_simulator.py) without the commentary leaking into it.
"""
import json
import re
import subprocess
import sys

# Mirrors IPHONEOS_DEPLOYMENT_TARGET. A machine whose newest iOS runtime is older
# than this cannot install the app at all, and xcodebuild reports that several
# minutes later as an unrelated-looking failure, so say it plainly up front.
MINIMUM_IOS = (26, 0)

# Matches only iOS runtimes: watchOS and tvOS identifiers are built the same way
# but do not contain ".iOS-", so anchoring on the prefix keeps them out.
IOS_RUNTIME = re.compile(r"SimRuntime\.iOS-(\d+)-(\d+)")


def runtime_version(identifier):
    """(major, minor) for an iOS runtime identifier, or None when it is not iOS."""
    match = IOS_RUNTIME.search(identifier)
    return (int(match.group(1)), int(match.group(2))) if match else None


def describe(version):
    return ".".join(str(part) for part in version)


def main() -> int:
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "--json"],
            capture_output=True, text=True, check=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Could not list simulators: {error}", file=sys.stderr)
        return 1

    devices = json.loads(result.stdout)["devices"]

    candidates = []
    for identifier, entries in devices.items():
        version = runtime_version(identifier)
        if version is None:
            continue
        for device in entries:
            if "iPhone" in device["name"] and device.get("isAvailable", True):
                candidates.append((version, device["name"], device["udid"]))

    if not candidates:
        print("No available iPhone simulator found. Installed devices:", file=sys.stderr)
        subprocess.run(["xcrun", "simctl", "list", "devices", "available"], stdout=sys.stderr)
        return 1

    # Sorted rather than max() so a machine holding several iPhones on the same
    # runtime picks the same one every run. An arbitrary pick makes a failure that
    # only reproduces on one device model impossible to reason about from a log.
    version, name, udid = sorted(candidates)[-1]

    if version < MINIMUM_IOS:
        print(
            f"ChillMate needs an iOS {describe(MINIMUM_IOS)} simulator; the newest one "
            f"installed is {describe(version)}. Install a newer runtime, or select a "
            "newer Xcode before this step.",
            file=sys.stderr,
        )
        return 1

    print(f"platform=iOS Simulator,id={udid}")
    print(f"Selected {name} on iOS {describe(version)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
