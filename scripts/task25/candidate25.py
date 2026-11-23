#!/usr/bin/env python3
"""Trusted-main candidate pipeline. Signing never executes application code.

Builds use a frozen, tested source WITHOUT signing credentials and with debug
signing disabled. Only the separate main-only data signer receives the old key.
No deploy, OAuth change, key generation, release, deletion or device operation.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile

REPO = "luxhypnomaster/sulfi-hypnotherapy"
OWNER = "luxhypnomaster"
SOURCE = "737ea741636e9abe7c20353d9d5b8301cf44a5bb"
CERT = "0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6"
WEB = "325102995568-07pk1fcqvfnkp27kkmv7ple39enin31d.apps.googleusercontent.com"
VERSION, CODE = "0.4.21", 29
BUILD_WORKFLOW = ".github/workflows/sulfi-candidates25-build.yml"
QA_WORKFLOW = ".github/workflows/sulfi-candidates25-verify.yml"
BUILD_CONFIRM = "BUILD_EXISTING_KEY_CANDIDATES_NO_DEPLOY"
QA_CONFIRM = "VERIFY_DISPOSABLE_ANDROID_ONLY"
IDS = {"master": "ru.sulfi.sulfi_hypnotherapy", "client": "ru.sulfi.sulfi_hypnotherapy.clienttest"}
BASELINES = {
    "master": (752461821, 193900724, "2bec82df8b75dcc6b8e6b49faf5f4244627003c137c2ded25b844d611cdd4d6e"),
    "client": (752462315, 193900756, "637195c8eb9771208be822fcfbef586023240c658072eb5c4edcbc3176026051"),
}
SIGNING_KEYS = ("SULFI_TEST_KEYSTORE_BASE64", "SULFI_TEST_STORE_PASSWORD", "SULFI_TEST_KEY_ALIAS", "SULFI_TEST_KEY_PASSWORD")
GRADLE_PIN = "f1fe33736d6d5943151611d6135940d6e20b483d77e672e528fb185905c534d4"


class GateError(Exception):
    pass


def digest(path):
    with Path(path).open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def guard(workflow=None):
    workflow = workflow or os.environ.get("CANDIDATE25_WORKFLOW")
    confirm = BUILD_CONFIRM if workflow == BUILD_WORKFLOW else QA_CONFIRM
    checks = {"GITHUB_REPOSITORY": REPO, "GITHUB_EVENT_NAME": "workflow_dispatch",
              "GITHUB_REF": "refs/heads/main", "GITHUB_REF_PROTECTED": "true",
              "GITHUB_ACTOR": OWNER, "GITHUB_TRIGGERING_ACTOR": OWNER,
              "GITHUB_WORKFLOW_REF": f"{REPO}/{workflow}@refs/heads/main",
              "CANDIDATE25_CONFIRMATION": confirm}
    if workflow not in (BUILD_WORKFLOW, QA_WORKFLOW) or any(os.environ.get(k) != v for k, v in checks.items()):
        raise GateError("TRUSTED_OWNER_PROTECTED_MAIN_REQUIRED")
    if not re.fullmatch(r"[0-9a-f]{40}", os.environ.get("GITHUB_SHA", "")):
        raise GateError("EXACT_MAIN_SOURCE_REQUIRED")
    root = Path(os.environ.get("RUNNER_TEMP", ""))
    if not root.is_absolute() or root.is_symlink() or not root.is_dir():
        raise GateError("SAFE_RUNNER_TEMP_REQUIRED")
    return root


def redact(text):
    for key in (*SIGNING_KEYS, "GH_TOKEN", "GITHUB_TOKEN"):
        value = os.environ.get(key)
        if value:
            text = text.replace(value, "***")
    return re.sub(r"(https://[^\s?'\"]+)\?[^\s'\"]+", r"\1?[REDACTED]", text)[-2000:]


def command(args, *, cwd=None, secret=False, live=False):
    if live:
        subprocess.run(args, cwd=cwd, check=True)
        return ""
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if r.returncode:
        detail = redact(r.stderr + "\n" + r.stdout)
        raise GateError(f"COMMAND_FAILED_{Path(args[0]).name}_{r.returncode}: {detail}")
    return r.stdout


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).scheme != "https":
            raise GateError("NON_TLS_REDIRECT_REFUSED")
        r = super().redirect_request(req, fp, code, msg, headers, newurl)
        if urllib.parse.urlsplit(req.full_url).netloc != urllib.parse.urlsplit(newurl).netloc:
            r.remove_header("Authorization")
        return r


def fetch(url, output=None, *, limit=1024 ** 3, accept="application/vnd.github+json"):
    if not url.startswith(f"https://api.github.com/repos/{REPO}/"):
        raise GateError("UNAPPROVED_API_ENDPOINT")
    token = os.environ.get("GH_TOKEN", "")
    if not token:
        raise GateError("SCOPED_DOWNLOAD_TOKEN_REQUIRED")
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token,
        "Accept": accept, "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "Sulfi-candidate25"})
    try:
        with urllib.request.build_opener(SafeRedirect()).open(req, timeout=120) as response:
            count = 0
            if output:
                with Path(output).open("xb") as out:
                    while chunk := response.read(1024 * 1024):
                        count += len(chunk)
                        if count > limit:
                            raise GateError("DOWNLOAD_SIZE_LIMIT")
                        out.write(chunk)
                return None
            raw = response.read(min(limit, 8 * 1024 * 1024) + 1)
            if len(raw) > min(limit, 8 * 1024 * 1024):
                raise GateError("JSON_SIZE_LIMIT")
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        try:
            reason = json.loads(e.read(8192)).get("message", "")
            reason = redact(reason) if isinstance(reason, str) else ""
        except (ValueError, UnicodeError):
            reason = ""
        host = urllib.parse.urlsplit(e.url).hostname or "unknown"
        raise GateError(f"DOWNLOAD_HTTP_{e.code} host={host}" + (": " + reason if reason else "")) from None
    except urllib.error.URLError as e:
        raise GateError("DOWNLOAD_NETWORK_" + type(e.reason).__name__) from None


def api(path):
    return fetch(f"https://api.github.com/repos/{REPO}/{path}")


def tools():
    sdk = Path(os.environ["ANDROID_HOME"])
    folder = sdk / "build-tools/36.0.0"
    if not all((folder / n).is_file() for n in ["apksigner", "aapt", "zipalign"]):
        raise GateError("PINNED_ANDROID_BUILD_TOOLS_36_REQUIRED")
    return folder


def check_apk(path, edition, code, *, signed, config=None):
    path = Path(path)
    if path.stat().st_size > 512 * 1024 ** 2:
        raise GateError("APK_SIZE_LIMIT")
    t = tools()
    badging = command([str(t / "aapt"), "dump", "badging", str(path)])
    version = VERSION if code == CODE else "0.4.20"
    if not all(x in badging for x in [f"name='{IDS[edition]}'", f"versionCode='{code}'", f"versionName='{version}'", "sdkVersion:'24'"]):
        raise GateError("PACKAGE_VERSION_SDK_MISMATCH")
    target = re.search(r"targetSdkVersion:'(\d+)'", badging)
    if not target or (code == CODE and int(target[1]) != 36) or not 24 <= int(target[1]) <= 36:
        raise GateError("UNEXPECTED_TARGET_SDK")
    if "application-debuggable" not in badging:
        raise GateError("QA_DEBUGGABLE_PACKAGE_REQUIRED_FOR_NATIVE_INVENTORY")
    manifest = command([str(t / "aapt"), "dump", "xmltree", str(path), "AndroidManifest.xml"])
    if any(("testOnly" in line or "usesCleartextTraffic" in line) and "0xffffffff" in line for line in manifest.splitlines()):
        raise GateError("TEST_ONLY_OR_CLEARTEXT_APK_REFUSED")
    for p in ["android.permission.RUN_USER_INITIATED_JOBS", "android.permission.FOREGROUND_SERVICE_DATA_SYNC", "android.permission.ACCESS_NETWORK_STATE"]:
        if p not in manifest:
            raise GateError("BACKGROUND_PERMISSION_MISSING")
    with zipfile.ZipFile(path) as z:
        if z.testzip() is not None:
            raise GateError("APK_ZIP_CRC_FAILED")
        for f in z.infolist():
            p = PurePosixPath(f.filename)
            if p.is_absolute() or ".." in p.parts or stat.S_ISLNK(f.external_attr >> 16) or f.filename.endswith((".keystore", ".jks", "/.env")):
                raise GateError("UNSAFE_APK_ENTRY")
        kernel = z.read("assets/flutter_assets/kernel_blob.bin")
        if config and any(config[k].encode() not in kernel for k in ["endpoint", "webClientId"]):
            raise GateError("LEGACY_PUBLIC_CONFIG_SCOPE_CHANGED")
        if b"CONTROLLED_NATIVE18_NO_GAS" in kernel or b"CONTROLLED_OWNER_18_" in kernel:
            raise GateError("PROBE_DART_IN_APK")
        dex = b"".join(z.read(n) for n in z.namelist() if n.endswith(".dex"))
        if b"Lru/sulfi/sulfi_hypnotherapy/probe/TransferProbeControl;" in dex or b"ru.sulfi/controlled18" in dex:
            raise GateError("PROBE_NATIVE_IN_APK")
        if b"SULFI_STORAGE_CORRUPT_NO_RESET" not in dex:
            raise GateError("NATIVE_STORAGE_GUARD_MISSING")
    verify = subprocess.run([str(t / "apksigner"), "verify", "--print-certs", str(path)], capture_output=True, text=True)
    if signed:
        certs = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-f]+)", verify.stdout)
        if verify.returncode or certs != [CERT]:
            raise GateError("HISTORICAL_CERTIFICATE_MISMATCH")
        align = [str(t / "zipalign"), "-c"] + (["-P", "16"] if code == CODE else []) + ["4", str(path)]
        command(align)
    elif verify.returncode == 0:
        raise GateError("UNSIGNED_JOB_PRODUCED_SIGNED_APK")
    return {"edition": edition, "package": IDS[edition], "versionCode": code, "versionName": version,
            "size": path.stat().st_size, "sha256": digest(path), "certificateSHA256": CERT if signed else None,
            "minSdk": 24, "targetSdk": int(target[1]), "debuggable": True, "ZIP_CRC": "PASS",
            "signed": signed}


def baselines(root):
    d = root / "task25-baseline"
    d.mkdir(exist_ok=True)
    endpoints = []
    for edition, (asset, size, sha) in BASELINES.items():
        f = d / f"{edition}28.apk"
        if not f.exists():
            fetch(f"https://api.github.com/repos/{REPO}/releases/assets/{asset}", f, limit=size, accept="application/octet-stream")
        if f.stat().st_size != size or digest(f) != sha:
            raise GateError("IMMUTABLE_BASELINE_SHA_OR_SIZE_MISMATCH")
        check_apk(f, edition, 28, signed=True)
        with zipfile.ZipFile(f) as z:
            kernel = z.read("assets/flutter_assets/kernel_blob.bin")
        urls = set(re.findall(rb"https://script\.google\.com/macros/s/[A-Za-z0-9_-]+/exec", kernel))
        if len(urls) != 1 or WEB.encode() not in kernel:
            raise GateError("UNAMBIGUOUS_BASELINE_PUBLIC_CONFIG_REQUIRED")
        endpoints.append(next(iter(urls)).decode())
    if endpoints[0] != endpoints[1]:
        raise GateError("BASELINE_EDITION_CONFIG_DIFFERS")
    config = {"endpoint": endpoints[0], "webClientId": WEB}
    write(d / "public-config.json", config)
    return config


def unsigned_patch(path):
    path = Path(path)
    if digest(path) != GRADLE_PIN:
        raise GateError("UNREVIEWED_NATIVE_BUILD_CONFIG")
    before = path.read_text()
    marker = "    buildTypes {\n        debug {\n"
    if before.count(marker) != 1:
        raise GateError("UNSIGNED_PATCH_ANCHOR_AMBIGUOUS")
    after = before.replace(marker, marker + "            signingConfig = null // trusted CI: unsigned data build; no new debug key\n", 1)
    path.write_text(after)
    return {"path": "android/app/build.gradle.kts", "beforeSHA256": GRADLE_PIN,
            "afterSHA256": digest(path), "purpose": "disable default debug signing in credential-free build only"}


def app_dir():
    p = Path(os.environ["GITHUB_WORKSPACE"]) / "appsource"
    if command(["git", "rev-parse", "HEAD"], cwd=p).strip() != SOURCE:
        raise GateError("UNREVIEWED_APP_SOURCE")
    return p


def build(root):
    if any(os.environ.get(k) for k in SIGNING_KEYS) or any(k.startswith("SULFI_SIGNING_") and v for k, v in os.environ.items()):
        raise GateError("SIGNING_CREDENTIALS_MUST_NOT_ENTER_BUILD_JOB")
    source = app_dir()
    config = baselines(root)
    pins = json.loads((source / "scripts/task23/native_source_pins.json").read_text())
    generated = "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
    for p, sha in pins["files"].items():
        if p == generated and not (source / p).exists():
            continue  # Git-ignored output; checked strictly AFTER locked pub get.
        if not (source / p).is_file():
            raise GateError("MISSING_REVIEWED_NATIVE_SOURCE_" + p)
        if digest(source / p) != sha:
            raise GateError("NATIVE_SOURCE_PIN_DRIFT_" + p)
    default_key = Path.home() / ".android/debug.keystore"
    before_key = (default_key.stat().st_size, default_key.stat().st_mtime_ns) if default_key.exists() else None
    command(["flutter", "pub", "get", "--enforce-lockfile"], cwd=source, live=True)
    # Check every pin, including generated registration, before any Gradle task.
    for p, sha in pins["files"].items():
        if not (source / p).is_file() or digest(source / p) != sha:
            raise GateError("NATIVE_SOURCE_PIN_DRIFT_AFTER_PUB_GET_" + p)
    patch = unsigned_patch(source / "android/app/build.gradle.kts")
    output = root / "task25-unsigned"
    output.mkdir()
    records = []
    for edition in IDS:
        args = ["flutter", "build", "apk", "--debug", "--no-pub", f"--build-name={VERSION}", f"--build-number={CODE}",
                "--dart-define=SULFI_METADATA_V1=false", "--dart-define=SULFI_PROJECT22=false",
                "--dart-define=SULFI_ALCHEMIST_API=" + config["endpoint"], "--dart-define=SULFI_GOOGLE_WEB_CLIENT_ID=" + WEB]
        if edition == "client":
            args.append("--dart-define=SULFI_EDITION=client")
        command(args, cwd=source, live=True)
        after_key = (default_key.stat().st_size, default_key.stat().st_mtime_ns) if default_key.exists() else None
        if after_key != before_key:
            raise GateError("DEFAULT_DEBUG_KEY_CREATED_OR_CHANGED_STOP")
        dest = output / f"{edition}29-unsigned.apk"
        shutil.copyfile(source / "build/app/outputs/flutter-apk/app-debug.apk", dest)
        records.append(check_apk(dest, edition, CODE, signed=False, config=config))
    write(output / "unsigned-manifest.json", {"applicationSourceSHA": SOURCE, "versionName": VERSION,
          "versionCode": CODE, "publicConfig": config, "nativeBuildOverlay": patch, "newKeyGenerated": False,
          "metadata21": False, "project22": False, "buildMainSHA": os.environ["GITHUB_SHA"], "pair": records})


def artifact(root, run_id, name, allowed, folder, *, require_complete=True):
    if not str(run_id).isdigit():
        raise GateError("NUMERIC_RUN_ID_REQUIRED")
    run = api(f"actions/runs/{run_id}")
    if run["head_branch"] != "main" or run["event"] != "workflow_dispatch" or run["actor"]["login"] != OWNER or run["path"].split("@")[0] != BUILD_WORKFLOW:
        raise GateError("UNTRUSTED_ARTIFACT_RUN")
    if require_complete and (run["status"] != "completed" or run["conclusion"] != "success"):
        raise GateError("BUILD_RUN_NOT_SUCCESSFUL")
    if not require_complete and run["head_sha"] != os.environ["GITHUB_SHA"]:
        raise GateError("CURRENT_RUN_SOURCE_MISMATCH")
    rows = [a for a in api(f"actions/runs/{run_id}/artifacts")["artifacts"] if a["name"] == name and not a["expired"]]
    if len(rows) != 1:
        raise GateError("EXACT_ARTIFACT_REQUIRED")
    a = rows[0]
    zip_path = root / f"download-{a['id']}.zip"
    fetch(f"https://api.github.com/repos/{REPO}/actions/artifacts/{a['id']}/zip", zip_path)
    if a.get("digest") and a["digest"] != "sha256:" + digest(zip_path):
        raise GateError("ARTIFACT_PROVIDER_SHA_MISMATCH")
    out = root / folder
    out.mkdir()
    with zipfile.ZipFile(zip_path) as z:
        if len(z.namelist()) != len(allowed) or set(z.namelist()) != set(allowed) or z.testzip() is not None:
            raise GateError("ARTIFACT_CONTENTS_OR_CRC_MISMATCH")
        for n in allowed:
            if z.getinfo(n).file_size > 512 * 1024 ** 2:
                raise GateError("ARTIFACT_ENTRY_SIZE_LIMIT")
            with z.open(n) as inp, (out / n).open("xb") as dest:
                shutil.copyfileobj(inp, dest)
    zip_path.unlink()
    return out, run


def sign(root):
    for key in SIGNING_KEYS:
        if not os.environ.get(key):
            raise GateError("EXISTING_SECRET_MISSING_" + key)
    d = root / "task25-unsigned"
    manifest = json.loads((d / "unsigned-manifest.json").read_text())
    if (manifest["applicationSourceSHA"] != SOURCE or manifest["versionCode"] != CODE
            or manifest["versionName"] != VERSION or manifest["buildMainSHA"] != os.environ["GITHUB_SHA"]
            or manifest["publicConfig"]["webClientId"] != WEB
            or manifest["metadata21"] or manifest["project22"]):
        raise GateError("UNSIGNED_PROVENANCE_MISMATCH")
    output = root / "task25-signed-quarantine"
    output.mkdir()
    store = base64.b64decode("".join(os.environ[SIGNING_KEYS[0]].split()), validate=True)
    if not store or len(store) > 1024 * 1024:
        raise GateError("INVALID_EXISTING_STORE")
    t = tools()
    records = []
    with tempfile.TemporaryDirectory(prefix=".sulfi25-sign-", dir=root) as temp:
        os.chmod(temp, 0o700)
        key = Path(temp) / "existing-store"
        fd = os.open(key, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(fd, "wb") as f:
            f.write(store)
        # Public cert first, before any APK signing. No key generation/import.
        exported = subprocess.run(["keytool", "-exportcert", "-keystore", str(key), "-alias", os.environ[SIGNING_KEYS[2]],
            "-storepass:env", SIGNING_KEYS[1]], capture_output=True)
        if exported.returncode or hashlib.sha256(exported.stdout).hexdigest() != CERT:
            raise GateError("EXISTING_CERTIFICATE_MISMATCH_STOP")
        for edition in IDS:
            src = d / f"{edition}29-unsigned.apk"
            checked = check_apk(src, edition, CODE, signed=False, config=manifest["publicConfig"])
            expected = next(x for x in manifest["pair"] if x["edition"] == edition)
            if checked["sha256"] != expected["sha256"]:
                raise GateError("UNSIGNED_APK_BYTES_CHANGED")
            aligned = Path(temp) / f"{edition}-aligned.apk"
            command([str(t / "zipalign"), "-P", "16", "-f", "4", str(src), str(aligned)])
            dest = output / f"{edition}29.apk"
            command([str(t / "apksigner"), "sign", "--ks", str(key), "--ks-key-alias", os.environ[SIGNING_KEYS[2]],
                "--ks-pass", "env:" + SIGNING_KEYS[1], "--key-pass", "env:" + SIGNING_KEYS[3],
                "--v4-signing-enabled", "false",
                "--out", str(dest), str(aligned)], secret=True)
            records.append(check_apk(dest, edition, CODE, signed=True, config=manifest["publicConfig"]))
    write(output / "signed-manifest.json", {**manifest, "pair": records, "certificateSHA256": CERT,
          "privateSigningUsable": "CONFIRMED_BY_TWO_ACTUAL_SIGNATURES", "temporaryStore": "REMOVED",
          "safeForOwnerInstall": False, "nativeSafety": "PENDING", "GooglePhysicalQA": "NOT_RUN"})


def signed_data(root, run):
    out, meta = artifact(root, run, f"quarantine25-{run}", ["master29.apk", "client29.apk", "signed-manifest.json"], "task25-signed-quarantine")
    manifest = json.loads((out / "signed-manifest.json").read_text())
    if manifest["applicationSourceSHA"] != SOURCE or manifest["versionCode"] != CODE or manifest["buildMainSHA"] != meta["head_sha"]:
        raise GateError("SIGNED_PROVENANCE_MISMATCH")
    for edition in IDS:
        actual = check_apk(out / f"{edition}29.apk", edition, CODE, signed=True, config=manifest["publicConfig"])
        expected = next(x for x in manifest["pair"] if x["edition"] == edition)
        if actual != expected:
            raise GateError("SIGNED_PAIR_READBACK_MISMATCH")
    write(root / "SIGNED_PAIR_INDEPENDENT_READBACK_25.json", {"buildRun": int(run), "buildMainSHA": meta["head_sha"],
          "applicationSourceSHA": SOURCE, "pair": manifest["pair"], "status": "PASS_SECOND_JOB_BYTE_IDENTITY_SIGNATURE_READBACK",
          "nativeSafety": "PENDING", "physicalPhones": "NOT_RUN"})


def baseline_data(root, run):
    same_run = str(run) == os.environ.get("GITHUB_RUN_ID")
    artifact(root, run, f"baseline25-{run}", ["master28.apk", "client28.apk", "public-config.json"],
             "task25-baseline", require_complete=not same_run)
    # Never trust the artifact manifest for historical bytes: original external
    # asset sizes/SHA/signatures and public configuration are independently checked.
    baselines(root)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=["trust", "credentials", "baseline", "baseline-data", "build", "unsigned-data", "sign", "signed-data"])
    p.add_argument("--run", type=int)
    args = p.parse_args()
    root = guard()
    try:
        if args.action == "trust":
            print("PASS_TRUSTED_PROTECTED_MAIN_NO_SECRETS")
        elif args.action == "credentials":
            if any(not os.environ.get(k) for k in SIGNING_KEYS):
                raise GateError("EXISTING_SIGNING_SECRET_MISSING")
            print("EXISTING_FOUR_SECRET_BINDINGS_PRESENT_NOT_YET_SIGNED")
        elif args.action == "baseline":
            baselines(root)
            print("IMMUTABLE_BASELINES_AND_LEGACY_PUBLIC_CONFIG_VERIFIED")
        elif args.action == "build":
            build(root)
        elif args.action == "baseline-data":
            baseline_data(root, args.run or int(os.environ["GITHUB_RUN_ID"]))
        elif args.action == "unsigned-data":
            artifact(root, os.environ["GITHUB_RUN_ID"], f"unsigned25-{os.environ['GITHUB_RUN_ID']}",
                     ["master29-unsigned.apk", "client29-unsigned.apk", "unsigned-manifest.json"], "task25-unsigned", require_complete=False)
        elif args.action == "sign":
            sign(root)
        elif args.action == "signed-data":
            signed_data(root, args.run)
    except Exception as error:
        # Preserve a useful, redacted cause BEFORE failing. No lost stderr.
        message = redact(str(error)) if isinstance(error, (GateError, subprocess.CalledProcessError)) else type(error).__name__
        write(root / "CANDIDATE25_BLOCKER.json", {"status": "BLOCKED", "stage": args.action, "reason": message,
            "applicationSourceSHA": SOURCE, "mainSHA": os.environ["GITHUB_SHA"], "privateDataOrKeysInReport": False})
        print("CANDIDATE25_BLOCKED: " + message)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
