# Выполненные изменения разрешённого продолжения

- Scoped owner exception в stagingTargetPlan: только совпавшие workspace/project, Hobby, logicalEnvironment=staging; без глобального fallback на Production или upgrade.
- Native probe для настоящего HTTP runtime: фиксированный SELECT1 и ограниченный KV опыт; отдельная capability, в config только SHA256, expiry≤1200s, auth до bindings, byte cap512, fail-closed. Произвольный SQL/публикация/регистрация отсутствуют.
- Исправлены реальные ошибки Edge Rules: schemaVersion EDGE_RULE_SET_V1 и terminal override. Official CLI regression проверяет обе Functions и все 3 правила.
- Curated Git source branch того же репозитория,27 файлов, pin к проверенному source; официальный remote Git build обходит недоступный прямой SourceV2 transfer из Codex без альтернативного сервера.
- Привязана уже существующая SQL к тому же Service/environment, Functions default; DB URI auto-inject=false. Compute CPU250millicores/idle60s, SQL0.25CU/suspend60s.
- Диагностические результаты, rollback/restore и конечное состояние фиксируются раздельно; никакие Android/GAS6/main/signing/Google OAuth/пользовательские данные не менялись.

---

## Предыдущий checkpoint — история, не текущий статус

# Изменения нового продолжения

- Документированные registry/capabilities readback и официальный nrzdeploydry без publishing. Настоящее ограничение Hobby→CustomPro сохранено безсекретов.
- staging_target26.mjs: чистый read-only planner, строгие workspace/project/target/type/participation, noProductionfallback/no tariffchange.
- resource reconciliation: savedSQLID/underscore имя, отдельныйподтверждённый SQLownerProduct, обязательнаяпроверка Service/environmentbinding; чужие workspace непринимаются. Actual-topologyregressionRED→GREEN.
- 5 новыхсодержательных tests; финальныйобщий 65PASS с officialCLI. Paid/nativeAndroid/GAS/main неизменялись.


---

## Предыдущий checkpoint, сохранён для истории

# Изменения текущего продолжения

- Применено обновлённое разрешение26-А и rolling24h правило; первоначальные входные файлы26 сохранены как исторический baseline.
- BillingCache требует явный store; durable PostgreSQL adapter и additive002_billing_cache.sql. lastAttempt до upstream, lastSuccess только после success; атомарная lease и fencing completion, отдельные LastGood по period, suppression после failure/restart/manual,401/403 hide,429 Retry-After, bounded timeout, no polling/UI.
- Добавлены12 policy/PGlite регрессий, официальный opt-in CLI/Function runtime test и безопасный native SQL smoke (URI только env, strict TLS, sanitization). Smoke не выполнил SQL из-за TCP refusal.
- onreza.toml фиксирует конкретный frozen Compute entry. Исправлена доказанная несовместимость infer-entry в CLI build.
- Разрешённое provisioning минимальных постоянных ресурсов, timeout reconciliation без duplicate POST, прямой/pooled диагноз и safe stop; private паспорт сохранён отдельно.
- Только docs/task26, reports/task26, server/alchemist/onreza26. Нет изменений №25, приложений, live GAS, main, signing или ACL.

---

## Исторический снимок до разрешённого live-доступа (не текущий статус)

# Продолжение26-А

Актуальное изменение и base — CHANGES_26A.md, code SHA/checkpoint — DELIVERY_26A.json. Та же Draft PR77, без новой ветки/merge/deploy. Ниже сохранён кодовый этап26 до дополнения.

---

# Изменения №26

Отдельная ветка `feat/task26-onreza-staging`, база `ff32a0f86b8fe9c5ffe7e75406d8b3291471d9c2`, PR54 `feat/task22-server-ratings-admin`. Кодовый SHA `fa053239d2d8ac91bf9fbaa9158815e20bf67f46`; [Draft PR77](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/77), не merge. Последующие коммиты только отчётные, кодовый tree сохраняется.

PR51→52→54→55→56→57 остаются OPEN DRAFT, не merged. Актуальные SHA PR54 `ff32a0f…`, PR55 `85fa532…`, PR56 `d0a6d9a…`, PR57 `ef9d894…`; GitHub compare подтверждает PR54 — предок PR57, ahead78/behind0. Readback main `ef32862e07f5da07b610d29c721677b27ce1704e`, protected=true; локальный origin/main старее и не использован как доказательство текущего main.

Выбор базы: асинхронный PostgreSQL bootstrap относится к существующему серверному контуру №22. №23–25 меняют Android/данные/навигацию/native gates и не нужны для этой изолированной работы. Их ветки и worktree не checkout/reset/rebase. Draft PR26 направлен в ветку №22, не main.

Изменены только новые пути:
- server/alchemist/onreza26: код, schema001, adapters, Function, tests, pin/lock, build, README;
- docs/task26: оригинальные7 файлов архива;
- reports/task26: очищенные результаты/матрица/логи/provenance.

Прежние файлы каталога, IAM22, рейтингов, очередей и GAS не редактируются. `catalog_snapshot.cjs` переиспользуется через import/curated copy; полная SQLite реализация22 не выдаётся за уже портированную PostgreSQL. CORE не использует ctx.kv/ctx.sql; ONREZA bindings явно выделены. Никаких deployment/release workflows или secrets в PR.

Отдельно закрыты обнаруженные boundary-дефекты нового кандидата RED→GREEN: пустой scope в подписанном JWT, читатель HEAD без version fence, скрытые/private поля синтетического public snapshot. Исторические RED логи сохранены, результат не скрыт.
