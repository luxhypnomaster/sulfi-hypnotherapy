# Изменения текущего продолжения

- Применено обновлённое разрешение26-А и rolling24h правило; первоначальные входные файлы26 сохранены как исторический baseline.
- BillingCache требует явный store; durable PostgreSQL adapter и additive002_billing_cache.sql. lastAttempt до upstream, lastSuccess только после success; атомарная lease и fencing completion, отдельные LastGood по period, suppression после failure/restart/manual,401/403 hide,429 Retry-After, bounded timeout, no polling/UI.
- Добавлены12 policy/PGlite регрессий, официальный opt-in CLI/Function runtime test и безопасный native SQL smoke (URI только env, strict TLS, sanitization). Smoke не выполнил SQL из-за TCP refusal.
- onreza.toml фиксирует конкретный frozen Compute entry. Исправлена доказанная несовместимость infer-entry в CLI build.
- Разрешённое provisioning минимальных постоянных ресурсов, timeout reconciliation без duplicate POST, прямой/pooled диагноз и safe stop; private паспорт сохранён отдельно.
- Только docs/task26, reports/task26, server/alchemist/onreza26. Нет изменений №25, приложений, live GAS, main, signing или ACL.

---

## Исторический снимок до разрешённого live-доступа (не текущий статус)

# Изменения26-А

Продолжение существующей ветки feat/task26-onreza-staging / Draft PR77, от e7ae471501b353807b0fac209f86e9fa60f6481d. Ни нового основного задания/ветки/сервера, ни merge/deploy. Точный новый code SHA — DELIVERY_26A.json после checkpoint.

- Прочитано/сохранено официальное ADDENDUM_26A, обследованы актуальные docs и официальный CLI0.54.0 (release SHA проверен), OpenAPI и CLI source pinned commit b1c31311170bc9834e1d9db7a8345dd4f044f9b3.
- BILLING_RESEARCH,23-строчная карта source/live availability, proposal BillingAdapter и дополнительные T26-19…22; общие ACCEPTANCE/RESULT/ISSUES обновлены с сохранённой историей.
- Новый core/billing26a.mjs: capability flags, precision-safe normalization, честное отсутствие данных, guard-derived remaining credit, серверный cache/ACL/coalescing/stale. Не mounted в Compute/P22 или UI, не реальная ONREZA интеграция.
- Новый operator-only research/billing_probe26a.mjs: только официальные GET, проверка точного workspace, без ресурсообразующих действий/скрытых API/secret output. Без protected NRZ_TOKEN —0HTTP.
- Финансовый gate core/budget.mjs адресно изменён согласно26-А:10₽ advisory, no guaranteed cap; отсутствие Usage API/стоимостной оценки само не блокирует trial. Hobby/no-paid terms/authorization/minimal bounded workload/safe after-state остаются обязательными. Поддерживается официальный enum HOBBY.
-16адресных тестов PASS (включая2прежних build checks и изменённые3budget cases); отдельно3targeted budget проверки official enum. Старые36/32 не повторялись. Один precision regression RED→GREEN запрещает Number суммы до вычислений.

Все изменения ограничены docs/task26, reports/task26 и server/alchemist/onreza26. Нет Android, main, GAS6, production, OAuth/ACL/signing/№25 и billing subscription изменений. Не создавались ONREZA ресурсы и копии fork ради измерений. Ключ не искался в Drive/чате/config и не использовался незашифрованно. Нет raw owner identifiers/financial responses в shared evidence.

Кодовый SHA26-А: `b57726d8ce3af7138fb8f73257026f6d29c6bb27`. Следующие коммиты только доставка/отчёты.
