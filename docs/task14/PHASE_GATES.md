# ТЗ №14 — ЭТАПЫ, ЗАВИСИМОСТИ, ОТКАТЫ

## Этап 0 — проверка базы (не изменять содержимое)
- Проверить актуальный Git base/branch относительно №13 final `64639bd627eb102781c69d78d9d8889b05646c2f`, schema, known tests, desktop/device boundaries.
- Доказательства: BASELINE_AUDIT, git log/status, version schema, список проверенных работающих функций.
- Если уже существует selective importer/catalog/ContentLink — указать фактические файлы, тесты, версию и не переписывать.

## Этап A — K-029: кнопка «На главную страницу»
- Минимальный UI diff с approved 9:16 макетом, новая кнопка, безопасность back stack и 3 действия.
- Доказательства: widget navigation assertions, Flutter screenshots, unchanged session history.

## Этап B — K-025: индикация модуль/шаблон
- Реальная diff-компарация с исходной конкретной библиотечной ревизией; отредактировали → highlighted, Undo → normal.
- Доказательства: widget + unit tests на changed/unchanged/unknown provenance, RunScreen color regression.

## Этап C — exports и version keys
- Reuse CapsuleService, selected exports/manifest/closure, safe import/rollback. Legacy capsule fixtures PASS.
- Доказательства: track/module/template roundtrip fresh DB, sha mismatch, duplicate, missing, no data leak.

## Этап D — immutable revisions / provenance
- Additive schema, pinned refs, personal forks, safe migration. Hard failures documented, no auto-rebase of history.
- Доказательства: old DB→new, personal fork preserves official, revision 1 retained after revision 2, old history snapshot intact.

## Этап E — локальный каталог / selector / installer
- Exact dependency closure, content-addressed verify/stage/commit, offline fixture, UI installed state.
- Доказательства: install template with shared tracks, only missing blobs, idempotent repeat, cancel/restart corruption/storage tests.
- Нет сети = не считать продакшен-каталог опубликованным. Не разворачивать Apps Script.

## Этап F — ContentLink дневника
- Exact type/version/digest link, old diary serialization preserved, installed/missing/unavailable UX.
- Доказательства: local diary card→catalog/installer and error case. Live publication requires independent authorization/deployment, не входит.

## Этап G — full regression / CI / docs
- Final analyze, full tests, migration recovery, existing CI/APK signing, screenshot set, user-visible summary.
- Никакого merge в main без явного решения владельца. Дать PR и report folder, без работы в фоновых процессах после ответа Codex.

## Если возникнет блокер
1. Сохранить отдельные проверенные и неразрушающие A/B.
2. В C/D делать безопасные additive изменения; если нельзя гарантировать migratable state — остановить опасную часть, сообщить причину, не запускать migration на данных владельца.
3. В E сделать реальный локальный fixture installer и тесты. Если локальный перенос тоже невозможен — честный PARTIAL, а не визуальная заглушка.
4. F не должен зависеть от отсутствующего сервера — выполнить локальную ссылку и контракт или BLOCKED.
5. Всегда выдать отчёты по ВСЕМ блокам и строкам матрицы, даже NOT RUN. Не начинать новые задачи из отсутствующих данных.
