#!/usr/bin/env python3
"""Print an xcodebuild -destination for the newest available iPhone simulator.

Hard-coding a device name ("iPhone 17 Pro") breaks whenever the CI runner image
changes its simulator set, and the app requires iOS 26, so the destination has to
be resolved from what the machine actually has.
"""
import json
import re
import subprocess
import sys


def runtime_sort_key(runtime: str):
    """iOS runtimes sort by version, newest last."""
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(match.group(1)), int(match.group(2))) if match else (0, 0)


def main() -> int:
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        capture_output=True, text=True, check=True,
    )
    devices = json.loads(result.stdout)["devices"]

    candidates = [
        (runtime, device)
        for runtime, entries in devices.items()
        if "iOS" in runtime
        for device in entries
        if "iPhone" in device["name"] and device.get("isAvailable", True)
    ]
    if not candidates:
        print("No available iOS iPhone simulator found.", file=sys.stderr)
        subprocess.run(["xcrun", "simctl", "list", "devices", "available"])
        return 1

    runtime, device = max(candidates, key=lambda pair: runtime_sort_key(pair[0]))
    print(f"platform=iOS Simulator,id={device['udid']}")
    print(f"Selected {device['name']} on {runtime}", file=sys.stderr)
    return 0


sys.exit(main())
