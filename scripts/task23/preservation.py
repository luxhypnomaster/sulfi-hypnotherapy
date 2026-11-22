#!/usr/bin/env python3
"""Copy-only preservation helper. Never point this at a running/owner app.

Input must be an explicitly authorised, quiescent forensic/synthetic COPY.
owner is a caller-supplied local binding, NOT Google authentication. The trusted
caller must check that binding; restore also requires an independently retained
manifest SHA. This is diagnostic recovery, not a new user capsule/sync format.
Default CLI operation is dry-run. No SQLite on the source is opened, even RO:
SQLite may create SHM/recover journals. Integrity is checked on a derivative.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import sqlite3
import tempfile

MANIFEST = "preservation23.json"


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def relative(value):
    if not isinstance(value, str) or not value or "\\" in value or "\0" in value:
        raise ValueError("unsafe path")
    p = PurePosixPath(value)
    if p.is_absolute() or any(x in (".", "..") for x in value.split("/")) or str(p) != value:
        raise ValueError("unsafe path")
    return value


def root_path(root):
    root = Path(root).absolute()
    if not root.is_dir() or any(p.is_symlink() for p in (root, *root.parents)):
        raise ValueError("root must be a regular isolated directory")
    return root


def inventory(root):
    root = root_path(root)
    files = {}
    for parent, dirs, names in os.walk(root, followlinks=False):
        for name in dirs + names:
            p = Path(parent) / name
            if p.is_symlink() or not (p.is_dir() or p.is_file()):
                raise ValueError("links/special files are not recoverable automatically")
        for name in names:
            p = Path(parent) / name
            rel = relative(p.relative_to(root).as_posix())
            if rel == MANIFEST:
                continue
            before = p.stat()
            row = {"bytes": before.st_size, "sha256": digest(p)}
            after = p.stat()
            if (before.st_size, before.st_mtime_ns, before.st_ino) != (after.st_size, after.st_mtime_ns, after.st_ino):
                raise ValueError("source changed during read")
            files[rel] = row
    return dict(sorted(files.items()))


def verify_sqlite_copy(root, database):
    """Check ALL sidecars on a derivative; no immutable=1 WAL omission."""
    database = relative(database)
    src = Path(root) / database
    with tempfile.TemporaryDirectory(prefix="t23-check-") as temp:
        target = Path(temp) / "db"
        for suffix in ("", "-wal", "-shm", "-journal"):
            f = Path(str(src) + suffix)
            if f.exists():
                shutil.copyfile(f, str(target) + suffix)
        if not target.is_file():
            raise ValueError("database missing")
        # RW is permitted on this derivative ONLY, for hot-journal recovery.
        conn = sqlite3.connect(target)
        try:
            if conn.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
                raise ValueError("database corrupt")
            version = conn.execute("PRAGMA user_version").fetchone()[0]
            if version not in range(1, 10):
                raise ValueError("unknown schema; preserve bytes and stop")
            return version
        finally:
            conn.close()


def independent_destination(root, destination):
    dst = Path(destination).absolute()
    if dst.exists() or dst.is_symlink():
        raise ValueError("destination exists; never overwrite")
    if root == dst or root in dst.parents or dst in root.parents:
        raise ValueError("destination must be independent")
    # No creation of parents and no symlink redirection.
    root_path(dst.parent)
    return dst


def write_copy(root, destination, files, manifest=None):
    dst = independent_destination(root, destination)
    dst.mkdir()  # exclusive reservation; an existing empty directory is refused
    try:
        for rel, expected in files.items():
            src, target = root / relative(rel), dst / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            with src.open("rb") as source, target.open("xb") as output:
                shutil.copyfileobj(source, output, 1024 * 1024)
            if target.stat().st_size != expected["bytes"] or digest(target) != expected["sha256"]:
                raise ValueError("source changed / copy checksum mismatch")
        if inventory(root) != files or inventory(dst) != files:
            raise ValueError("source changed during copy")
        if manifest is not None:
            with (dst / MANIFEST).open("xb") as f:
                f.write(canonical(manifest))
        return dst
    except BaseException:
        shutil.rmtree(dst)  # only the directory exclusively created above
        raise


def snapshot(root, owner, database="library.sqlite", destination=None, *, dry_run=True, copy_confirmed=False):
    if not copy_confirmed or not owner:
        raise ValueError("explicit copy-only authorisation and owner binding required")
    root = root_path(root)
    if (root / MANIFEST).exists():
        raise ValueError("snapshot already present; use inspect/restore")
    before = inventory(root)
    version = verify_sqlite_copy(root, database)
    if inventory(root) != before:
        raise ValueError("source changed during validation")
    manifest = {"format": "sulfi-preservation-copy", "schema": 1, "ownerBinding": owner,
                "database": relative(database), "sqliteVersion": version, "files": before}
    sha = hashlib.sha256(canonical(manifest)).hexdigest()
    if destination is not None:
        independent_destination(root, destination)
    if not dry_run:
        if destination is None:
            raise ValueError("new isolated destination required")
        write_copy(root, destination, before, manifest)
    return {"mode": "DRY_RUN" if dry_run else "COPY_CREATED", "manifestSHA256": sha,
            "files": len(before), "sqliteVersion": version, "unknownMedia": "PRESERVED_NO_GC"}


def restore(root, expected_owner, expected_manifest_sha, destination=None, *, dry_run=True, copy_confirmed=False):
    if not copy_confirmed or not expected_owner or not expected_manifest_sha:
        raise ValueError("explicit copy-only authorisation, owner and external checksum required")
    root = root_path(root)
    manifest_file = root / MANIFEST
    if manifest_file.is_symlink() or digest(manifest_file) != expected_manifest_sha:
        raise ValueError("manifest checksum mismatch")
    manifest = json.loads(manifest_file.read_bytes())
    if manifest.get("format") != "sulfi-preservation-copy" or manifest.get("schema") != 1:
        raise ValueError("unknown preservation format")
    if manifest.get("ownerBinding") != expected_owner:
        raise ValueError("owner mismatch; no alias guessing")
    files = manifest["files"]
    for name, row in files.items():
        relative(name)
        if not isinstance(row.get("bytes"), int) or row["bytes"] < 0 or len(row.get("sha256", "")) != 64:
            raise ValueError("invalid file metadata")
    if inventory(root) != files:
        raise ValueError("missing/extra/tampered files")
    version = verify_sqlite_copy(root, manifest["database"])
    if version != manifest["sqliteVersion"] or inventory(root) != files:
        raise ValueError("database changed")
    if destination is not None:
        independent_destination(root, destination)
    if not dry_run:
        if destination is None:
            raise ValueError("new isolated destination required")
        write_copy(root, destination, files)
    return {"mode": "DRY_RUN" if dry_run else "ISOLATED_COPY_CREATED", "files": len(files),
            "sqliteVersion": version, "source": "UNCHANGED", "ownerCheck": "EXACT_CALLER_BINDING"}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("operation", choices=["snapshot", "restore"])
    p.add_argument("--copy-root", required=True)
    p.add_argument("--owner", required=True, help="exact trusted caller binding, not a Google token")
    p.add_argument("--database", default="library.sqlite")
    p.add_argument("--manifest-sha256")
    p.add_argument("--destination")
    p.add_argument("--assert-copy-only", action="store_true")
    p.add_argument("--write-copy", action="store_true", help="default is read-only dry-run")
    a = p.parse_args()
    common = dict(destination=a.destination, dry_run=not a.write_copy, copy_confirmed=a.assert_copy_only)
    try:
        result = snapshot(a.copy_root, a.owner, a.database, **common) if a.operation == "snapshot" else restore(
            a.copy_root, a.owner, a.manifest_sha256, **common)
        print(json.dumps(result, sort_keys=True))  # counts only; no filenames/owner/payload
    except (ValueError, OSError, sqlite3.DatabaseError, KeyError, TypeError):
        p.exit(2, "BLOCKED: copy validation failed; source preserved. Inspect locally, do not retry blindly.\n")


if __name__ == "__main__":
    main()
