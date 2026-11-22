#!/usr/bin/env python3
"""Read-only guard for Task24's isolated UI changes; never builds/deploys."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = "85fa5321c043ef97b43cb30a88a0909e7edf66f2"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode().strip()


def check():
    git("merge-base", "--is-ancestor", BASE, "HEAD")
    protected = json.loads((ROOT / "reports/task24/PROTECTED_24.json").read_text())
    for name, sha in protected["files"].items():
        data = (ROOT / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != sha or data != subprocess.check_output(
            ["git", "show", f"{BASE}:{name}"], cwd=ROOT):
            raise ValueError("Task21/22/23 protected source changed")
    changed = git("diff", "--name-only", BASE).splitlines()
    allowed = {"lib/ui/alchemist_queue_indicator.dart", "lib/ui/alchemist_sync_screen.dart",
               "lib/ui/diary_reader.dart"}
    for name in changed:
        if name.startswith("lib/") and name not in allowed:
            raise ValueError("outside isolated UI routing scope")
        if name.startswith(("android/", "server/", ".github/", "assets/", "lib/data/", "lib/services/", "lib/models/")) or name in ("pubspec.yaml", "pubspec.lock", "README.md", "BACKLOG.md"):
            raise ValueError("storage/server/auth/native/shared file overwritten")
    for row in json.loads((ROOT / "docs/task24/06_MANIFEST.json").read_text())["files"]:
        raw = (ROOT / "docs/task24" / row["file"]).read_bytes()
        if len(raw) != row["bytes"] or hashlib.sha256(raw).hexdigest() != row["sha256"]:
            raise ValueError("input manifest changed")
    return {"status": "PASS_SOURCE", "head": git("rev-parse", "HEAD"), "basePR55": BASE,
            "protectedPreviousFiles": len(protected["files"]), "previousSource": "BYTE_IDENTICAL",
            "changedUI": [p for p in changed if p.startswith("lib/")],
            "native": "DEFERRED_BY_OWNER", "serverAuthStorageSigningMain": "NOT_CHANGED"}


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
