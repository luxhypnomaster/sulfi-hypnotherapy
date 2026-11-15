#!/usr/bin/env bash
set -euo pipefail
marker_root="$RUNNER_TEMP/task18-queue-marker"
marker_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
marker_api="$(ls -d "$ANDROID_HOME"/platforms/android-* | sort -V | tail -1)/android.jar"
mkdir -p "$marker_root/classes" "$marker_root/dex"
javac -source 17 -target 17 -cp "$marker_api" -d "$marker_root/classes" scripts/task18/queue_probe/LegacyQueueMarker.java
"$marker_tools/d8" --min-api 24 --lib "$marker_api" --output "$marker_root/dex" "$marker_root/classes/org/alchemist/p0probe/LegacyQueueMarker.class"
jar cf "$marker_root/marker.jar" -C "$marker_root/dex" classes.dex
