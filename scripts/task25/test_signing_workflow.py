"""Parse the inactive proposal and reject credential/trigger/artifact expansion."""
import hashlib
from pathlib import Path
import re
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
PROPOSAL = ROOT / "scripts/task25/review_only/sulfi-signing-inspect25.yml"


class WorkflowTest(unittest.TestCase):
    def setUp(self):
        self.text = PROPOSAL.read_text()
        self.w = yaml.safe_load(self.text)
        self.job = self.w["jobs"]["inspect"]

    def test_proposal_cannot_be_dispatched_from_feature_branch(self):
        self.assertFalse((ROOT / ".github/workflows/sulfi-signing-inspect25.yml").exists())
        self.assertEqual(set(self.w["on"]), {"workflow_dispatch"})
        self.assertEqual(self.w["permissions"], {"contents": "read"})
        self.assertEqual(list(self.w["jobs"]), ["inspect"])
        self.assertNotIn("env", self.w)
        self.assertNotIn("env", self.job)

    def test_owner_main_dispatch_and_re_run_actor_are_all_required(self):
        condition = self.job["if"]
        for required in [
            "github.repository == 'luxhypnomaster/sulfi-hypnotherapy'",
            "github.event_name == 'workflow_dispatch'", "github.ref == 'refs/heads/main'",
            "github.actor == 'luxhypnomaster'", "github.triggering_actor == 'luxhypnomaster'",
            "inputs.confirmation == 'READ_ONLY_EXISTING_CERTIFICATE'",
        ]:
            self.assertIn(required, condition)
        self.assertNotIn("||", condition)
        inputs = self.w["on"]["workflow_dispatch"]["inputs"]
        self.assertEqual(set(inputs), {"confirmation"})
        self.assertEqual(inputs["confirmation"]["default"], "")

    def test_only_inspection_step_gets_three_required_existing_secrets(self):
        steps = self.job["steps"]
        secret_steps = [s for s in steps if "secrets." in str(s)]
        self.assertEqual(len(secret_steps), 1)
        step = secret_steps[0]
        self.assertEqual(step["run"], "python3 scripts/task25/signing_inspect.py")
        self.assertEqual(set(step["env"]), {
            "TASK25_INSPECT_CONFIRMATION", "SULFI_TEST_KEYSTORE_BASE64",
            "SULFI_TEST_STORE_PASSWORD", "SULFI_TEST_KEY_ALIAS",
        })
        self.assertNotIn("CLASPRC_JSON", self.text)
        self.assertNotIn("SULFI_TEST_KEY_PASSWORD", self.text)
        self.assertLess(steps.index(next(s for s in steps if "Verify approved" in s["name"])), steps.index(step))

    def test_reviewed_tool_hash_and_actions_are_immutable(self):
        expected = hashlib.sha256((ROOT / "scripts/task25/signing_inspect.py").read_bytes()).hexdigest()
        self.assertIn("expected = '" + expected + "'", self.text)
        for step in self.job["steps"]:
            if "uses" in step:
                self.assertRegex(step["uses"], r"^actions/(checkout|upload-artifact)@[0-9a-f]{40}$")
        checkout = self.job["steps"][0]
        self.assertEqual(checkout["with"]["ref"], "${{ github.sha }}")
        self.assertFalse(checkout["with"]["persist-credentials"])
        self.assertEqual(checkout["with"]["sparse-checkout"], "scripts/task25/signing_inspect.py")

    def test_upload_cannot_capture_keystore_workspace_or_apks(self):
        step = next(s for s in self.job["steps"] if "upload-artifact" in s.get("uses", ""))
        self.assertEqual(step["with"]["path"], "${{ runner.temp }}/task25-signing-inspect/public-result.json")
        self.assertFalse(step["with"]["include-hidden-files"])
        self.assertFalse(step["with"]["overwrite"])
        self.assertIn("github.run_attempt", step["with"]["name"])
        self.assertFalse(self.w["concurrency"]["cancel-in-progress"])
        for phrase in ["flutter build", "apksigner sign", "clasp", "gh release", "git push", "pull_request_target:"]:
            self.assertNotIn(phrase, self.text)

    def test_both_embedded_python_blocks_compile_without_execution(self):
        run_steps = [s for s in self.job["steps"] if "python3 - <<'" in s.get("run", "")]
        self.assertEqual(len(run_steps), 2)
        for step in run_steps:
            lines = step["run"].splitlines()
            delimiter = re.search(r"<<'([^']+)'", lines[0])[1]
            self.assertEqual(lines[-1], delimiter)
            compile("\n".join(lines[1:-1]), "review-only-embedded-python", "exec")


if __name__ == "__main__":
    unittest.main()
