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
