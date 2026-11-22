"""Controlled canary subprocesses only; no keystore/certificate is generated."""
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import signing_inspect as si


class InspectTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="controlled-inspect25-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = {
            "GITHUB_REPOSITORY": si.REPOSITORY, "GITHUB_EVENT_NAME": "workflow_dispatch",
            "GITHUB_REF": "refs/heads/main", "GITHUB_ACTOR": si.OWNER,
            "GITHUB_TRIGGERING_ACTOR": si.OWNER,
            "GITHUB_REF_PROTECTED": "true",
            "GITHUB_WORKFLOW_REF": f"{si.REPOSITORY}/{si.WORKFLOW}@refs/heads/main",
            "TASK25_INSPECT_CONFIRMATION": si.CONFIRMATION, "GITHUB_SHA": "1" * 40,
            "RUNNER_TEMP": str(self.root), "PATH": "/usr/bin:/bin",
            "SULFI_TEST_KEYSTORE_BASE64": base64.b64encode(b"controlled-store-canary").decode(),
            "SULFI_TEST_STORE_PASSWORD": "PASSWORD_CANARY_MUST_NEVER_LEAK",
            "SULFI_TEST_KEY_ALIAS": "ALIAS_CANARY_MUST_NEVER_LEAK",
            "SULFI_TEST_KEY_PASSWORD": "UNNECESSARY_KEY_PASSWORD_NEVER_REQUESTED",
            "CLASPRC_JSON": "UNRELATED_SECRET_MUST_NOT_BE_FORWARDED",
        }
        self.calls = []
        self.der = b"CONTROLLED_PUBLIC_BYTES_NOT_A_CERTIFICATE"

    def fake(self, args, **kwargs):
        self.calls.append((args, kwargs))
        self.assertNotIn(self.env["SULFI_TEST_STORE_PASSWORD"], args)
        self.assertNotIn("CLASPRC_JSON", kwargs["env"])
        self.assertNotIn("SULFI_TEST_KEY_PASSWORD", kwargs["env"])
        self.assertNotIn("SULFI_TEST_KEYSTORE_BASE64", kwargs["env"])
        self.assertEqual(kwargs["shell"], False)
        self.assertEqual(kwargs["stdin"], subprocess.DEVNULL)
        store = Path(args[args.index("-keystore") + 1])
        self.assertEqual(store.stat().st_mode & 0o777, 0o600)
        self.assertEqual(store.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(store.read_bytes(), b"controlled-store-canary")
        out = b"Entry type: PrivateKeyEntry\n" if "-list" in args else self.der
        return subprocess.CompletedProcess(args, 0, stdout=out, stderr=b"CANARY_NEVER_PRINT")

    def assert_no_store(self):
        self.assertFalse(list(self.root.glob(".sulfi25-cert-*")))
        text = "\n".join(p.read_text() for p in self.root.rglob("public-result.json"))
        for secret in ["PASSWORD_CANARY", "ALIAS_CANARY", "controlled-store-canary", "CANARY_NEVER_PRINT", "UNRELATED_SECRET"]:
            self.assertNotIn(secret, text)

    def test_controlled_certificate_match_is_not_private_signing_or_native_pass(self):
        with patch.object(si, "CERT", hashlib.sha256(self.der).hexdigest()):
            code, result = si.run(self.env, runner=self.fake)
        self.assertEqual(code, 0)
        self.assertEqual(result["APKs"], "NOT_BUILT")
        self.assertEqual(result["nativeUpgrade"], "NOT_RUN")
        self.assertEqual(result["keyPasswordValidity"], "NOT_TESTED_NOT_REQUESTED")
        self.assertIn("NOT_PROVEN", result["privateSigningUsable"])
        self.assertEqual(len(self.calls), 2)
        self.assert_no_store()

    def test_untrusted_context_cannot_even_read_secret_fields(self):
        class NoSecretReads(dict):
            def get(self, key, default=None):
                if key.startswith("SULFI_TEST_"):
                    raise AssertionError("secret accessed before trusted guard")
                return super().get(key, default)
        for key, bad in {
            "GITHUB_REPOSITORY": "fork/sulfi-hypnotherapy", "GITHUB_EVENT_NAME": "pull_request_target",
            "GITHUB_REF": "refs/heads/feat/task25", "GITHUB_ACTOR": "other-maintainer",
            "GITHUB_TRIGGERING_ACTOR": "other-maintainer",
            "GITHUB_WORKFLOW_REF": f"{si.REPOSITORY}/other.yml@refs/heads/main",
            "TASK25_INSPECT_CONFIRMATION": "", "GITHUB_SHA": "main",
        }.items():
            with self.subTest(key=key):
                env = NoSecretReads(self.env); env[key] = bad
                with self.assertRaises(si.InspectError):
                    si.run(env, runner=self.fake)
        self.assertFalse(self.calls)
        self.assertFalse(list(self.root.iterdir()))

    def test_pull_request_fork_push_and_workflow_run_all_denied(self):
        for event in ["pull_request", "push", "workflow_run", "release"]:
            self.env["GITHUB_EVENT_NAME"] = event
            with self.assertRaises(si.InspectError):
                si.run(self.env, runner=self.fake)
        self.assertFalse(self.calls)

    def test_unprotected_main_must_refuse_before_reading_any_secret(self):
        class NoSecretReads(dict):
            def get(self, key, default=None):
                if key.startswith("SULFI_TEST_"):
                    raise AssertionError("unprotected ref reached secret read")
                return super().get(key, default)
        env = NoSecretReads(self.env)
        env["GITHUB_REF_PROTECTED"] = "false"
        with self.assertRaises(si.InspectError):
            si.run(env, runner=self.fake)
        self.assertFalse(self.calls)
        self.assertFalse(list(self.root.iterdir()))

    def test_missing_secret_has_public_code_and_no_temp_store(self):
        del self.env["SULFI_TEST_KEYSTORE_BASE64"]
        code, result = si.run(self.env, runner=self.fake)
        self.assertEqual(code, 1)
        self.assertEqual(result["code"], "EXISTING_SIGNING_SECRET_MISSING")
        self.assertFalse(self.calls)
        self.assert_no_store()

    def test_invalid_and_oversize_stores_never_launch_keytool(self):
        for value in ["%invalid%", "a" * (2 * si.MAX_STORE + 1), "\u2603", " "]:
            with self.subTest(size=len(value)):
                (self.root / "task25-signing-inspect").mkdir(exist_ok=True)
                for f in (self.root / "task25-signing-inspect").iterdir(): f.unlink()
                (self.root / "task25-signing-inspect").rmdir()
                self.env["SULFI_TEST_KEYSTORE_BASE64"] = value
                code, result = si.run(self.env, runner=self.fake)
                self.assertEqual(code, 1)
                self.assertEqual(result["code"], "INVALID_STORE_ENCODING_OR_SIZE")
        self.assertFalse(self.calls)
        self.assert_no_store()

    def test_wrong_certificate_is_stop_not_signing_pass(self):
        code, result = si.run(self.env, runner=self.fake)
        self.assertEqual(code, 1)
        self.assertEqual(result["code"], "HISTORICAL_CERTIFICATE_MISMATCH_STOP")
        self.assert_no_store()

    def test_tool_failure_stderr_and_argv_never_in_public_receipt(self):
        def fail(args, **kwargs):
            self.fake(args, **kwargs)
            return subprocess.CompletedProcess(args, 1, stdout=b"PASSWORD_CANARY", stderr=b"ALIAS_CANARY")
        code, result = si.run(self.env, runner=fail)
        self.assertEqual(code, 1)
        self.assertEqual(result["code"], "CERTIFICATE_TOOL_FAILED")
        self.assert_no_store()

    def test_timeout_cleanup_is_bounded_and_has_no_exception_echo(self):
        def timeout(args, **kwargs):
            self.fake(args, **kwargs)
            raise subprocess.TimeoutExpired(args, 30, output=b"PASSWORD_CANARY")
        code, result = si.run(self.env, runner=timeout)
        self.assertEqual(code, 1)
        self.assertEqual(result["code"], "CERTIFICATE_TOOL_FAILED")
        self.assert_no_store()

    def test_unexpected_exception_is_redacted_and_store_deleted(self):
        def fail(args, **kwargs):
            raise ValueError("PASSWORD_CANARY")
        code, result = si.run(self.env, runner=fail)
        self.assertEqual(code, 1)
        self.assertEqual(result["code"], "INSPECTION_OR_CLEANUP_FAILED")
        self.assert_no_store()

    def test_trusted_cert_entry_does_not_prove_private_key_entry(self):
        def certificate_only(args, **kwargs):
            self.fake(args, **kwargs)
            return subprocess.CompletedProcess(args, 0, stdout=b"Entry type: trustedCertEntry\n", stderr=b"")
        code, result = si.run(self.env, runner=certificate_only)
        self.assertEqual(code, 1)
        self.assertEqual(result["code"], "PRIVATE_KEY_ENTRY_NOT_CONFIRMED")
        self.assertEqual(len(self.calls), 1)
        self.assert_no_store()

    def test_preexisting_or_symlink_output_never_overwritten(self):
        path = self.root / "task25-signing-inspect"
        path.mkdir(); marker = path / "public-result.json";marker.write_text("PRESERVE")
        with self.assertRaises(si.InspectError):si.run(self.env, runner=self.fake)
        self.assertEqual(marker.read_text(), "PRESERVE")
        marker.unlink();path.rmdir();path.symlink_to(self.root)
        with self.assertRaises(si.InspectError):si.run(self.env, runner=self.fake)
        self.assertFalse(self.calls)

    def test_no_build_sign_export_private_key_or_network_operations(self):
        source = Path(si.__file__).read_text()
        self.assertNotIn("requests.", source)
        self.assertNotIn("urlopen(", source)
        self.assertNotIn("-importkeystore", source)
        self.assertNotIn("-genkeypair", source)
        self.assertNotIn("flutter build", source)
        self.assertNotIn("apksigner sign", source)
        self.assertNotIn("SULFI_TEST_KEY_PASSWORD", source)


if __name__ == "__main__":
    unittest.main()
