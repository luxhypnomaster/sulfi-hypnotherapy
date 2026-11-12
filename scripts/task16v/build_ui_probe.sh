#!/usr/bin/env bash
set -euo pipefail
# This helper is installed ONLY on a disposable emulator. Its throwaway key is
# unrelated to Sulfi signing; no repository secrets or owner tokens are used.
probe_root="$RUNNER_TEMP/task16v-ui-probe"
mkdir -p "$probe_root/classes" "$probe_root/dex"
probe_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
probe_android="$(ls -d "$ANDROID_HOME"/platforms/android-* | sort -V | tail -1)/android.jar"
javac -source 17 -target 17 -cp "$probe_android" -d "$probe_root/classes" scripts/task16v/ui_probe/Probe.java
"$probe_tools/d8" --min-api 24 --lib "$probe_android" --output "$probe_root/dex" "$probe_root/classes/org/alchemist/p0probe/Probe.class"
"$probe_tools/aapt" package -f -M scripts/task16v/ui_probe/AndroidManifest.xml -I "$probe_android" -F "$probe_root/unsigned.apk"
zip -j "$probe_root/unsigned.apk" "$probe_root/dex/classes.dex"
"$probe_tools/zipalign" -f 4 "$probe_root/unsigned.apk" "$probe_root/aligned.apk"
keytool -genkeypair -keystore "$probe_root/disposable.jks" -storepass disposable-ui-only -keypass disposable-ui-only -alias p0-probe -keyalg RSA -keysize 2048 -validity 1 -dname 'CN=Disposable emulator UI QA' >/dev/null 2>&1
"$probe_tools/apksigner" sign --ks "$probe_root/disposable.jks" --ks-key-alias p0-probe --ks-pass pass:disposable-ui-only --out "$probe_root/probe.apk" "$probe_root/aligned.apk"
