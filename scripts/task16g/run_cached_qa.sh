#!/usr/bin/env bash
# Disposable emulator only. Independent fault QA must not be lost to a UI selector failure.
set -euo pipefail
native_status=0
python3 scripts/task16g/native_upgrade.py || native_status=$?
if [ "$native_status" -eq 0 ]; then
  TASK16G_REUSE_UI_BASELINE=1 python3 scripts/task16g/app_fault.py
else
  # Preserve the primary failure receipt. This is NOT accepted healthy upgrade.
  # Only a disposable Android UI dataset is used; never SQL-seeded or owner data.
  test "$(adb shell getprop ro.kernel.qemu | tr -d '\r')" = 1
  adb install -r "$RUNNER_TEMP/task16g-apks/master26.apk"
  TASK16G_REUSE_PARTIAL_UI_BASELINE=1 python3 scripts/task16g/app_fault.py
fi
# A successful independent negative test must never hide positive-gate failure.
exit "$native_status"
