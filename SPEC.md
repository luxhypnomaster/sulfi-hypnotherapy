> Последнее задание: [«Задание 3» из папки Google Drive](docs/task3-2026-11-06/TASK_RU.txt), три обязательных раздела — главная, библиотека и полноэкранная структура. Имеет приоритет над прежними ограничениями: жёлтый знак/вихрь/две строки темы, компактная библиотека с OR нескольких категорий и AND поиска/раздела, четыре нижних действия структуры с фуксиевым добавлением фазы слева и без верхнего плюса. Данные и существующие рабочие функции сохраняются. [Отчёт и приёмка](reports/task3_home_library_structure.md).

> Последнее точечное задание 06.11.2026: [структура сессии](docs/session-structure-2026-11-06/TASK_RU.txt). Только полноэкранный редактор: фуксиевая фаза → вложенный светлый модуль → компактные строки; постоянные стрелки, отдельные меню, смешанный порядок и вставка в выбранное место. Внизу ровно «Выбрать» / «Сохранить» / «Применить», добавление фазы сверху. Это уточнение имеет приоритет над прежними четырьмя кнопками MVP. Главная и другие подсистемы сохраняются. [Отчёт](reports/session_structure_hierarchy.md).

> Позднее уточнение владельца 05.11.2026: [модули и главная 0.4.7+12](reports/modules_catalog_home.md). На главной раздел «Шаблоны и модули», две вкладки каталога; новый модуль сразу редактируется и сохраняется вместе с составом. Главная следует `2479.jpg`. Замечание об отдельных треках/паузах отозвано; их поведение сохраняется.

> Базовое сводное ТЗ: [MVP от 05.11.2026](docs/mvp-2026-11-05/SULFI_MVP_ALL_SPECS_RU.txt). При противоречиях оно заменяет прежние требования, с учётом уточнения выше. Первая поставка — полноэкранная структура, редактор модуля и минимальные связи Home; [реализованное и оставшиеся этапы](reports/mvp_session_structure.md). Рабочие дневник, пауза, аудио и данные сохраняются.

> Ниже — архив исходных требований и ссылки на историческое [v4.2](docs/v42/00_READ_FIRST.md). Дневник включён в MVP; старый запрет отменён.

> Архив предыдущих требований. Действуют [V4.0](docs/v4/00_README_RU.md) и [финальный плеер v4.1](docs/v41/02_PLAYER_FINAL_SPEC_V4_1_RU.md). v4.1 переопределяет UI/навигацию активной сессии, остальной V4.0 сохраняется; v2/v3 заменены.

# Product requirements: Сульфи — гипнотерапевт

## 1. Vision and intended use
A locally operated Android application for constructing and playing sessions from pre-recorded spoken audio in Sulfi's established voice. The app is an audio composition and self-regulation tool, not an autonomous therapist. No AI dialogue or GPT integration in version 0.1. The voice is generated externally (in Suno); the app imports the exported files. Do not require Suno API or voice-cloning functionality.

## 2. Core data objects

### AudioAsset
`id`, `title`, `filePath`, `durationMs`, `format`, `createdAt`, `category` (e.g. induction, deepener, integration, exit, freeform), `fileSizeBytes`. Import copies files into app-controlled storage, so a deleted external original won't break saved sessions. Never store private audio files in a publicly accessible location by default.

### SessionTemplate
`id`, `name`, `description`, `blocks[]`, `createdAt`, `updatedAt`.

### SessionInstance
`id`, `templateId`, `startedAt`, `topicText` (optional), `topicRecordingAssetId` (optional), `blockStates`, `userRecordings[]` (local), `status` (planned/running/completed/interrupted).

### Block
- `AUDIO`: `assetId`; playback once. Optional fade in/out (not required first slice).
- `SILENCE`: `durationMs`; no mic recording.
- `RECORD_MIC`: `durationMs`; record microphone to local file during this block; display clear recording indication. Permission prompted when needed; if denied, offer switch to silent block rather than crashing.

All blocks should have stable IDs so that reordering and persistence are safe.

## 3. User flows

