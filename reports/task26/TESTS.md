# Финальная проверка после actual-topology/target исправлений

`P22_NRZ_BIN=<verified CLI0.54.0> XDG_CACHE_HOME=<taskcache> npm test`:65PASS/0FAIL/0SKIP,47778.984681ms. Лог evidence26staging/full-stage-target-tests.log. Включены PGliteengine и real localFunctions runtime/CLIbuild. Не cloudSQL/Google/телефон PASS.

Resource-topologyRED:2 старых PASS/2 новых FAIL; после patch7 адресных PASS(4reconcile+3target). Новый targetcomponent до implementation давал missingmodule; невыдаётсязадефектпрежнегопродукта. Новый actual SQLownerregression реальновоспроизводилошибку SAVED_ID_MISMATCH/STOP.

LIVE:registry/capabilities200;официальный dryRUNBLOCKEDENVIRONMENT_NOT_FOUND;normalizedtargetguardBLOCKED_CUSTOM_ENVIRONMENT_REQUIRES_PRO/0mutations;finalSQLstopped18:28. JSON доказательства evidence26staging/STAGING_CAPABILITY_READBACK.json. Повторныйполныйпрогоноправданизменением resourceCORE и 5 новыми tests,неповторомнеудачного native теста.


---

## Предыдущий checkpoint, сохранён для истории

# Проверки текущего продолжения — фактические границы

| Проверка | Результат | Доказательство |
|---|---|---|
| npm test, весь runtime26 |59PASS /0FAIL /1SKIP,46430.649794ms|evidence26live/full-continuation-tests.log|
| opt-in P22_NRZ_BIN official CLI test |1PASS /0FAIL /0SKIP|evidence26live/provider-cli-test.log|
| Предварительный targeted billing24h/billing/budget/build |28PASS /0FAIL /0SKIP,8683.855ms; подмножество полного прогона|evidence26live/billing24-tests.log|
| Official nrz build, correct root + onreza.toml |PASS; COMPUTE entry onreza26/compute.mjs|evidence26live/nrz-build-frozen-entry.log|
| Official Function native runtime load |PASS; functionsLoaded1; runtime release runtime-5bf016e0885b4b70c77b9c12ce84c528aa80b531|evidence26live/functions-check.log|
| Workspace/user/project/SQL API |LIVE200; HOBBY/OWNER, one target project/one SQL|evidence26live/LIVE_CONTROL_PLANE.json|
| SQL create timeout |READ_ONLY_RECONCILED; one DB, no repeat POST|same|
| SQL start/idle-stop/safe-stop readback |LIVE running then stopped; SQL-only observation|same|
| Direct/pooled managed SQL smoke |BLOCKED ECONNREFUSED; checksExecuted=[]; no migrations executed|same|
| Billing one logical metadata refresh |LIVE200;1GET workspace, metadata only|evidence26live/LIVE_BILLING_METADATA.json|
| Cloud app HTTPS/deploy/Function invocation/KV ordering |NOT_RUN; fail-closed safety gate|ISSUES.md|
| Phone RF/foreign, real Google/Android |NOT_RUN; outside26 stage|NEXT_STAGE.md|

PGlite tests verify actual PostgreSQL-engine constraints/close-reopen/atomic claims on synthetic local data. Это не доказательство live managed SQL. Общий тестовый skip связан с явным opt-in CLI, который отдельно запущен и PASS. Предварительные/повторные тесты не суммируются как новые. Raw failed CLI diagnostics сохранены до исправления; nativeSQL данные только санитизированный readback, не вымышленный query PASS.

---

## Исторический снимок до разрешённого live-доступа (не текущий статус)

# Приоритетная запись26-А

Новые адресные результаты — TESTS_26A.md:16PASS, плюс3повторных budget enum checks. Обследованы official CLI/schema/public HTTP; authenticated billing0requests/NRZ_TOKEN_MISSING. Старые36/32не повторялись и ниже сохранены как исторический snapshot, не текущий новый прогон. Financial gate теперь26-А, no Usage API не стоп-фактор сам по себе.

---

# Проверки №26

LOCAL, 25.11.2026, Node24.19.0. Точные timestamps/SHA/summary каждого запуска — TEST_RUNS.json; исходные логи в logs. Матрица всех18 критериев — ACCEPTANCE.csv/ACCEPTANCE.md. Уровни LOCAL/LIVE/OWNER разделены.

## Фактические успешные проверки

- `npm test`: финальный полный прогон36 PASS/0FAIL/0SKIP после добавления resource reconciliation. Итого36 уникальных новых тестов. `task26-final-small.log` содержит повтор2 build +2 resource; не4 новых сверх36.
- `node --test server/alchemist/test/{snapshot20,runtime21,task22-core,task22-runtime}.test.mjs`:32 PASS/0FAIL; реальные старые Node/SQLite фикстуры, не production.
- PGlite0.6.0 — локальный PostgreSQL WASM engine: DDL, реальная transaction atomicity, uniqueness, immutable trigger, FK, rollback, restart persistence. pg8.23.1 production adapter не проверен по TCP на managed ONREZA; это остаётся live gate.
- Валидная/поддельная/истёкшая/wrong issuer/aud/scope сессия, wrong installation, CLIENT publish deny, forged role headers, роль/roleVersion из актуальной SQL, revoke со stale KV.
- KV miss существующей identity, запрет неразрешённого нового аккаунта, стабильные uid/installation, повтор requestId без второго session, отказ KV и TTL30s.
- HEAD/readback hash/dependencies, private scope/fields reject, immutable snapshot, идентичная пересборка без смены HEAD; неподтверждённый ratings adapter закрыт.
- SQL failure head→outbox, lost commit response, KV down, lost SQL ack после KVwrite, retries, устаревшие события, rebuild без purge чужих namespaces. Порядок на fake с version fence; no-CAS ONREZA adapter →STOP, не фальшивый PASS.
- Self-contained Function-entry проверен под Node/Web APIs с fake ctx/ports, good auth/HEAD без SQL calls, privileged=false, реальный adapter HEAD закрыт. `nrz functions check` НЕ выполнен.
- Curated build дважды побайтово совпал; упакованный Compute реально отвечает локально health200,404,405; секреты/стек/заголовки клиента в response не возвращаются. Это HTTP loopback, не HTTPS endpoint ONREZA.
- TOML разобран стандартным Python tomllib,2rules. Это синтаксис TOML, не provider acceptance правил.
- Один anonymous provider API GET401 с timestamp в NETWORK.json; docs200. Не обход авторизации.

## Неуспешные/уточняющие запуски и экономия

Первый прогон остановлен: test harness использовал PGlite prepared query для multi-command DDL (11FAIL/1cancelled). После одной диагностики adapter harness переключён на simple SQL exec; отдельный migration тест PASS, затем25PASS. Это ошибка тестового harness, не evidence потери пользовательских данных. Три последующих boundary RED (3FAIL) и уточнённый отдельный ordering RED(1FAIL) воспроизвели реально исправленные ошибки; далее31PASS, ack-target1PASS, промежуточный34PASS и финальный36PASS после добавления resource-reconciliation. Новые budget/build/resource проверки включались по мере добавления кода. Одинаковые неизвестные infrastructure-сбои не повторялись вслепую.

CLI/managed SQL/GitHub native build/Android/Google/Function sleep/расход live не имитировались. Flutter, APK, Gradle и эмулятор не запускались: Android явно вне №26. Запуски Actions с секретами не создавались. Величины пользовательской квоты Codex неизвестны и не вычислялись.
