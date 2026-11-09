# TASK_015 — точки продолжения

Ветка: feat/task15-pre-server-readiness. База №14: 9982df546aa032d014244df8f4483434294f350b. Не начинать задачу заново. Протокол: docs/task15/RESUME_INSTRUCTIONS.md. after_sha — коммит кода/результата gate; последующий metadata-коммит сохраняет эту запись, не меняя проверенный код.

## G0 — COMPLETE
- before_sha: 9982df546aa032d014244df8f4483434294f350b
- after_sha: 31b731a (docs/task15 baseline)
- PASS_IDs: BAS-01, BAS-02, BAS-03, BAS-04 (аудит и прежний restricted diff; окончательный CI BAS-05 наG6)
- PARTIAL_IDs: прежние №14 EXP-08/VER-02/CAT-03/CAT-04/CAT-06 остаются открыты, не переносить PASS на№15.
- open blockers: root был около9МБ; build cache без удаления перенесён вRAM, symlink build сохранён. G3 exact audio byte retention ещё не реализован. Live server запрещён. ФизическогоAndroid нет.
- touched files/tables: docs/task15/, никаких пользовательских таблиц/файлов. Архив №14 подтверждёнmetadataDrive в TASK_014.
- last tests: flutter test --no-pub test/task14_composition_test.dart test/task14_content_test.dart --reporter expanded — 4PASS; повтор всего379 baseline не нужен при неизменномSHA.
- next gate: G1 ACTIVE — occurrence A/B/C, отдельныйmarker, Home shield/shared sheet.
- next command: rg -n 'metadata refresh|moduleDiffersFromSource|_privacy' test/mvp_structure_test.dart lib/services/session_controller.dart lib/ui/library_screen.dart

## G1 — IN PROGRESS
Читать TASK_RU.md §1 и acceptance UI-01…UI-13. Не переписывать уже работающий CapsuleService/плеер. Проверить гипотезу: editor.reload обновляет durationMs всем старым экземплярам, но источник хранит прежний кеш длительности; новая копия C не проходит этот refresh. Прежде фикса написать regression с такой metadata drift и реальным A/B/C, persistence и Undo. Сохранить существующий тест metadata refresh.

G2–G6: NOT STARTED. SERVER_READY: NO до завершения P0. Отчёты: https://drive.google.com/drive/folders/1rq9fFTwMDmayx8M6eNdbIiNJALYLJwmS
