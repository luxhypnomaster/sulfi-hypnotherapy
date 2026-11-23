#!/usr/bin/env python3
"""APK28->29 on a disposable hosted emulator. No owner device or fake Google.

Reuses the pinned, previously exercised UI routines. Built-in uiautomator avoids
generating a new instrumentation signing key. Supplemental native SQLite rows
are explicitly identified; tracks/modules/program/history/MASTER draft use UI.
"""
import argparse
import base64
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import time
import wave
import math
import struct
import io
import zipfile
import xml.etree.ElementTree as ET

from candidate25 import CODE, SOURCE, IDS, GateError, guard, command, tools, digest, write, redact


def accessibility_snapshot(adb, out, actions, run=None):
    """Observe a fresh tree across bounded UI transitions; never retry a tap.

    A playback position event can interrupt platform uiautomator's idle wait.
    A dead emulator is a separate failure and is never restarted here.
    """
    run = run or subprocess.run
    diagnostics = []
    for attempt in range(1, 4):
        adb("shell", "rm", "-f", "/sdcard/qa25-window.xml")
        try:
            p = run(["adb", "shell", "uiautomator", "dump", "/sdcard/qa25-window.xml"],
                    capture_output=True, text=True, timeout=55)
            detail = {"attempt": attempt, "returncode": p.returncode,
                      "stdout": redact(p.stdout[-500:]), "stderr": redact(p.stderr[-500:])}
            xml = adb("exec-out", "cat", "/sdcard/qa25-window.xml", check=False)
            nodes = list(ET.fromstring(xml).iter("node")) if "<hierarchy" in xml else []
            if p.returncode == 0 and nodes:
                (out / "latest-window.xml").write_text(xml)
                if diagnostics:
                    actions.append({"action": "read_only_accessibility_transition_recovered",
                                    "attempts": attempt, "failures": diagnostics,
                                    "repeatedUIActions": False})
                return nodes
        except (subprocess.TimeoutExpired, ET.ParseError) as error:
            detail = {"attempt": attempt, "error": type(error).__name__}
        diagnostics.append(detail)
        write(out / "AX_LAST_TRANSITION_25.json", {"readOnly": True, "attempts": diagnostics})
        if adb("get-state", check=False).strip() != "device":
            raise GateError("EMULATOR_CONNECTION_LOST_NO_RETRY")
        if attempt < 3:
            time.sleep(0.5 * attempt)
    raise GateError("NATIVE_ACCESSIBILITY_DUMP_UNAVAILABLE_AFTER_3_FRESH_READS:" + json.dumps(diagnostics))


def open_public_cache(ui):
    ui.home()
    ui.click("Дневник")
    if any(ui.label(node) == "Читатель" for node in ui.tree()):
        ui.click("Читатель", exact=True)  # Existing MASTER reader mode; no role change.
    ui.click("QA25 cached public diary")
    assert any("CONTROLLED_NATIVE25_PUBLIC_CACHE_NOT_GOOGLE" in ui.label(node)
               or "Controlled offline text" in ui.label(node) for node in ui.tree()), "OFFLINE_READER_NOT_RENDERED"
    ui.shot("offline-public-reader")
    return {"cachePreservedAndReadableOffline": True, "Google": "NOT_RUN", "source": "supplemental synthetic public cache"}


def open_master_editor(ui, original_editor):
    """Leave the existing reader and select existing author mode before typing.

    Navigation observation only; no app Back changes, role changes or SQL writes.
    The original editor readiness and exact persisted-field assertions still run.
    """
    labels = [ui.label(node) for node in ui.tree()]
    if "К списку записей" in labels:
        ui.click("К списку записей", exact=True)
        labels = [ui.label(node) for node in ui.tree()]
    author_view = next((label for label in ("Автор", "Мои записи") if label in labels), None)
    if "Новая запись" not in labels and author_view is not None:
        ui.click(author_view, exact=True)
    return original_editor()


