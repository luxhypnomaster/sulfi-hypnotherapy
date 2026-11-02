# Build plan

## Milestone 0 — bootstrap
- [ ] Initialize Flutter application and Android target; configure Russian locale and theme.
- [ ] Choose and check current compatible packages; establish local database and app-controlled media storage.
- [ ] Add lint/tests/CI (GitHub Actions on PR). Run `flutter analyze` and `flutter test`.

## Milestone 1 — working audio library
- [ ] Import MP3/M4A/WAV from Android picker; copy into internal storage.
- [ ] Read/display duration and category; preview, rename, delete asset.
- [ ] Test invalid audio, canceled picker, missing files.

## Milestone 2 — session constructor
- [ ] Support three block types: AUDIO, SILENCE, RECORD_MIC.
- [ ] Reorder/duplicate/remove; edit silence/record durations; validate timeline.
- [ ] Save/load templates; calculate estimated duration.

## Milestone 3 — player engine
- [ ] Sequential execution and transitions without gaps or double-starts.
- [ ] Background playback, lock-screen handling, pause/resume/next.
- [ ] One-tap Finish and exit; select an exit audio asset for template.

## Milestone 4 — session records
- [ ] Pre-session topic recording with permission, consent and playback/delete.
- [ ] Microphone recording blocks, clear recording indicator, playback/delete.
- [ ] Session history with local-only data; handle interruptions and recordings carefully.

## Milestone 5 — Android testing and package
- [ ] Real-device manual validation with screen locked, earbuds, interruptions and denied permissions.
- [ ] Fix issues; build signed or debug APK as appropriate and explain installation.
- [ ] Document actual limitations and test status.

## Deferred
- [ ] GPT integration (explicitly not in current release).
- [ ] Cloud backup and sync (explicitly not in current release).

## Version control & release process (from day one)
- [ ] Create `develop` from stable `main` after adding starter files.
- [ ] Initialize `CHANGELOG.md`, version metadata and release tags as outlined in VERSIONING.md.
- [ ] Add GitHub Actions checks for PRs after Flutter bootstrap.
- [ ] Add tested APK build as a GitHub Release asset on approved stable tags.
- [ ] Test update migration of imported audio, templates and recordings before publishing releases.
- [ ] Plan encrypted local backup/export for personal session records before broad distribution.
