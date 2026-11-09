# ЧТО CODEX ДОЛЖЕН ВЕРНУТЬ

Папка `For_Codex/Отчёты — Задание 15`:
- `RESULT.md` — какие Gate сделаны, вердикт `READY_LOCAL_CONTRACT_ONLY|PARTIAL|BLOCKED`, status 6 phases и ключевые evidence, свежий SHA/PR/CI/APK links.
- `BASELINE_15.md` — перед изменениями: Git, schema/manifest, service APIs, реальные роли и client build.
- `PROGRESS.md` — последовательно сохранённые gate checkpoints (по одной записи на этап).
- `CHANGES.md` — точные изменённые файлы, почему, что сохранено.
- `TESTS.md` — все acceptance IDs из `ACCEPTANCE_MATRIX.md`, PASS/PARTIAL/FAIL/BLOCKED/NOT_RUN и доказательство (test log screenshot Git path). Не суммировать вложенные targeted/full counts.
- `MIGRATIONS_AND_ROLLBACK.md` — schema before→after, populated fixtures, hashes, аварийные тесты, план без потери данных и фактические ограничения Android.
- `ISSUES_AND_NEXT.md` — только реальные остатки, проблемные paths/commits, no fake DONE, следующий этап №16 server.
- `SERVER_HANDOFF/` — API, JSON schema, auth, conformance, playbooks для реального сервера.
- `screenshots/` — настоящие Flutter renders новых UI, разные экраны/модели; отдельно пометить «эмуляция» и «physical owner device».
- `APK_INFO.md` — оба построенных CI artifacts (author/client) либо честная причина отсутствия; sha/signing/package IDs, реальные URLs и срок жизни artifacts.

Проверить полный CI после финального коммита; если CI не запустился — явно BLOCKED. Не лгать о физических установках и рабочем облаке. Не размещать реальные аудио, токены, личный дневник, авторские ключи на общедоступном Drive.