def configure_display(path):
    """Disposable AVD framebuffer; logical UI remains the tested720x1280/280."""
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        raise GateError("EXISTING_DISPOSABLE_AVD_CONFIG_REQUIRED")
    config = dict(line.split("=", 1) for line in path.read_text().splitlines() if "=" in line)
    if config.get("disk.dataPartition.size", "").strip() not in {"3G", "3072M", "3221225472"}:
        raise GateError("DISPOSABLE_AVD_PARTITION_NOT_PINNED")
    before = {k: config.get(k) for k in ["hw.lcd.width", "hw.lcd.height", "hw.lcd.density"]}
    config.update({"hw.lcd.width": "720", "hw.lcd.height": "1280", "hw.lcd.density": "280",
                   "skin.name": "720x1280", "skin.path": "_no_skin"})
    path.write_text("\n".join(k + "=" + v for k, v in config.items()) + "\n")
    return {"status": "PASS_DISPOSABLE_PHYSICAL_FRAMEBUFFER_CONFIGURED", "before": before,
            "after": {k: config[k] for k in before}, "applicationOrDatabaseChanged": False}


def prepare_profile(root):
    source = Path(os.environ["GITHUB_WORKSPACE"]) / "appsource"
    if command(["git", "rev-parse", "HEAD"], cwd=source).strip() != SOURCE:
        raise GateError("PINNED_PRE_EMULATOR_SOURCE_REQUIRED")
    command(["python3", str(source / "scripts/task17/pre_emulator.py")], live=True)
    receipt = configure_display(Path.home() / ".android/avd/test.avd/config.ini")
    write(root / "task25-native-evidence/SDK_PROFILE_25.json", receipt)
    print("TASK25_PHYSICAL720x1280_DENSITY280_WITH_EXISTING_PINNED_EMULATOR_AND_EXIT_MONITOR")

