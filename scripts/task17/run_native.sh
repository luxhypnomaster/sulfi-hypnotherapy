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
  # Hosted runners do not guarantee ripgrep; never lose the kernel diagnostic
  # just because our preferred search tool is missing.
  if command -v rg >/dev/null 2>&1; then
    sudo dmesg | rg -i 'out of memory|oom-kill|killed process.*qemu' | tail -10 || true
  else
    sudo dmesg | grep -Ei 'out of memory|oom-kill|killed process.*qemu' | tail -10 || true
  fi
fi
exit "$native_status"
