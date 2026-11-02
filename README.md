# Сульфи — гипнотерапевт

Android-first offline audio session builder for guided self-hypnosis and personal self-regulation.

**Status:** project kickoff specification, not a completed app.

## Mission

The user imports an existing voice recording (including the custom Sulfi voice from Suno), assembles it into a repeatable session using audio, silence and microphone recording blocks, saves templates and plays a session with reliable background audio and an accessible exit procedure.

## Version 0.1 scope

- Import local MP3, M4A and WAV audio files (with validation and clear errors)
- Maintain an editable local audio library (title, duration, type/category)
- Compose a sequence of blocks: AUDIO, SILENCE, RECORD_MIC
- Reorder, duplicate, remove and configure blocks
- Persist reusable session templates and a named session with a date/topic
- Optional pre-session recorded topic/message as a recording, and optional microphone recording block *during* a session; alternative: silent work block
- Playback with block progress, total estimated time, pause/resume, next, and user-initiated end-of-session transition to an exit module
- Local-only storage; no login, cloud sync, analytics, payments or GPT in v0.1
- Foreground audio and recording behavior verified on Android device

## Recommended stack (confirm currently maintained packages)

Flutter (Dart), Android primary target. Evaluate `just_audio`, `audio_service`, `record`, `file_picker`, `path_provider`, a simple persistent data layer (e.g. SQLite) and current Android permissions / foreground service requirements. Do not use the stack names as a substitute for verifying current SDK/package APIs.

## Setup

This folder is a product-and-engineering handoff. A coding agent should initialize a fresh Flutter project in the repository and then implement functionality in slices, checking build and tests after each slice.

Read [SPEC.md](SPEC.md), [AGENTS.md](AGENTS.md), [BACKLOG.md](BACKLOG.md) before implementing.

## Versioning and rollback

Read [VERSIONING.md](VERSIONING.md) for the `main` / `develop` / feature-branch policy, tagged releases, APK retention and data-safe rollback expectations.
