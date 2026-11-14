#!/usr/bin/env bash
set -euo pipefail
native_status=0
python3 scripts/task17/native_upgrade.py || native_status=$?
if [ "$native_status" -ne 0 ]; then
  echo TASK17_HOST_FAILURE_DIAGNOSTICS
  df -Pk "$RUNNER_TEMP"
  free -m
  ps -C qemu-system-x86_64 -o pid,rss,vsz,pcpu,stat || true
  timeout 10 adb get-state || true
  sudo dmesg | rg -i 'out of memory|oom-kill|killed process.*qemu' | tail -10 || true
fi
exit "$native_status"