### Import audio
Home > Library > Add audio > OS file picker > validate, copy and read duration > editable title/category > saved locally. Support rename, preview, delete with clear handling of references in existing templates.

### Compose session template
Templates > New > set name > Add block > select audio / silence / recording > set duration for timed blocks (e.g. seconds or minutes) > reorder by drag and drop > duplicate/delete > estimated total time including audio durations > save template.

### Start a session
Choose template > optionally record a short spoken topic (or enter text) > choose session date and name > preview timeline/expected total > Start. Pre-session topic recording is stored separately unless explicitly inserted into playback; never play the user's private topic automatically without user consent.

### Session playback
Immersive simple controls: current step, elapsed time, remaining time, pause/resume, next step, extend timed block (+1/+5 minutes), move to safe exit. Sleep screen / background audio should work. If recording, explicit on-screen/mic status and prominent notification. Do not silently record. User can manually end a recording block early.

### Completion
At normal sequence completion, play the designated EXIT block if present. During a session provide an always-available "Finish and exit" action that transitions to the selected exit track. On failed audio/permission/abrupt interruption, stop safely with a notification and simple orienting text; avoid promising automatic playback on app termination. If no exit track is set, do not pretend one exists: show a safe text-based grounding sequence and flag the template when saving.

## 4. UX
Russian-language UI in v0.1. Three core tabs: Audio Library, Session Builder/Templates, Player/Session History. Dark visual system; deep navy, restrained magenta and acid-green accents inspired by Sulfi, with legible typography and accessible touch targets. Keep the player low-cognitive-load, with a big Finish and exit action.

## 5. Audio playback and microphone recording engineering
- Respect Android audio focus, playback media session, interruptions and device sleep.
- Recording and playback may require different audio focus/routing; test combined behavior on actual Android devices. During RECORD_MIC blocks default to recording without playing another voice track.
- Account for audio-player teardown, canceling timers on pause/resume, process death, corrupt/absent files, Bluetooth handsets and permission denial.
- Save recordings incrementally/at end of a block and avoid leaving partial files unmanaged.
- Add explicit pause/resume semantics: the user should not lose time in silence or recording blocks by pausing the entire session.
- Session duration = sum of audio durations and timed blocks. For indefinitely extended user-controlled work, show a clear varying estimated time.

## 6. Privacy
Only on-device recording and storage. No telemetry, external uploads, signup or embedded third-party analytics in v0.1. No sensitive audio in logs. Include local deletion and an explicit all-data reset option. The GitHub repository is PRIVATE and must not include real user recordings, audio assets, personal material or access secrets.

## 7. Safety and scope
The product is for personal self-regulation and audio guidance, not clinical diagnosis, trauma regression, false-memory recovery, or a claim to cure psychiatric conditions. Provide an optional plain-language caution against use while driving, and an on-demand orientation/exit function. Avoid "guaranteed trance", "guaranteed memory recovery" and similar claims. No GPT interpretation in v0.1.

## 8. Release acceptance tests
1. User can import three sample locally sourced audio files, see correct titles/durations and preview playback.
2. User can create a template consisting of AUDIO > SILENCE > AUDIO > RECORD_MIC > AUDIO, save it and reopen it with stable ordering/durations.
3. User can speak a pre-session topic recording and subsequently play or delete the local file.
4. Player executes timed silence and records microphone audio for recording block (with permission).
5. Pausing and resuming both playback and timers does not skip/duplicate blocks; extending a block updates remaining time.
6. Background/locked-screen behavior works on a real supported Android handset and doesn't leak mic access.
7. Finish and exit routes to configured exit track from any active block, stops microphone capture, and offers a clear completion screen.
8. App restarts without losing templates and imported audio metadata.
9. `flutter analyze` and `flutter test` pass; Android debug build created when SDK available.
10. Document any untested device-specific behaviors; do not falsely claim they pass.

## 9. Not in v0.1
GPT, AI-led therapeutic interpretation, automatic emotion/memory inference, cloud accounts, subscriptions, streaming, proprietary Suno integration, marketplace, remote speech synthesis, iOS build, clinical record systems.
