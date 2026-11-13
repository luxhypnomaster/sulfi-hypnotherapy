#!/usr/bin/env bash
set -euo pipefail
test "$(adb shell getprop ro.kernel.qemu | tr -d '\r')" = 1
adb install "$RUNNER_TEMP/task16g-storage-probe/probe.apk"
adb shell am instrument -w org.alchemist.storageprobe/.GuardProbe > "$RUNNER_TEMP/storage16g.txt"
cat "$RUNNER_TEMP/storage16g.txt"
grep -q 'INSTRUMENTATION_CODE: -1' "$RUNNER_TEMP/storage16g.txt"
grep -q '"originalBytesUnchanged":true' "$RUNNER_TEMP/storage16g.txt"
! grep -q STORAGE_16G_FAILURE "$RUNNER_TEMP/storage16g.txt"
