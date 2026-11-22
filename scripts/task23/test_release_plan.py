import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import release_plan as r


class ReleasePlanTest(unittest.TestCase):
    def test_plan_has_both_unchanged_ids_pins_and_no_execution(self):
        # Trap subprocess: the planner must only read source files.
        with patch.object(subprocess, "run", side_effect=AssertionError("native execution forbidden")):
            plan = r.plan("a" * 40, 29)
        self.assertFalse(plan["execute"])
        self.assertEqual(plan["status"], "DEFERRED_BY_OWNER")
        self.assertEqual([x["applicationId"] for x in plan["commandsForFutureApprovedTaskOnly"]], list(r.IDS.values()))
        self.assertIn("NOT APK", plan["artifactRule"])
        self.assertEqual(plan["toolchain"]["gradle"], "9.3.1")
        self.assertNotIn("PASSWORD", json.dumps(plan))

    def test_downgrade_reused_code_and_nonexact_source_rejected(self):
        for code in (0, 25, 28):
            with self.assertRaises(ValueError):
                r.plan("a" * 40, code)
        with self.assertRaises(ValueError):
            r.plan("a" * 40, 29, installed_code=30)
        with self.assertRaises(ValueError):
            r.plan("main", 29)

    def test_cli_execute_refused_before_any_build(self):
        result = subprocess.run([sys.executable, str(Path(r.__file__)), "--source", "a" * 40,
                                 "--version-code", "29", "--execute"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("DEFERRED_BY_OWNER", result.stderr)

    def test_native_drift_not_silently_rebaselined(self):
        pins = json.loads((r.ROOT / "scripts/task23/native_source_pins.json").read_text())
        changed = copy.deepcopy(pins)
        changed["files"]["pubspec.yaml"] = "0" * 64
        original = Path.read_text
        def read(path, *a, **kw):
            return json.dumps(changed) if path.name == "native_source_pins.json" else original(path, *a, **kw)
        with patch.object(Path, "read_text", read):
            with self.assertRaisesRegex(ValueError, "drift"):
                r.plan("a" * 40, 29)


if __name__ == "__main__":
    unittest.main(verbosity=2)
