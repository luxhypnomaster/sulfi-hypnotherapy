# Текущий результат

69PASS/0FAIL/0SKIP в финальном кодовом suite. Авторизация существующим токеном работает; настоящий Hobby STAGING развёрнут с отдельным owner exception. Один logical workspace metadata refresh всё ещё не даёт денежных сумм; quota/charges/reconciliation/panel не выдумываются. Admin preflight workspace reads не являются пользовательским BillingAdapter polling. Подробные LIVE результаты и ограничения: TESTS.md, KV_ORDERING_NATIVE_26A.md, evidence26approved/.

---

## Предыдущий checkpoint — история, не текущий статус

# Актуальный финальный прогон

65PASS/0FAIL/0SKIP с opt-in официальным CLI,47778.984681ms. Это последнийобщий runtime26suite; прошлые 59PASS и 28 адресных—история,неприбавлять. Новыетестытаргета/реальноймодели SQLowner и evidence в evidence26staging/. Полный scope/границысм.TESTS.md.


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

# Проверки26-А — LOCAL / CONTROLLED / PUBLIC SOURCE, без authenticated live

Команда: `node --test test/billing26a.test.mjs test/budget.test.mjs test/build.test.mjs` в server/alchemist/onreza26.
Финальный адресный результат: **16PASS/0FAIL/0SKIP**,511.23ms из evidence26a/targeted-tests-final.log. Дополнительный targeted `test/budget.test.mjs` после приведения plan к HOBBY:3PASS/0FAIL; это повторы, не19уникальных тестов. Старые36STAGING и32Node regressions не запускались, исторические логи сохранены.

Покрытие: отсутствиеAPI/поля/кредита не0; metadata не выдумывает period start/timezone; partial fork не workspace balance; quantity и monetary strings сохраняют precision; privateIDs исключены; derived remainder только при совпадающих авторитетных component/scope/period/as-of/currency/unit; incompatible/Number/negative inconsistent inputs fail closed; server authorization доcache; cache coalescing/manual throttling; STALE/denied no old financial data; missing secret0HTTP; GET-only path order; mismatch/403/network различаются; новый экономический gate и воспроизводимый curated build. BillingCache остаётся предложением с injected existing IAM, не production authorization.

Precision RED evidence26a/precision-red.log: Number amount некорректно принимался в новом derive prototype. Исправлен typeof-string guard, затем тест PASS в16. Дополнительный enumHOBBY сценарий проверен адресно. Повторные полные SQL/PGlite/Auth/Android тесты без причины не запускались. Значения пользовательской Codex quota неизвестны и не вычислялись.

Фактически выполнено вне mocks:
- официальный CLI binary0.54.0 downloaded/checksum/version/help;
- public docs/OpenAPI/source чтение с SHA/точными ссылками;
- public app/pricing HTTP200, без owner session;
- реальный запуск operator probe →NRZ_TOKEN_MISSING,0requests.

Не выполнено: live billing/user/workspace readback, scopes используемого NRZ_TOKEN, фактические числа затрат/кредита, before/after small load, reconciliation delay, panel comparison, managed ONREZA/SQL/Function sleep, Google/Android. Отсутствие этих испытаний не обозначается PASS и не подменяется нормализованными fixture ответами. См. дополнительные4критерия ACCEPTANCE_26A.csv.
