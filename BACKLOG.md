# Build plan

## Milestone 0 — bootstrap
- [x] Initialize Flutter application and Android target; configure Russian locale and theme.
- [x] Choose and check current compatible packages; establish SQLite v1 and private app-controlled audio storage. Flutter 3.47.9 / Dart 3.13.7; dependencies pinned with lockfile.
- [x] Add lint/tests/CI (GitHub Actions on PR/push develop). `flutter analyze` and 28 tests pass locally; see docs/VERIFICATION.md for Android build/CI results.

## Milestone 1 — working audio library
- [x] Implement MP3/M4A/WAV import through Android system picker with private copy and decoder validation; device acceptance pending below.
- [x] Implement duration/category/format/size display, foreground preview, rename, category edit, confirmed delete and local reset.
- [x] Automated tests: rejected/canceled/empty/missing/decoder-failed import, persistence, deletion, reset and UI flows. Picker/decoder/player are injected in tests.
- [ ] Complete real-Android acceptance for native picker, three actual formats, decoder corruption/missing-file errors, audio focus and phone storage behavior (docs/ANDROID_TEST_PLAN.md).
- [x] Prevent deleting audio referenced by current draft, templates or an active run; show dependencies. History snapshots keep their metadata independently.

## Milestone 2 — session constructor
- [x] Persist distinct AUDIO / SILENCE / FREE_WORK / RECORD_MIC models. AUDIO/SILENCE/FREE_WORK are editable/executable; mic execution is a separate pending stage.
- [x] Reorder/duplicate/remove/replace; edit delays and timed work; validate timeline. Recording controls remain disabled.
- [x] Save/load/version/copy/rename/delete templates; maintain an independent autosaved draft and duration estimates.

## Milestone 3 — player engine
- [x] Foreground sequential execution, per-block pre-delay and serialized transitions. Logical tests prevent duplicate/skipped transitions; audible gap measurements remain for device acceptance.
- [ ] Background playback, lock-screen handling, pause/resume/next.
- [x] Foreground Finish and exit, explicit exit-track choice, safe text fallback and truthful early-finish status.

## Milestone 4 — session records
- [ ] Pre-session topic recording with permission, consent and playback/delete.
- [ ] Microphone recording blocks, clear recording indicator, playback/delete.
- [x] Local immutable execution snapshots, actual events/checkpoints, interruption on background/process death, rename/notes/repeat/create template. Voice-recording links still pending.

## Milestone 5 — Android testing and package
- [ ] Real-device manual validation with screen locked, earbuds, interruptions and denied permissions.
- [ ] Fix issues; build signed or debug APK as appropriate and explain installation.
- [ ] Document actual limitations and test status.

## Deferred
- [ ] GPT integration (explicitly not in current release).
- [ ] Cloud backup and sync (explicitly not in current release).

## Version control & release process (from day one)
- [x] Use existing `develop` from starter `main`; preserve `main` unchanged.
- [x] Initialize CHANGELOG.md and pubspec version 0.1.0+1. No release tag created.
- [x] Add GitHub Actions checks and debug APK artifacts on PR/push develop.
- [x] Prepare owner-published-release workflow: stable-main ancestry/version guard, repeated checks, explicitly labeled debug APK + checksum. No release published; workflow cannot publish one itself.
- [ ] Configure stable production signing and verify approved release workflow before distribution. Debug builds from different environments may have different keys.
- [ ] Test update migration of imported audio, templates and recordings before publishing releases.
- [ ] Plan encrypted local backup/export for personal session records before broad distribution.

## Iteration 0.2 — completed working slice
- [x] Import full CODEX_TASK_RU.md 2.0 and the approved references; document later owner clarifications in docs/DECISIONS_V2.md.
- [x] Additive migration SQLite v1 → v2, independent entities and immutable run snapshots; preserve private audio.
- [x] New home clipboard, full-screen structure, three-section library, templates and history screens.
- [x] Golden pause editor opened by the time badge; defaults 00:00, independent minute/second wheels, 5-second detents, haptics, manual input, cancel/apply.
- [x] Foreground audio/timed work engine, exact pause semantics, events/checkpoints and safe exit.
- [ ] Physical Android acceptance: actual audio, tactile feel, screen-reader actions, rotation/large font, missing files and update migration.

## Next working slice
- [ ] Implement standalone recorder: permission, visible recording, pause/resume, preview, title/description, save/delete; no fake active mic buttons.
- [ ] Keep new library recordings, optional topic recordings and in-session recordings separate, with explicit ownership/consent and IDs.
- [ ] Add tested RECORD_MIC execution and proper interruption/cleanup handling.
- [ ] Implement Android foreground media service, media session, notification, background/lock-screen playback and recording policies, Bluetooth and calls.
- [ ] Configure a persistent signing plan and verify upgrading the installed debug app without data loss; see docs/UPGRADING.md. No key/app ID changes made here.
- [ ] Build encrypted local backup/export before broad distribution; Git/APK do not back up personal data.
- [ ] Complete native/device scenarios K1–K10; K5 and background/recording acceptance are not claimed complete.
