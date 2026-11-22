#!/usr/bin/env python3
"""Inspect the EXISTING public certificate, never sign/build/deploy an APK.

Activation needs a separately approved trusted-main workflow. No key password,
Google credentials, network, private-key export or application data are used.
Only the small public result is eligible for upload; temporary store is erased.
"""
import base64
import binascii
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

REPOSITORY = "luxhypnomaster/sulfi-hypnotherapy"
OWNER = "luxhypnomaster"
WORKFLOW = ".github/workflows/sulfi-signing-inspect25.yml"
CONFIRMATION = "READ_ONLY_EXISTING_CERTIFICATE"
CERT = "0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6"
MAX_STORE = 1024 * 1024


class InspectError(Exception):
    """A fixed, non-sensitive code; never include tool stderr or secret values."""


def trusted_context(env):
    expected = {
        "GITHUB_REPOSITORY": REPOSITORY,
        "GITHUB_EVENT_NAME": "workflow_dispatch",
        "GITHUB_REF": "refs/heads/main",
        "GITHUB_REF_PROTECTED": "true",
        "GITHUB_ACTOR": OWNER,
        "GITHUB_TRIGGERING_ACTOR": OWNER,
        "GITHUB_WORKFLOW_REF": f"{REPOSITORY}/{WORKFLOW}@refs/heads/main",
        "TASK25_INSPECT_CONFIRMATION": CONFIRMATION,
    }
    for key, value in expected.items():
        if env.get(key) != value:
            raise InspectError("TRUSTED_OWNER_MANUAL_MAIN_REQUIRED")
    if not re.fullmatch(r"[0-9a-f]{40}", env.get("GITHUB_SHA", "")):
        raise InspectError("EXACT_TOOL_SOURCE_REQUIRED")
    root = Path(env.get("RUNNER_TEMP", ""))
    if not root.is_absolute() or root.is_symlink() or not root.is_dir():
        raise InspectError("SAFE_RUNNER_TEMP_REQUIRED")
    return root


def inspect(env, root, *, runner=subprocess.run):
    # Call only AFTER trusted_context. No access to credentials precedes it.
    encoded = env.get("SULFI_TEST_KEYSTORE_BASE64", "")
    password = env.get("SULFI_TEST_STORE_PASSWORD", "")
    alias = env.get("SULFI_TEST_KEY_ALIAS", "")
    if not encoded or not password or not alias:
        raise InspectError("EXISTING_SIGNING_SECRET_MISSING")
    if len(encoded) > (MAX_STORE * 2):
        raise InspectError("INVALID_STORE_ENCODING_OR_SIZE")
    try:
        store = base64.b64decode("".join(encoded.split()), validate=True)
    except (binascii.Error, ValueError):
        raise InspectError("INVALID_STORE_ENCODING_OR_SIZE") from None
    if not store or len(store) > MAX_STORE:
        raise InspectError("INVALID_STORE_ENCODING_OR_SIZE")
    if any(c in alias for c in "\r\n\x00"):
        raise InspectError("INVALID_ALIAS")
    java = Path(env.get("JAVA_HOME_21_X64", "")) / "bin/keytool"
    tool = str(java) if java.is_absolute() and java.is_file() else shutil.which("keytool")
    if not tool:
        raise InspectError("KEYTOOL_UNAVAILABLE")
    # Password supplied via environment, not argv. Do not forward all CI secrets.
    child_env = {k: env[k] for k in ("PATH", "JAVA_HOME", "LANG", "HOME") if k in env}
    child_env["SULFI_INSPECT_STORE_PASSWORD"] = password
    with tempfile.TemporaryDirectory(prefix=".sulfi25-cert-", dir=root) as temp:
        os.chmod(temp, 0o700)
        path = Path(temp) / "existing-store"
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as out:
            out.write(store)
            out.flush()
            os.fsync(out.fileno())
        common = ["-keystore", str(path), "-alias", alias,
                  "-storepass:env", "SULFI_INSPECT_STORE_PASSWORD"]

        def keytool(operation):
            try:
                result = runner(
                    [tool, "-J-Duser.language=en", "-J-Duser.country=US", *operation, *common],
                    env=child_env, stdin=subprocess.DEVNULL, capture_output=True,
                    timeout=30, check=False, shell=False,
                )
            except (OSError, subprocess.SubprocessError):
                raise InspectError("CERTIFICATE_TOOL_FAILED") from None
            if result.returncode != 0:
                raise InspectError("CERTIFICATE_TOOL_FAILED")
            return result.stdout

        listing = keytool(["-list", "-v"]).decode("utf-8", errors="replace")
        if not re.search(r"^Entry type:\s*PrivateKeyEntry\s*$", listing, re.MULTILINE):
            raise InspectError("PRIVATE_KEY_ENTRY_NOT_CONFIRMED")
        der = keytool(["-exportcert"])
        if not der or len(der) > 128 * 1024:
            raise InspectError("INVALID_CERTIFICATE_OUTPUT")
        if hashlib.sha256(der).hexdigest() != CERT:
            raise InspectError("HISTORICAL_CERTIFICATE_MISMATCH_STOP")
    # The temporary store has been deleted BEFORE producing a success receipt.
    return {
        "status": "PASS_PUBLIC_CERTIFICATE_INSPECT_ONLY",
        "certificateSHA256": CERT,
        "privateKeyEntry": "PRESENT_ACCORDING_TO_KEYTOOL_LIST",
        "keyPasswordValidity": "NOT_TESTED_NOT_REQUESTED",
        "privateSigningUsable": "NOT_PROVEN_BY_PUBLIC_CERTIFICATE_INSPECTION",
        "temporaryStore": "REMOVED_BEFORE_RECEIPT",
        "APKs": "NOT_BUILT",
        "nativeUpgrade": "NOT_RUN",
        "production": "NOT_ACCESSED",
    }


def run(env, *, runner=subprocess.run):
    # Reject PR/fork/other actors/ref/workflow BEFORE even reading secret fields.
    root = trusted_context(env)
    public_dir = root / "task25-signing-inspect"
    if public_dir.exists() or public_dir.is_symlink():
        raise InspectError("PUBLIC_OUTPUT_MUST_BE_NEW")
    public_dir.mkdir(mode=0o700)
    code = 0
    try:
        result = inspect(env, root, runner=runner)
    except InspectError as error:
        result = {"status": "BLOCKED", "code": str(error), "APKs": "NOT_BUILT"}
        code = 1
    except Exception:
        # Never serialize subprocess args, exception repr, stdout or stderr.
        result = {"status": "BLOCKED", "code": "INSPECTION_OR_CLEANUP_FAILED", "APKs": "NOT_BUILT"}
        code = 1
    result["toolSourceSHA"] = env["GITHUB_SHA"]
    result["purpose"] = "Task25 existing certificate read-only; not Android acceptance"
    (public_dir / "public-result.json").write_text(json.dumps(result, indent=2) + "\n")
    return code, result


def main():
    if len(sys.argv) != 1:
        print("SIGNING_INSPECT_BLOCKED: NO_EXECUTE_OR_BUILD_OPTIONS_SUPPORTED")
        return 1
    try:
        code, result = run(os.environ)
        print(result["status"])
        return code
    except Exception:
        print("SIGNING_INSPECT_BLOCKED: TRUST_OR_OUTPUT_GUARD")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
