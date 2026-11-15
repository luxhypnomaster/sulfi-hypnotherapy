#!/usr/bin/env bash
set -euo pipefail
probe_root="$RUNNER_TEMP/task18-sqlite-probe"
mkdir -p "$probe_root/classes" "$probe_root/dex"
probe_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
probe_android="$(ls -d "$ANDROID_HOME"/platforms/android-* | sort -V | tail -1)/android.jar"
javac -source 17 -target 17 -cp "$probe_android" -d "$probe_root/classes" scripts/task18/sqlite_probe/NativePoolProbe.java
"$probe_tools/d8" --min-api 24 --lib "$probe_android" --output "$probe_root/dex" "$probe_root/classes/org/alchemist/p0probe/"*.class
(cd "$probe_root/dex" && zip "$probe_root/native-pool.jar" classes.dex)
