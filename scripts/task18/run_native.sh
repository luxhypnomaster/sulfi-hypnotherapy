#!/usr/bin/env bash
set -euo pipefail
if [ "${TASK17_EMULATOR_PIN:-}" = "37.2.12" ]; then
  python3 - <<'PYREADY'
import pathlib,os,json
p=pathlib.Path(os.environ['GITHUB_WORKSPACE'])/'.task17-sdk-ready.json'
assert p.exists(),'SDK_PREFLIGHT_FAILED_NO_BASELINE_INSTALL'
v=json.loads(p.read_text());assert v['version']=='37.2.12' and v['validatedHeadlessVersion'] is True
print('SDK_PREFLIGHT_BARRIER_PASS')
PYREADY
fi
native_status=0
python3 scripts/task18/native_upgrade.py || native_status=$?
if [ "$native_status" -ne 0 ]; then
  python3 scripts/task18/emulator_crash_metadata.py || true
  echo TASK18_HOST_FAILURE_DIAGNOSTICS
  df -Pk "$RUNNER_TEMP"
  free -m
  ps -C qemu-system-x86_64 -o pid,rss,vsz,pcpu,stat || true
  timeout 10 adb get-state || true
  timeout 10 adb logcat -d -b crash -t 80 || true
  find /tmp/android-runner -maxdepth 2 -type f -name "*.dmp" -printf "EMULATOR_CRASH_DUMP=%f %s bytes\n" 2>/dev/null || true
  # Hosted runners do not guarantee ripgrep; never lose the kernel diagnostic
  # just because our preferred search tool is missing.
  if command -v rg >/dev/null 2>&1; then
    sudo dmesg | rg -i 'out of memory|oom-kill|killed process.*qemu|segfault|general protection|trap.*qemu' | tail -10 || true
  else
    sudo dmesg | grep -Ei 'out of memory|oom-kill|killed process.*qemu|segfault|general protection|trap.*qemu' | tail -10 || true
  fi
fi
exit "$native_status"
