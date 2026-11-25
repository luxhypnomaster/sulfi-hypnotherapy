# №26: изолированный синтетический STAGING-кандидат

Это локально проверяемый bootstrap в существующем `server/alchemist`, не новый production backend и не полный Протокол 22. Live ONREZA пока BLOCKED. GAS6, Android, Auth19 и очередь №18 не подключены и не меняются. Не направлять сюда реальные аккаунты или материалы.

## Запуск и проверки

Node 24.19.0, npm, точный lockfile:

```sh
cd server/alchemist/onreza26
npm ci --ignore-scripts
npm test
npm run build
node preflight.mjs
npm start
```

Последняя команда без секретов запускает только минимальный `/healthz`; `GET` → `{"status":"ok","environment":"staging"}`, неправильный метод →405, неизвестный путь →404. `PORT` по умолчанию3000, bind0.0.0.0. Это локальный HTTP, не доказательство HTTPS у провайдера.

`preflight.mjs` при отсутствии NRZ_TOKEN возвращает exit2/BLOCKED_OWNER, без поиска ключа в файлах. Он не устанавливает CLI, не авторизуется и не создаёт ресурсы. Дальнейшие точные read-only команды — в runbook.

Пакет `pg` закреплён; PGlite — только dev dependency и локальный PostgreSQL WASM engine, не тест управляемой БД ONREZA. Отдельный schema `p22_stage26`, явная миграция001, никаких автоматических миграций при запуске приложения. Для изолированной DB нужен `P22_STAGE26_DATABASE_URL`, generic DATABASE_URL не используется.

## Контракты

- `core/security.mjs`: синтетические JWT HS256 (не Google), проверка issuer/audience/scope/expiration/binding; отдельные signing keys только в protected runtime.
- `adapters/postgres.mjs`: SQL — authority; стабильный uid по verified issuer/sub, привязка установки, default CLIENT; никакого email auto-link. SQL recheck для publish, immutable verified snapshots, HEAD+receipt+outbox в одной транзакции. При current roleVersion mismatch запрос запрещён.
- `core/publisher.mjs`: один общий bounded drain для session/HEAD. Потеря KV не удаляет SQL. Нет `setInterval`, keep-alive или недолговечной waitUntil-очереди.
- `adapters/kv.mjs`: get/put/delete/TTL и capability contract. MemoryKV с version fence — **только fake**, не гарантия ONREZA. Для ONREZA `monotonicWrite=false`: publisher и reader HEAD блокируются `ORDERING_NOT_PROVEN`; get+set не считается CAS.
- `core/reader.mjs`: basic session можно проверить по подписанной KV-проекции с экспериментальным сроком≤30s; проверка чувствительных действий всегда через SQL. Это не production SLA немедленного отзыва. KV outage fail-closed; только допустимый miss делает один контролируемый SQL fallback после криптографической проверки.
- `light.nrz-fn.mjs`: self-contained handwritten ESM Function; CORE `light()` получает порты, ctx только в binding. Синтетический session/check не вызывает SQL/Compute; miss →503 и отдельное подтверждённое восстановление на Compute. HEAD на реальном неподтверждённом KV закрыт. Function не принимает роль из заголовка и не выдаёт sensitive ACL.
- Повторно используется **неизменённый** `experimental/catalog_snapshot.cjs` №20–22: canonical JSON/hash/проверка exact dependencies. Синтетический public snapshot дополнительно ограничен безопасными полями и `synthetic-*` IDs. Полный metadata/runtime22 синхронный SQLite, потому PostgreSQL не подставляется за него без отдельного async revision.
- Независимый verified ratings adapter не подключён: передача ratings HEAD отвергается, новые wire fields/фиктивный рейтинг не создаются. Полная интеграция №22 остаётся открытой.

## Сборочный контекст

`build.mjs` копирует **только** этот runtime и прежний verifier в `dist`, создаёт manifest v2 и build receipt. Android, GAS src, тесты, приватные файлы и dev node_modules не входят. Build воспроизводим по байтам; CLI Functions/manifest preflight ещё NOT_RUN. Полный checkout Android в провайдер не передавать. Runtime dependencies устанавливать из lockfile с `--omit=dev` в curated context перед проверенным deploy.

Не деплоить текущий кандидат, пока не закрыты защищённый доступ, inventory/стоимость/остаточный расход, лимит владельца и доказательство порядка KV. Идентификаторы ресурсов хранить только в закрытом паспорте. Подробный порядок продолжения: `reports/task26/DEPLOYMENT_RUNBOOK.md`.
