#!/usr/bin/env python3
"""Validate notification delivery components in source or merged Android XML.

Use the same check on the release merged manifest: checking only the source
cannot prove that manifest merging preserved the receiver contract.
"""

import argparse
import hashlib
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


ANDROID = "{http://schemas.android.com/apk/res/android}"
DELIVERY_RECEIVER = (
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
)
BOOT_RECEIVER = (
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
)
BOOT_ACTIONS = frozenset(
    {
        "android.intent.action.BOOT_COMPLETED",
        "android.intent.action.MY_PACKAGE_REPLACED",
        "android.intent.action.QUICKBOOT_POWERON",
        "com.htc.intent.action.QUICKBOOT_POWERON",
    }
)


def validate_manifest(xml):
    """Return actionable violations without trusting comments or substrings."""
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as error:
        return [f"Invalid manifest XML: {error}"]
    if root.tag != "manifest":
        return ["Root element must be manifest"]

    failures = []
    permissions = [
        node
        for node in root.findall("uses-permission")
        if node.get(ANDROID + "name") == "android.permission.RECEIVE_BOOT_COMPLETED"
    ]
    if not permissions or all(
        node.get(ANDROID + "maxSdkVersion") is not None for node in permissions
    ):
        failures.append("RECEIVE_BOOT_COMPLETED must cover all supported SDKs")

    applications = root.findall("application")
    if len(applications) != 1:
        return failures + ["Manifest must contain exactly one application"]
    application = applications[0]
    if application.get(ANDROID + "enabled", "true") != "true":
        failures.append("Application must be enabled")

    for name in (DELIVERY_RECEIVER, BOOT_RECEIVER):
        receivers = [
            node
            for node in application.findall("receiver")
            if node.get(ANDROID + "name") == name
        ]
        if len(receivers) != 1:
            failures.append(f"Expected exactly one application receiver: {name}")
            continue
        receiver = receivers[0]
        if receiver.get(ANDROID + "exported") != "false":
            failures.append(f"Receiver must explicitly set exported=false: {name}")
        if receiver.get(ANDROID + "enabled", "true") != "true":
            failures.append(f"Receiver must be enabled: {name}")
        if name == BOOT_RECEIVER:
            actions = {
                action.get(ANDROID + "name")
                for action in receiver.findall("intent-filter/action")
            }
            for action in sorted(BOOT_ACTIONS - actions):
                failures.append(f"Boot receiver is missing action: {action}")
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifests", type=Path, nargs="+")
    options = parser.parse_args()
    failed = False
    for path in options.manifests:
        try:
            data = path.read_bytes()
            failures = validate_manifest(data)
            digest = hashlib.sha256(data).hexdigest()
        except OSError as error:
            failures, digest = [str(error)], None
        print(json.dumps({"manifest": str(path), "sha256": digest, "failures": failures}))
        failed |= bool(failures)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
