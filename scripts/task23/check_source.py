#!/usr/bin/env python3
"""Read-only archive/protected-source guard. No build, auth or cloud mutation."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BASE = "ff32a0f86b8fe9c5ffe7e75406d8b3291471d9c2"
PARENT = "40b7c59e67921f456c3c5a4e943bd40f7232f336"
ARCHIVE_SHA = "123d4bd298ebecc92176eec44fed718eecc6f04b09472e10ca197e3627d46a69"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def check(archive=None):
    git("merge-base", "--is-ancestor", BASE, "HEAD")
    pinned = json.loads((ROOT / "reports/task23/TASK22_PROTECTED_23.json").read_text())
    # Independently derive overlap paths; don't rely on a manually selected list.
    paths = git("diff", "--name-only", PARENT, BASE).decode().splitlines()
    scoped = [p for p in paths if p.startswith(("lib/", "server/", "test/", "scripts/", ".github/"))]
    if set(scoped) != set(pinned["files"]):
        raise ValueError("Task22 protected path set drift")
    for path in scoped:
        current = (ROOT / path).read_bytes()
        if current != git("show", f"{BASE}:{path}"):
            raise ValueError("Task22 component overwritten")
        if hashlib.sha256(current).hexdigest() != pinned["files"][path]:
            raise ValueError("protected digest mismatch")
    changed = git("diff", "--name-only", BASE).decode().splitlines()
    forbidden = [p for p in changed if p.startswith(("android/", "server/", ".github/")) or p in ("pubspec.yaml", "pubspec.lock")]
    allowed_lib = {"lib/data/app_database.dart", "lib/data/storage_preflight.dart", "lib/services/capsule_service.dart", "lib/main.dart"}
    if forbidden or any(p.startswith("lib/") and p not in allowed_lib for p in changed):
        raise ValueError("scope drift")
    manifest = json.loads((ROOT / "docs/task23/06_MANIFEST.json").read_text())
    if len(manifest["files"]) != 6 or len(list((ROOT / "docs/task23").iterdir())) != 7:
        raise ValueError("input file count drift")
    for row in manifest["files"]:
        data = (ROOT / "docs/task23" / row["file"]).read_bytes()
        if len(data) != row["bytes"] or hashlib.sha256(data).hexdigest() != row["sha256"]:
            raise ValueError("input manifest mismatch")
    archive_status = "NOT_REOPENED_USE_INITIAL_INTEGRITY_RECORD"
    if archive:
        archive = Path(archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA:
            raise ValueError("outer archive digest mismatch")
        with zipfile.ZipFile(archive) as z:
            if z.testzip() is not None or len(z.namelist()) != 7 or len(set(z.namelist())) != 7:
                raise ValueError("ZIP CRC/count mismatch")
            for name in z.namelist():
                if z.read(name) != (ROOT / "docs/task23" / name).read_bytes():
                    raise ValueError("archive/source mismatch")
        archive_status = "PASS_CRC_7_FILES_OUTER_SHA_AND_MANIFEST_6_HASHES_SIZES"
    return {"status": "PASS_SOURCE", "head": git("rev-parse", "HEAD").decode().strip(),
            "basePR54": BASE, "parentPR52": PARENT, "protectedTask22Files": len(scoped),
            "task22Bytes": "IDENTICAL_TO_PR54", "nativeServerWorkflowPubspecDiff": forbidden,
            "changedPaths": changed, "archive": archive_status,
            "native": "DEFERRED_BY_OWNER", "mainMerge": "NOT_PERFORMED"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive")
    try:
        print(json.dumps(check(parser.parse_args().archive), indent=2))
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError):
        parser.exit(2, "BLOCKED: source boundary/integrity mismatch. No mutation performed.\n")
