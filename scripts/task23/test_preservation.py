import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

import preservation as p


class PreservationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="task23-test-")
        self.root = Path(self.temp.name) / "synthetic"
        self.root.mkdir()
        db = sqlite3.connect(self.root / "library.sqlite")
        db.execute("PRAGMA user_version=9")
        db.execute("CREATE TABLE exact_payload(id TEXT PRIMARY KEY, payload TEXT)")
        db.execute("INSERT INTO exact_payload VALUES(?,?)", ("same-ID", '{"frozen":["audio-1",2]}'))
        db.commit()
        db.close()
        (self.root / "audio").mkdir()
        (self.root / "audio/unknown-owner.part").write_bytes(b"SYNTHETIC_ONLY_NOT_GC")
        self.before = p.inventory(self.root)
        self.backup = Path(self.temp.name) / "snapshot"
        self.dst = Path(self.temp.name) / "restore"

    def tearDown(self):
        self.temp.cleanup()

    def snapshot(self, **args):
        return p.snapshot(self.root, "synthetic-owner-A", destination=self.backup,
                          copy_confirmed=True, **args)

    def restore(self, sha, **args):
        return p.restore(self.backup, "synthetic-owner-A", sha, destination=self.dst,
                         copy_confirmed=True, **args)

    def test_dry_run_never_creates_destination_and_requires_explicit_copy(self):
        result = self.snapshot()
        self.assertEqual(result["mode"], "DRY_RUN")
        self.assertFalse(self.backup.exists())
        with self.assertRaises(ValueError):
            p.snapshot(self.root, "synthetic-owner-A")
        self.assertEqual(p.inventory(self.root), self.before)

    def test_roundtrip_retains_every_byte_and_unknown_file_without_source_changes(self):
        result = self.snapshot(dry_run=False)
        self.restore(result["manifestSHA256"])
        self.assertFalse(self.dst.exists())
        self.restore(result["manifestSHA256"], dry_run=False)
        self.assertEqual(p.inventory(self.root), self.before)
        self.assertEqual(p.inventory(self.dst), self.before)
        self.assertEqual(p.inventory(self.backup), self.before)
        db = sqlite3.connect(self.dst / "library.sqlite")
        self.assertEqual(db.execute("SELECT * FROM exact_payload").fetchall(),
                         [("same-ID", '{"frozen":["audio-1",2]}')])
        db.close()

    def test_wrong_owner_or_unpinned_manifest_does_not_write(self):
        result = self.snapshot(dry_run=False)
        with self.assertRaisesRegex(ValueError, "owner"):
            p.restore(self.backup, "owner-B", result["manifestSHA256"], self.dst,
                      dry_run=False, copy_confirmed=True)
        with self.assertRaises(ValueError):
            self.restore("0" * 64, dry_run=False)
        self.assertFalse(self.dst.exists())
        self.assertEqual(p.inventory(self.root), self.before)

    def test_checksum_missing_extra_or_corrupt_file_rejected_before_writes(self):
        result = self.snapshot(dry_run=False)
        kept = self.backup / "audio/unknown-owner.part"
        original = kept.read_bytes()
        for action in (lambda: kept.write_bytes(b"TAMPER"), lambda: kept.unlink(),
                       lambda: (self.backup / "extra").write_text("unexpected")):
            kept.write_bytes(original)
            extra = self.backup / "extra"
            if extra.exists():
                extra.unlink()
            action()
            with self.assertRaises(ValueError):
                self.restore(result["manifestSHA256"], dry_run=False)
            self.assertFalse(self.dst.exists())

    def test_corrupt_sqlite_preserved_and_no_snapshot_created(self):
        db = self.root / "library.sqlite"
        db.write_bytes(b"NOT_A_SQLITE_DATABASE")
        before = p.inventory(self.root)
        with self.assertRaises(sqlite3.DatabaseError):
            self.snapshot(dry_run=False)
        self.assertEqual(p.inventory(self.root), before)
        self.assertFalse(self.backup.exists())

    def test_no_overwrite_no_nested_dest_no_symlinks(self):
        self.backup.mkdir()
        (self.backup / "valuable").write_text("KEEP")
        with self.assertRaises(ValueError):
            self.snapshot(dry_run=False)
        self.assertEqual((self.backup / "valuable").read_text(), "KEEP")
        with self.assertRaises(ValueError):
            p.snapshot(self.root, "A", destination=self.root / "nested", copy_confirmed=True)
        (self.root / "audio/link").symlink_to(self.root / "library.sqlite")
        with self.assertRaises(ValueError):
            p.snapshot(self.root, "A", copy_confirmed=True)

    def test_traversal_in_manifest_refused_even_when_rehashed(self):
        self.snapshot(dry_run=False)
        path = self.backup / p.MANIFEST
        doc = json.loads(path.read_bytes())
        doc["files"]["../escape"] = {"sha256": "0" * 64, "bytes": 0}
        path.write_bytes(p.canonical(doc))
        with self.assertRaises(ValueError):
            self.restore(p.digest(path), dry_run=False)
        self.assertFalse(self.dst.exists())

    def test_live_wal_copy_captures_rows_without_source_sqlite_write(self):
        db = sqlite3.connect(self.root / "library.sqlite")
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA wal_autocheckpoint=0")
        db.execute("INSERT INTO exact_payload VALUES('wal-only','kept')")
        db.commit()
        before = p.inventory(self.root)
        result = self.snapshot(dry_run=False)
        self.assertEqual(p.inventory(self.root), before)
        self.restore(result["manifestSHA256"], dry_run=False)
        check = sqlite3.connect(self.dst / "library.sqlite")
        self.assertEqual(check.execute("SELECT payload FROM exact_payload WHERE id='wal-only'").fetchone(), ("kept",))
        check.close()
        db.close()

    def test_changed_source_cleans_only_exclusively_created_derivative(self):
        original = p.shutil.copyfileobj
        def mutate(*args, **kwargs):
            original(*args, **kwargs)
            (self.root / "audio/unknown-owner.part").write_bytes(b"NEW_SOURCE_CONTENT")
        from unittest.mock import patch
        with patch.object(p.shutil, "copyfileobj", side_effect=mutate):
            with self.assertRaises(ValueError):
                self.snapshot(dry_run=False)
        self.assertFalse(self.backup.exists())
        self.assertEqual((self.root / "audio/unknown-owner.part").read_bytes(), b"NEW_SOURCE_CONTENT")


if __name__ == "__main__":
    unittest.main(verbosity=2)
