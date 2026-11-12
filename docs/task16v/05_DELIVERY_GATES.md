# G3 — Обязательные пороги готовности к передаче владельцу

## Проверки
- `flutter analyze`, полный Flutter regression suite, Node security/domain, CI; при наличии изменений backend — только локальные tests, deploy запрещён.
- Native signed APK24→candidate26 same package/cert **с проверкой реальных UI-created objects**, до/после точные identity IDs, audio SHA, module graph, diary drafts, history, templates, capsule presence, SQLITE integrity.
- Cold restart / offline / Google refresh / account switch / queue failed, stale WAL / crash injection на disposable окружении. Не пытаться у владельца выполнить запрещённую миграцию/восстановление до backup/approval.
- STOP-SHIP при любом missing track/module/diary draft; STOP-SHIP если session/error silently falls back to empty DB; STOP-SHIP при privacy cross-account; STOP-SHIP без documented recovery path для owner.
- Сравнение до/после не должно засчитывать synthetic DB setup как эквивалент реального Android поведения. Поведение после update должно быть **fail-closed при опасности изменения данных**.

## Результаты, строго по стадиям
`RESULT_16V.md`, `ROOT_CAUSE_16V.md`, `DIFF_AUDIT_16V.md`, `UPGRADE_REPRO_16V.md`, `RECOVERY_LIMITATIONS_16V.md`, `OWNER_RECOVERY_PLAN_16V.md`, `CHANGES_16V.md`, `TESTS_16V.md`, `ISSUES_16V.md`, `ACCEPTANCE_16V.csv`, `EVIDENCE_INDEX_16V.md`, `APK_CANDIDATE_16V.md` (только если готов и безопасен).

В каждую матрицу добавить Code/Emulator/Owner evidence отдельно. Физическую потерю данных не объявлять решённой до фактической проверки владельца. Допускается **PARTIAL/BLOCKED**, если безопасность не может быть доказана: лучше не выдавать APK26, чем подвергать опасности библиотеку.

Писать в существующую папку результатов задания №16 в Google Drive: https://drive.google.com/drive/folders/1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z . Старые отчёты не менять/не удалять. Existing PR45 — traceable baseline; отдельная ветка/черновой PR для hotfix, без merge/main/deploy. Если нет загрузки в Drive, выдать ссылку на commit/PR и безопасный readme, но не заявлять, что отчёты уже опубликованы.

## После выполнения
Не запускать полномасштабный №17, программу-витрину или новый сервер. Только после data recovery вернуться к №16-Б и проверке MASTER/CLIENT auth/catalog/ContentLink/offline.
