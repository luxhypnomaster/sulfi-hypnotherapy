#!/usr/bin/env bash
set -euo pipefail
# This helper is installed ONLY on a disposable emulator. Its throwaway key is
# unrelated to Sulfi signing; no repository secrets or owner tokens are used.
probe_root="$RUNNER_TEMP/task16v-ui-probe"
mkdir -p "$probe_root/classes" "$probe_root/dex"
probe_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
probe_android="$(ls -d "$ANDROID_HOME"/platforms/android-* | sort -V | tail -1)/android.jar"
javac -source 17 -target 17 -cp "$probe_android" -d "$probe_root/classes" scripts/task16v/ui_probe/*.java
mapfile -t probe_classes < <(find "$probe_root/classes" -name '*.class')
"$probe_tools/d8" --min-api 24 --lib "$probe_android" --output "$probe_root/dex" "${probe_classes[@]}"
keytool -genkeypair -keystore "$probe_root/disposable.jks" -storepass disposable-ui-only -keypass disposable-ui-only -alias p0-probe -keyalg RSA -keysize 2048 -validity 1 -dname 'CN=Disposable emulator UI QA' >/dev/null 2>&1
for probe_kind in probe ime; do
  probe_manifest=scripts/task16v/ui_probe/AndroidManifest.xml
  if [ "$probe_kind" = ime ]; then probe_manifest=scripts/task16v/ui_probe/ime_manifest.xml; fi
  "$probe_tools/aapt" package -f -M "$probe_manifest" -I "$probe_android" -S scripts/task16v/ui_probe/res -F "$probe_root/$probe_kind-unsigned.apk"
  zip -j "$probe_root/$probe_kind-unsigned.apk" "$probe_root/dex/classes.dex"
  "$probe_tools/zipalign" -f 4 "$probe_root/$probe_kind-unsigned.apk" "$probe_root/$probe_kind-aligned.apk"
  "$probe_tools/apksigner" sign --ks "$probe_root/disposable.jks" --ks-key-alias p0-probe --ks-pass pass:disposable-ui-only --out "$probe_root/$probe_kind.apk" "$probe_root/$probe_kind-aligned.apk"
done