FIXTURE_JAVA = r'''
package org.alchemist.qa25;
import android.database.sqlite.SQLiteDatabase;
import android.content.ContentValues;
import android.os.Build;
import android.os.Process;
import android.system.Os;
import java.io.File;
import java.nio.file.Files;
import org.json.*;
public final class Fixture {
 public static void main(String[] args) throws Exception {
  if(args.length!=2)throw new IllegalStateException("EXPLICIT_PACKAGE_INPUT_REQUIRED");
  String pkg=args[0];
  if(!pkg.equals("ru.sulfi.sulfi_hypnotherapy")&&!pkg.equals("ru.sulfi.sulfi_hypnotherapy.clienttest"))throw new IllegalStateException("WRONG_PACKAGE");
  if(!Build.HARDWARE.equals("ranchu")&&!Build.HARDWARE.equals("goldfish"))throw new IllegalStateException("EMULATOR_ONLY");
  File root=new File("/data/user/0/"+pkg+"/files"),dbfile=new File(root,"library.sqlite"),input=new File(args[1]);
  if(!dbfile.isFile()||Os.stat(dbfile.getPath()).st_uid!=Process.myUid()||Process.myUid()<10000||!input.getCanonicalFile().getParentFile().equals(root.getCanonicalFile()))throw new IllegalStateException("APP_OWNED_EXISTING_DB_ONLY");
  JSONObject fixture=new JSONObject(new String(Files.readAllBytes(input.toPath()),"UTF-8"));
  if(!fixture.getString("classification").equals("CONTROLLED_NATIVE25_SUPPLEMENT_NOT_GOOGLE"))throw new IllegalStateException("CONTROLLED_INPUT_ONLY");
  JSONArray rows=fixture.getJSONArray("records");
  if(rows.length()<6||rows.length()>7)throw new IllegalStateException("BOUNDED_FIXTURE_ONLY");
  SQLiteDatabase db=SQLiteDatabase.openDatabase(dbfile.getPath(),null,SQLiteDatabase.OPEN_READWRITE,x->{throw new IllegalStateException("NO_RESET");});
  try {
   if(db.getVersion()!=9)throw new IllegalStateException("SCHEMA9_REQUIRED");
   db.beginTransaction();
   try {
    for(int i=0;i<rows.length();i++){
     JSONObject record=rows.getJSONObject(i),row=record.getJSONObject("row");String table=record.getString("table");
     if(table.equals("app_settings")){
      String key=row.getString("name");
      boolean policy=key.equals("transfer_network_policy18")&&row.getString("value").equals("unmetered");
      if(!policy&&(!key.matches("alchemist_(card|upload):controlled_native25_[a-z]+")||!row.getString("value").contains("CONTROLLED_NATIVE25")))throw new IllegalStateException("NO_UNRELATED_SETTINGS");
      if(row.length()!=2)throw new IllegalStateException("EXACT_SETTINGS_COLUMNS");
     }else if(table.equals("diary_public")){
      if(!row.getString("id").equals("controlled-native25-public")||!row.getString("payload").contains("CONTROLLED_NATIVE25")||row.length()!=4)throw new IllegalStateException("NO_UNRELATED_PUBLIC_CACHE");
     }else throw new IllegalStateException("NO_OTHER_TABLES");
     ContentValues values=new ContentValues();java.util.Iterator<String> keys=row.keys();
     while(keys.hasNext()){String key=keys.next();Object value=row.get(key);if(value instanceof Number)values.put(key,((Number)value).longValue());else values.put(key,String.valueOf(value));}
     db.insertOrThrow(table,null,values); // Never replace existing rows or schema.
    }
    db.setTransactionSuccessful();
   }finally{db.endTransaction();}
   System.out.println("CONTROLLED_NATIVE25_INSERT_ONLY_OK");
  }finally{db.close();}
 }
}
'''


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--edition", choices=IDS)
    p.add_argument("--api", type=int, choices=[34, 35, 36])
    p.add_argument("--prepare-profile", action="store_true")
    args = p.parse_args()
    root = guard()
    if args.prepare_profile:
        prepare_profile(root)
        return 0
    if args.edition is None or args.api is None:
        p.error("--edition and --api required for native QA")
    source = Path(os.environ["GITHUB_WORKSPACE"]) / "appsource"
    if command(["git", "rev-parse", "HEAD"], cwd=source).strip() != SOURCE:
        raise GateError("PINNED_UI_ROUTINES_REQUIRED")
    devices = command(["adb", "devices"])
    serials = re.findall(r"^(emulator-\d+)\s+device$", devices, re.MULTILINE)
    if len(serials) != 1:
        raise GateError("ONE_DISPOSABLE_EMULATOR_REQUIRED")
    os.environ["ANDROID_SERIAL"] = serials[0]
    if command(["adb", "shell", "getprop", "ro.kernel.qemu"]).strip() != "1" or int(command(["adb", "shell", "getprop", "ro.build.version.sdk"]).strip()) != args.api:
        raise GateError("DISPOSABLE_API_MATRIX_MISMATCH")
    ready = Path(os.environ["GITHUB_WORKSPACE"]) / ".task17-sdk-ready.json"
    if not ready.exists() or json.loads(ready.read_text())["version"] != "37.2.12":
        raise GateError("PINNED_EMULATOR_PREHOOK_NOT_CONFIRMED")
    profile = root / "task25-native-evidence/SDK_PROFILE_25.json"
    if not profile.exists() or json.loads(profile.read_text())["status"] != "PASS_DISPOSABLE_PHYSICAL_FRAMEBUFFER_CONFIGURED":
        raise GateError("PHYSICAL_FRAMEBUFFER_PREHOOK_NOT_CONFIRMED")
    physical = command(["adb", "shell", "wm", "size"]).strip()
    if "Physical size: 720x1280" not in physical:
        raise GateError("PHYSICAL_FRAMEBUFFER_SIZE_NOT_APPLIED:" + physical)
    os.environ["TASK18_BASELINE"] = "27"  # Import functions only, never run legacy main.
    spec = importlib.util.spec_from_file_location("reviewed_ui18", source / "scripts/task18/native_upgrade.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    m.BASE, m.EDITION, m.PKG, m.IME = 28, args.edition, IDS[args.edition], False
    m.ELMAN_TITLE = "QA25 Elman three tracks"
    out = root / "task25-native-evidence"
    out.mkdir(exist_ok=True)
    m.OUT = out
    m.APK = root / "task25-native-apks"
    m.APK.mkdir()
    import shutil
    shutil.copyfile(root / "task25-baseline" / f"{args.edition}28.apk", m.APK / f"{args.edition}28.apk")
    shutil.copyfile(root / "task25-signed-quarantine" / f"{args.edition}29.apk", m.APK / f"{args.edition}29.apk")

    def report():
        write(out / "NATIVE_UPGRADE_25.json", {
            "edition": args.edition, "api": args.api, "baseline": 28, "candidate": CODE,
            "applicationSourceSHA": SOURCE, "driverMainSHA": os.environ["GITHUB_SHA"],
            "fixture": "tracks/modules/program/history/MASTER-local-draft/capsule via APK28 UI; queue/public-cache/network-policy supplemental Android SQLite, explicitly NOT Google",
            "ownerPhone": "NOT_TOUCHED", "realGoogle": "NOT_RUN", "uninstallClearDowngrade": False,
            "newKeysGenerated": False, "cases": m.CASES, "actions": m.ACTIONS, "inventories": m.inventories,
        })
    m.report = report

    def tree():
        return accessibility_snapshot(m.adb, out, m.ACTIONS)
    m.tree = tree
    if args.edition == "master":
        original_editor = m.open_diary_editor
        m.open_diary_editor = lambda: open_master_editor(m, original_editor)

    def install():
        if m.adb("shell", "pm", "path", m.PKG, check=False).strip():
            raise AssertionError("FRESH_EMULATOR_ONLY_NO_EXISTING_APP")
        assert "Success" in m.adb("install", "-r", str(m.APK / f"{args.edition}28.apk"))
        m.adb("shell", "wm", "size", "720x1280")
        m.adb("shell", "wm", "density", "280")
        m.adb("shell", "cmd", "connectivity", "airplane-mode", "enable", check=False)
        m.adb("shell", "svc", "wifi", "disable", check=False)
        m.adb("shell", "svc", "data", "disable", check=False)
        m.launch()
        assert m.package_info()["versionCode"] == 28
        return {"baseline": 28, "newKey": False, "helperAPK": False, "uninstall": False}

    original_inventory = m.inventory
    def inventory(name):
        value = original_inventory(name)
        b = m.adb("exec-out", "cat", "/sdcard/Download/task25-ui-before28.zip", binary=True, check=False)
        if b.startswith(b"PK"):
            value["files"]["external/Download/task25-ui-before28.zip"] = {"bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
        report()
        return value
    m.inventory = inventory

    def supplement():
        m.home()
        v = inventory("before-supplement")
        assert v["package"]["versionCode"] == 28 and len(v["rows"]["audio_assets"]) == 3
        records = []
        owner = "CONTROLLED_NATIVE25_NOT_GOOGLE"
        for i, phase in enumerate(["running", "queued", "paused", "unbound"]):
            who = None if phase == "unbound" else owner
            value = {"ownerBinding": who, "card": {"title": "CONTROLLED_NATIVE25_" + phase},
                "pending": {"operation": "catalog.publish", "parameters": {"requestId": "CONTROLLED_NATIVE25_" + phase, "ifMatch": "7"}},
                "_work": {"ownerBinding": who, "taskId": chr(97 + i) * 32, "revision": "a" * 64,
                          "phase": phase if phase != "unbound" else "queued", "attempts": 2,
                          "runnerEpoch": "CONTROLLED_NATIVE25", "networkRetries": 1,
                          "bytes": 262144, "totalBytes": 15728640}}
            value["_work"]["revision"] = hashlib.sha256(json.dumps({"card": value["card"]}, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
            if phase == "paused": value["_work"].update(code="USER_PAUSED", pauseReason="USER_PAUSED")
            records.append({"table": "app_settings", "row": {"name": "alchemist_card:controlled_native25_" + phase, "value": json.dumps(value, separators=(",", ":"))}})
        records.append({"table": "app_settings", "row": {"name": "alchemist_upload:controlled_native25_upload", "value": json.dumps({"ownerBinding": owner, "sessionId": "CONTROLLED_NATIVE25_session", "requestId": "CONTROLLED_NATIVE25_request", "offset": 262144, "receipt": None})}})
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        entry = {"id": "controlled-native25-public", "title": "QA25 cached public diary", "message": "CONTROLLED_NATIVE25_PUBLIC_CACHE_NOT_GOOGLE",
                 "body": "Controlled offline text", "createdAt": now, "updatedAt": now, "publishedAt": now, "status": "published", "version": 1,
                 "schemaVersion": 2, "order": 0, "_alchemistScope": "public"}
        records.append({"table": "diary_public", "row": {"id": entry["id"], "version": 1, "publishedAt": now, "payload": json.dumps(entry)}})
        if not any(r["name"] == "transfer_network_policy18" for r in v["rows"]["app_settings"]):
            records.append({"table": "app_settings", "row": {"name": "transfer_network_policy18", "value": "unmetered"}})
        d = root / "task25-fixture-native"
        (d / "classes").mkdir(parents=True)
        (d / "dex").mkdir()
        java = d / "Fixture.java"
        java.write_text(FIXTURE_JAVA)
        android = Path(os.environ["ANDROID_HOME"]) / "platforms/android-36/android.jar"
        command(["javac", "-source", "17", "-target", "17", "-cp", str(android), "-d", str(d / "classes"), str(java)])
        command([str(tools() / "d8"), "--min-api", "24", "--lib", str(android), "--output", str(d / "dex"), str(d / "classes/org/alchemist/qa25/Fixture.class")])
        command(["jar", "cf", str(d / "fixture.jar"), "-C", str(d / "dex"), "classes.dex"])
        m.adb("shell", "am", "force-stop", m.PKG)
        def put(name, data):
            result = subprocess.run(["adb", "shell", "-T", "run-as", m.PKG, "tee", "files/" + name], input=data, capture_output=True, timeout=30)
            assert result.returncode == 0 and result.stdout == data, "CONTROLLED_NATIVE_COPY_FAILED"
        put("qa25-fixture.jar", (d / "fixture.jar").read_bytes())
        put("qa25-fixture.json", json.dumps({"classification": "CONTROLLED_NATIVE25_SUPPLEMENT_NOT_GOOGLE", "records": records}).encode())
        m.adb("shell", "run-as", m.PKG, "chmod", "400", "files/qa25-fixture.jar")
        base = "/data/user/0/" + m.PKG + "/files/"
        result = m.adb("shell", "run-as", m.PKG, "env", "CLASSPATH=" + base + "qa25-fixture.jar", "app_process", "/system/bin", "org.alchemist.qa25.Fixture", m.PKG, base + "qa25-fixture.json")
        assert "CONTROLLED_NATIVE25_INSERT_ONLY_OK" in result
        m.launch()
        after = inventory("supplement-confirmed")
        for record in records:
            assert record["row"] in after["rows"][record["table"]], "NATIVE_FIXTURE_READBACK_FAILED"
        return {"source": "supplemental native Android SQLite, not UI/Google/server", "rows": len(records), "originalDatabaseReplaced": False}

    def capsule():
        m.home(); m.click("Библиотека"); m.click("О приложении и данных"); m.click("Резервная копия и обновления"); m.click("Создать резервную копию")
        time.sleep(2); m.text("task25-ui-before28.zip"); m.click("SAVE", exact=True); time.sleep(2)
        value = inventory("after-ui-capsule")
        assert "external/Download/task25-ui-before28.zip" in value["files"]
        raw = m.adb("exec-out", "cat", "/sdcard/Download/task25-ui-before28.zip", binary=True)
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            assert z.testzip() is None and z.namelist(), "UI_CAPSULE_CRC_OR_CONTENTS_FAILED"
        return {"createdBy": "APK28_UI_SAF_EXPORT", "sha256": value["files"]["external/Download/task25-ui-before28.zip"]["sha256"]}

    def before():
        m.home()
        v = inventory("beforeBaseline")
        assert v["database"]["integrity"] == "ok" and v["package"]["versionCode"] == 28
        for table, minimum in [("audio_assets", 3), ("module_definitions", 2), ("session_templates", 1), ("current_draft", 1), ("session_runs", 1), ("diary_public", 1)]:
            assert len(v["rows"][table]) >= minimum, "NONEMPTY_BASELINE_REQUIRED:" + table
        if args.edition == "master": assert v["rows"]["diary_author"], "UI_MASTER_DRAFT_REQUIRED"
        assert len({a["contentHash"] for a in v["rows"]["audio_assets"]}) == 3
        assert "external/Download/task25-ui-before28.zip" in v["files"]
        assert any(r["name"] == "transfer_network_policy18" for r in v["rows"]["app_settings"])
        return {"UIAudio": 3, "modules": 2, "programs": len(v["rows"]["session_templates"]), "history": len(v["rows"]["session_runs"]), "nativeDiaryCache": True}

    def compare(name):
        v = inventory(name); old = m.inventories["beforeBaseline"]
        assert v["package"]["versionCode"] == CODE and v["database"] == old["database"]
        for table in ["audio_assets", "module_definitions", "session_templates", "current_draft", "session_runs", "run_events", "diary_author", "diary_public", "app_settings"]:
            for row in old["rows"][table]:
                assert row in v["rows"][table], "PRESERVATION_FAILURE:" + table + ":" + str(row.get("id", row.get("name")))
        for path, value in old["files"].items():
            if path.startswith(("files/audio/", "files/diary_media/", "files/history_media/", "external/")):
                assert v["files"].get(path) == value, "MEDIA_BYTES_CHANGED:" + path
        return {"exactRowsAndMedia": True, "settingsQueueDiary": True, "SQLiteIntegrity": "ok", "versionCode": CODE}

    def upgrade():
        assert any(c["case"] == "beforeBaseline" and c["status"] == "PASS" for c in m.CASES)
        assert "Success" in m.adb("install", "-r", str(m.APK / f"{args.edition}29.apk"))
        m.launch(); m.shot("after-normal-update")
        return compare("afterCandidate")

    def reader():
        return open_public_cache(m)

    def case(name, fn):
        m.case(name, fn)
        if m.CASES[-1]["status"] != "PASS":
            raise GateError("NATIVE_CASE_BLOCKED_" + name)

    try:
        case("install_actual28", install)
        m.adb("shell", "mkdir", "-p", "/sdcard/Download")
        for i in range(1, 4):
            f = out / f"tone{i}.wav"
            with wave.open(str(f), "wb") as w:
                w.setparams((1, 2, 22050, 0, "NONE", "not compressed"))
                w.writeframes(b"".join(struct.pack("<h", int(1800 * math.sin(j * 2 * math.pi * (220 + i * 20) / 22050))) for j in range(22050 * 12)))
            dest = f"/sdcard/Download/task16v-{i}.wav"
            m.adb("push", str(f), dest)
            m.adb("shell", "am", "broadcast", "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE", "-d", "file://" + dest, check=False)
        time.sleep(2)
        for i in range(1, 4): case(f"ui_audio_{i}", lambda i=i: m.import_audio(f"task16v-{i}.wav", "UI same title" if i < 3 else "UI third track"))
        case("ui_module_three_tracks", lambda: m.module(m.ELMAN_TITLE, ["UI same title", "UI same title", "UI third track"]))
        case("ui_module_pause", lambda: m.module("UI timed module", ["UI third track"], True))
        case("ui_program", m.create_template)
        case("ui_history", m.create_history)
        if args.edition == "master": case("ui_master_local_diary28", m.local_draft_after)
        case("native_queue_cache_settings_supplement", supplement)
        case("ui_capsule_export", capsule)
        case("beforeBaseline", before)
        case("normal_install_r_28_to29", upgrade)
        case("UI_after29_and_native_audio", m.ui_after)
        case("cold_restart29", lambda: (m.restart(), compare("coldCandidate"))[-1])
        case("offline_diary_reader29", reader)
        if args.edition == "master": case("ui_master_local_diary29", m.local_draft_after)
    finally:
        report()
    print("NATIVE25_ALL_CASES_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
