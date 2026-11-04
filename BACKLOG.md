# Текущая коррекция v4.2 — 0.4.2+7

- [x] Отдельная ветка от develop с сохранением всех изменений v4.1, аудит и пакет требований.
- [x] Категории Установки/Безопасное место/Прогрессия независимо от происхождения; защита личной записи.
- [x] Компактный выбор аудио тапом, отдельное прослушивание, повторы без закрытия каталога.
- [x] Одна пользовательская Пауза, ноль по умолчанию, утверждённые золотые часы и независимые вертикальные крутилки; совместимость прежних Silence/FreeWork.
- [x] Один scroll/reorder для структуры, захваты фаз/модулей, +/− и отдельное меню, три закреплённых действия.
- [x] Компактные шаблоны, двухстрочная тема и диктофон; корректный экран 0:00/пустого дубля.
- [x] Полноценная колба, мини-плеер на часах и круговой seek; статусы и автоматическая история.
- [x] Дневник: модели/SQLite v4, опубликованный кеш, читатель с пагинацией, авторский редактор/черновики/предпросмотр, защищённый HTTP адаптер и контракт.
- [x] Миграционные, движковые, жестовые и widget-тесты, рендеры Flutter.
- [ ] Живой backend дневника/вход автора: BLOCKED, требуется инфраструктура и авторизация владельца.
- [ ] Физический Android: запись, звонки/Bluetooth, блокировка, вибрация, обновление APK с сохранением данных.
- [ ] Постоянная подпись и зашифрованный экспорт личных данных перед широким распространением.

Ниже — история прежних этапов; актуальный статус выше и в reports/v4_2_TESTS.md.

# v4.1 — 0.4.1+6, feature/v41-final-player

- [x] Аудит исходного состояния; нормативный ночной пакет получен и прочитан, V4 baseline совпадает.
- [x] Timeline по ID экземпляров, track/module/phase navigation, paused load без play, seek, completed/skipped IDs.
- [x] Общий forecast/процент/убывание жидкости, включая неизвестную длительность и нулевой общий план.
- [x] Финальный интерактивный плеер: утверждённые орнаменты, прокручиваемая шкала, часы, 6 переходов, одно завершение с подтверждением.
- [x] Контекстные действия FreeWork через ⓘ, сохранены real recorder/library/templates/history и full frozen plan.
- [x] Unit/widget регрессии и Flutter-рендеры; физическая приёмка ниже остаётся отдельной.
- [ ] Реальный Android: MP3 / mic / lock-screen / long silence / Bluetooth / calls / update signing и сохранение базы телефона.
- [ ] Рекомендации каталожных модулей: отдельный UI редактирования необязательных tags/recommendedPhaseIds.
- [ ] Постоянный ключ подписи и зашифрованная резервная копия — отдельный этап.
- [ ] Визуальная приёмка владельцем реального устройства; референс не является скриншотом готового приложения.
- [ ] Дневник: строго отложен; реализацию/облако не начинать без отдельного задания.

# V4 — 0.4.0+5 (feature branch, не релиз)

- [x] SQLite v3 и идемпотентная миграция с архивом исходных JSON, без удаления media.
- [x] Фазы, каталог модулей и независимые экземпляры; полный снимок запуска, disabled и pre-delay.
- [x] Назначение модулей при импорте/записи, создание/редактирование/архивация каталога.
- [x] Полноширинная главная, модульный конструктор, часы, компактная история и повтор полного плана.
- [x] Нативный диктофон record/AAC, реальные временные файлы, независимые finish/save и обработка ошибок.
- [x] Android audio_service/MediaSession, интервалы вне экранных виджетов, focus/noisy, checkpoint и корректный ранний выход.
- [x] Telegram владельца, конфигурируемая почта, спираль/adaptive launcher, label «Сульфи».
- [x] Автотесты модели, файлового lifecycle диктофона, миграции, истории, media handler и прокрутки; рендеры экранов.
- [ ] Физический Android: нативный микрофон/decoder, permission, слышимый preview, хранение при сбоях.
- [ ] Физический Android: экран off, длинные интервалы, уведомления, Bluetooth, звонки, ограничения батареи.
- [ ] Физический Android: обновление старой установки без потери данных, launcher masks, внешние контакты.
- [x] Контакты владельца подтверждены: Telegram и `luxhypnomaster@gmail.com`.
- [ ] Постоянный ключ подписи и зашифрованная резервная копия отдельным этапом.
- [ ] Проверка владельцем художественной близости к референсам; поставленная готовая спираль отличается от нарисованной.

Предыдущие этапы ниже — исторические; противоречащие им требования заменены V4. Подробная приёмка: [docs/VERIFICATION_V4.md](docs/VERIFICATION_V4.md).

# Build plan

## Owner remarks 0.2.2+4
- [x] Built-in stage list with descriptions, visible empty stages, per-section insertion and category routing without sorting execution.
- [x] Explicit zero pre-delay for new tracks; distinguish track duration and overall session duration, with an empty-state label.
- [x] Fixed, non-scrolling clock page; vertical-only wheels, haptic detents, visible controls and compact real preview at small sizes.
- [x] Preserve legacy group fingerprints and separate snapshots; cover the changes with storage and UI regression checks.
- [x] Superseded by final V4: ten approved phase types; legacy groups preserved by migration.

## Visual correction 0.2.1+3
- [x] Bring main / structure / pocket watch composition closer to the approved references with real controls.
- [x] Keep start and the single navigation row visible on a 360×720 phone; verify round-trip navigation and preview teardown.
- [x] Replace procedural flat panel with clean decorative leather artwork; compact technical editor controls.
- [ ] Owner device review of the revised layout, touch targets and haptics.

## Diary — publication entirely inside Sulfi (0.4.3+8)
- [x] Native Google login instead of token-entry UI; independent reader, local author and server publication permission.
- [x] One app: autosave/preview, explicit cloud draft backup/restore, publish/unpublish.
- [x] Apps Script/Drive server with RS256 verification, version conflicts, locks and private/public projections.
- [x] Tests for account gating, logout/races, cloud failures/conflicts, redirects, signatures and storage.
- [ ] Authorized Apps Script management, real OAuth clients, stable signing and deployment to the owner's project; existing source backed up.
- [ ] Real Google login, private draft backup, publication/unpublish and sync on two physical phones.
- [ ] Review UI for edits of the same draft across devices; restore currently imports missing IDs and preserves all existing local work.

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
