#!/usr/bin/env bash
set -uo pipefail
free -h
python3 scripts/task16v/native_upgrade.py
qa_status=$?
free -h
sudo dmesg --ctime | rg -i 'out of memory|oom-kill|killed process|qemu|segfault' | tail -25 || true
exit "$qa_status"
