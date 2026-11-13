#!/usr/bin/env bash
set -euo pipefail
# This is ONLY the disposable hosted build job, never the shared/user workspace.
test "${GITHUB_ACTIONS:-}" = true
test "${RUNNER_OS:-}" = Linux
test -s "$RUNNER_TEMP/task16g-apks/master26.apk"
test -s "$RUNNER_TEMP/task16g-apks/client26.apk"
test -s "$RUNNER_TEMP/task16g-apks/APK_PAIR_16G.json"
echo "DISK16G_BEFORE=$(df -Pk "$RUNNER_TEMP" | awk 'NR==2 {print $4*1024}')"
# All outputs/keys/baseline APKs under RUNNER_TEMP stay intact. No remote Actions
# artifacts/caches, release assets, source files or user material are removed.
rm -rf "$GITHUB_WORKSPACE/build" "$HOME/.gradle/caches" "$ANDROID_HOME/ndk/28.2.13676358"
rm -rf "$GITHUB_WORKSPACE/.tooling/flutter/bin/cache"
df -Pk "$RUNNER_TEMP"
python3 - <<'PY'
import shutil, os
free=shutil.disk_usage(os.environ['RUNNER_TEMP']).free
print('DISK16G_AFTER='+str(free))
assert free >= 8 * 1024**3, 'INSUFFICIENT_EMULATOR_SPACE; do not repeat emulator blindly'
PY
