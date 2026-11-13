#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "${RUNNER_OS:-}" = Linux
# Fresh hosted QA job only. No Flutter/Gradle/NDK build, no owner data.
# Existing repository source, cached APKs, signing material and remote artifacts
# are not targeted. These are unneeded stock hosted-runner tool installations.
df -Pk "$RUNNER_TEMP"
sudo rm -rf /usr/share/dotnet /opt/ghc /usr/local/.ghcup /opt/hostedtoolcache/CodeQL "$ANDROID_HOME/ndk"
df -Pk "$RUNNER_TEMP"
