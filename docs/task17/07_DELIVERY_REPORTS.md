# №17 — выходные материалы и контроль затрат

## Разместить в НОВОЙ папке `Отчёты — Задание 17` внутри проекта, не удаляя отчёты №16

1. `RESULT_17.md`: точные source SHA, ветка/PR, build/deployed endpoint versions, список изменений по гейтам и честный overall статус.
2. `ROOT_CAUSE_17.md`: воспроизводимые симптомы, конкретная трасса auth/queue, файлы/функции, отличия до/после и ссылки на тесты; неподтверждённое оставить hypothesis.
3. `ACCEPTANCE_17.csv`: матрица по `02_ACCEPTANCE_17.csv` с колонками `Code`, `Controlled`, `Live`, `Owner`, evidence links, status PASS/PARTIAL/BLOCKED/FAIL/NOT_RUN. Нельзя повысить PARTIAL до PASS без соответствующего доказательства.
4. `TESTS_17.md`: команды/результаты targeted unit/widget/service, безопасные mock/fake tests и Android native; реальные Google/Drive и QA владельца в отдельном разделе, не выдавать fake за live.
5. `SECURITY_17.md`: JWT/verified sub, owner isolation, 401/403, redirect safety, private catalog, logout, idempotency, отсутствие credential logging.
6. `MIGRATION_17.md`: доказательства неизменности SQLite/content IDs, native upgrade MASTER25/26→candidate и CLIENT25→candidate, сертификат, rollback, WAL/journal, media hashes.
7. `PHONE_QA_17.md`: конкретный тестовый план без ПК, что владелец должен проверить, какие действия не просить, что не проверено; по возможности мини-таблица results.
8. `APK_PAIR_17.json` **только если** safe release candidate реально создан: package, versionName/versionCode, cert digest, raw downloaded SHA256, bytes, exact verified private GitHub link (если выдача разрешена), produced-from SHA. Если не создан — честная причина и НЕ выдумывать ссылку.
9. `CODEX_EFFICIENCY_17.md`: фактические затраты на фазу G0–G5: какие тесты/CI повторены, почему, какие run IDs, какие проценты weekly/5h владелец сообщил (если вообще сообщил), рекомендации по следующему запуску. Не придумывать данные.
10. `DRIVE_READBACK_17.json`: подтверждение upload/size/hash/parent новых отчётов. Не запускать бесконечный retry для Drive, на ошибке показать конкретный blocker.

## Правила исполнения

- **Сначала G0 узкий воспроизводимый audit**, потом адресные исправления G1/G2. После каждого gate — короткое decision note, не многократный гигантский CI на каждый текстовый файл. Но full Android data preservation/security gate перед выдачей обязателен.
- При необходимости live серверного изменения: показать проверенный diff GAS6 с impact, deployment script, rollback и список exact calls; остановиться и запросить явное одобрение. Не выполнять втихую.
- Для API quota/DNS/TLS/401/403/redirect отвечать реальными стадиями с trace, а не магическими «увеличить таймаут»/«отключить HTTPS»/«сбросить авторизацию».
- Промежуточные гейты в одной задаче не означают параллельное написание нескольких независимых серверов/очередей. Ресурс Codex расходовать на доказательство working scenario.
