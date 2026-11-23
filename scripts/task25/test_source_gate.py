"""Safety boundary: immutable sources and no silent rebaselining/path escape."""
import hashlib
from pathlib import Path
import tempfile
import unittest

from source_gate import audit, check_pins


class SourceGateTest(unittest.TestCase):
    def test_real_integration_ancestry_and_all_runtime_pins(self):
        result = audit()
        self.assertEqual(result["status"], "PASS_SOURCE")
        self.assertGreater(result["runtimeFilesChecked"], 200)
        self.assertTrue(all(result["dependencyAncestry"].values()))
        self.assertEqual(result["ownerDevice"], "NOT_RUN")

    def test_modified_or_deleted_native_file_refuses_without_repinning(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            path = root / "native.kt"
            path.write_bytes(b"reviewed")
            pins = {"native.kt": hashlib.sha256(b"reviewed").hexdigest()}
            self.assertEqual(check_pins(root, pins), [])
            path.write_bytes(b"changed signing config")
            self.assertEqual(check_pins(root, pins)[0]["reason"], "hash_mismatch")
            self.assertEqual(path.read_bytes(), b"changed signing config")
            path.unlink()
            self.assertEqual(check_pins(root, pins)[0]["reason"], "missing")
            self.assertEqual(pins["native.kt"], hashlib.sha256(b"reviewed").hexdigest())

    def test_same_bytes_symlink_is_not_approved_source(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "outside").write_bytes(b"same")
            (root / "link").symlink_to(root / "outside")
            result = check_pins(root, {"link": hashlib.sha256(b"same").hexdigest()})
            self.assertEqual(result, [{"path": "link", "reason": "symlink"}])

    def test_manifest_path_escape_never_reads_external_file(self):
        for path in ["../outside", "/etc/passwd", "lib/../../outside"]:
            with self.assertRaises(ValueError):
                check_pins(Path("/nonexistent"), {path: "0" * 64})


if __name__ == "__main__":
    unittest.main()
