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
