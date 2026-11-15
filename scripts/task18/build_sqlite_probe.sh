#!/usr/bin/env bash
set -euo pipefail
probe_root="$RUNNER_TEMP/task18-sqlite-probe"
mkdir -p "$probe_root/classes" "$probe_root/dex"
probe_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
probe_android="$(ls -d "$ANDROID_HOME"/platforms/android-* | sort -V | tail -1)/android.jar"
python3 scripts/task18/sqlite_probe/prepare_scheduler_candidate.py
javac -source 17 -target 17 -cp "$probe_android" -d "$probe_root/classes" \
  scripts/task18/sqlite_probe/NativePoolProbe.java \
  scripts/task18/sqlite_probe/TransactionScheduler.java \
  "$probe_root/DatabaseWorkerPool.java" "$probe_root/Database.java" "$probe_root/Nullable.java" \
  third_party/sqflite_android/android/src/main/java/com/tekartik/sqflite/DatabaseTask.java \
  third_party/sqflite_android/android/src/main/java/com/tekartik/sqflite/DatabaseWorker.java
# Stub Database/Nullable are compile-time resolution only; NEVER put them in DEX.
mapfile -t probe_classes < <(find "$probe_root/classes/com/tekartik/sqflite" -name '*.class' ! -name 'Database.class' | sort)
"$probe_tools/d8" --min-api 24 --lib "$probe_android" --output "$probe_root/dex" "$probe_root/classes/org/alchemist/p0probe/"*.class "${probe_classes[@]}"
(cd "$probe_root/dex" && zip "$probe_root/native-pool.jar" classes.dex)
