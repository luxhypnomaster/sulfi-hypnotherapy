#!/usr/bin/env python3
"""Read-only SOURCE gate and future commands. No execution/native tool imports.

This file CANNOT build, sign, install, dispatch CI or modify Android sources.
Future commands require separate owner permission and a frozen approved source.
Historical certificates are evidence, not a freshly verified candidate APK.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
CERT = "0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6"
IDS = {"master": "ru.sulfi.sulfi_hypnotherapy", "client": "ru.sulfi.sulfi_hypnotherapy.clienttest"}


def plan(source, version_code, installed_code=28, root=ROOT):
    if not re.fullmatch(r"[0-9a-f]{40}", source):
        raise ValueError("exact approved source SHA required")
    if version_code <= max(28, installed_code):
        raise ValueError("no downgrade/reuse; choose versionCode above all installed editions")
    pinned = json.loads((root / "scripts/task23/native_source_pins.json").read_text())
    for name, sha in pinned["files"].items():
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != sha:
            raise ValueError("native source drift; re-audit, never auto-update pins")
    historical = json.loads((root / "reports/task18/DELIVERY_READBACK_18.json").read_text())
    for item in historical["secondIndependentReadback"]["files"]:
        if item["package"] != IDS[item["edition"]] or item["certificateSHA256"] != CERT:
            raise ValueError("historical identity mismatch")
    commands = []
    for edition in IDS:
        commands.append({"edition": edition, "applicationId": IDS[edition], "futureCommand":
            "flutter build apk --debug --no-pub --build-number=" + str(version_code) +
            (" --dart-define=SULFI_EDITION=client" if edition == "client" else ""),
            "artifact": "build/app/outputs/flutter-apk/app-debug.apk (copy edition separately ONLY after later permission)"})
    return {"status": "DEFERRED_BY_OWNER", "execute": False, "approvedSourceMustEqual": source,
            "sourceConfig": "PASS_READ_ONLY_NOT_APK_VERIFICATION", "toolchain": pinned["toolchain"],
            "historicalCertificateSHA256": CERT, "historicalCertificateSource": "Task18 readback, not newly inspected APK",
            "versionCode": version_code, "commandsForFutureApprovedTaskOnly": commands,
            "mandatoryBeforeFutureExecution": ["owner authorises native gate", "git HEAD equals approved SHA and clean tree",
                "Flutter/engine/JDK/Gradle/AGP/Kotlin/SDK exact pins rechecked and dependencies cached",
                "existing protected signing material provisioned; no generated default debug identity",
                "both APK independently checked: SHA, apksigner public cert, aapt package/code/permissions",
                "synthetic UI-created old-version normal install-r upgrade passes before owner device",
                "no uninstall, clear, downgrade, cloud/API/ACL changes"],
            "artifactRule": "Flutter ARM bundle is NOT APK/AAB and has NO Android signer proof",
            "readOnlyFutureAdb": ["adb shell dumpsys package " + value for value in IDS.values()]}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", required=True)
    p.add_argument("--version-code", type=int, required=True)
    p.add_argument("--highest-installed-code", type=int, default=28)
    p.add_argument("--execute", action="store_true")
    a = p.parse_args()
    if a.execute:
        p.exit(2, "DEFERRED_BY_OWNER: execution intentionally unavailable.\n")
    try:
        print(json.dumps(plan(a.source, a.version_code, a.highest_installed_code), indent=2))
    except (ValueError, OSError, KeyError):
        p.exit(2, "BLOCKED: read-only source/version gate failed; no native action performed.\n")


if __name__ == "__main__":
    main()
