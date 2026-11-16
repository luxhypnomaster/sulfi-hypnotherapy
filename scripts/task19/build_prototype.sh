#!/usr/bin/env bash
set -euo pipefail
test -z "${SULFI_SIGNING_STORE_FILE:-}"
auth_root="$RUNNER_TEMP/task19-prototypes"
mkdir -p "$auth_root"
for auth_edition in master client; do
  auth_defines=(--dart-define=SULFI_AUTH19_STAGING=true)
  auth_gradle="$(printf '%s' SULFI_AUTH19_STAGING=true | base64 -w0)"
  if [ "$auth_edition" = client ]; then
    auth_defines+=(--dart-define=SULFI_EDITION=client)
    auth_gradle="$auth_gradle,$(printf '%s' SULFI_EDITION=client | base64 -w0)"
  fi
  flutter build apk --debug --target lib/main_auth19.dart "${auth_defines[@]}"
  cp build/app/outputs/flutter-apk/app-debug.apk "$auth_root/$auth_edition.auth19.apk"
  (
    cd android
    ./gradlew :app:testDebugUnitTest :app:assembleDebugAndroidTest \
      -Ptarget=lib/main_auth19.dart "-Pdart-defines=$auth_gradle" --no-daemon --console=plain
  )
  cp build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk "$auth_root/$auth_edition.androidTest.apk"
  python3 scripts/task19/record_build.py "$auth_edition"
done
