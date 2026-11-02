# Instructions for coding agents

This repository is the **Сульфи — гипнотерапевт** Android-first Flutter application.

1. Read README.md, SPEC.md and BACKLOG.md at the start of a task.
2. The product owner is nontechnical. Communicate in Russian; describe each milestone in plain language and include screenshots, test output, and remaining blockers where possible.
3. Prefer working vertical slices to speculative architecture. Implement real, functioning screens and persist data. Avoid empty placeholder buttons, mock "success" messages, and demos presented as finished features.
4. Maintain project hygiene: standard Flutter structure, dependency pinning, small testable services, lints, unit/widget tests, and a brief manual Android test plan. Run `flutter pub get`, `flutter analyze`, `flutter test`, and an Android build if SDK is present; report what actually ran.
5. Keep v0.1 fully offline and local. No API keys, GPT, Supabase, Firebase, analytics, login, or network requests without explicit approval.
6. Never commit actual private audio, recordings, session data, credentials or `.env` files. Add Git ignores and safe sample/test placeholders.
7. The pre-existing Sulfi voice is created in Suno outside this repository. Import files using the system picker; never attempt to recreate the voice or substitute synthetic speech.
8. Keep modular types for AUDIO, SILENCE, RECORD_MIC. Support session-level topic audio separately, and optional user insert of that audio into the playback sequence.
9. Critical: clear microphone permission and recording indication; local delete; stop recording on exit; button "Finish and exit" available during session; interruptions handled without claiming guaranteed recovery.
10. Deliver small, reviewed changes/PRs. Do not merge destructive changes or publish releases without owner approval.
11. Track work in BACKLOG.md; keep README.md up to date with Android setup and verified build/run commands.
12. If a tool/SDK is unavailable, implement what is feasible, state limitation, and give exact reproducible next steps instead of inventing test results.
13. Read VERSIONING.md before modifying branches, tags, release workflows or Android version numbers. Always preserve `main` as stable and use PRs for changes. Do not rewrite published Git history.
14. Require owner approval before merging into `main` or publishing releases. For rollback, prefer a corrective new release with incremented Android versionCode; do not assume old APK can overwrite a newer version while preserving data.
15. Preserve on-device library and recording data across upgrades. Git revisions and APK archives are not backups of personal recordings.
