# Обязательный target gate перед продолжением

Сначала OWNER_DECISION_STAGING_26A.md: customSTAGING недоступен Hobby(требует Pro),registry только Production. Официальный dryexplicitstaging вернул ENVIRONMENT_NOT_FOUND. До отдельного разрешенияна defaultProductionslot**вданномновомизолированном project** невызывать deploy без selector/--prod инеугадыватьальтернативные POST. Не upgrade.

Reconciler теперьпонимает standaloneSQLownerProduct,нобазаещёНЕподключенак Service/runtime. Сохранённые project/service/sql/ownerIDs в owner-only паспорт; no duplicates. SQLstopped подтверждена 18:28. Неиспользовать genericDATABASE_URL для startup миграции.


---

## Предыдущий checkpoint, сохранён для истории

# Продолжение после подтверждённого live-доступа

1. Использовать существующий private паспорт owner-only, не брать IDs из общедоступной папки отчётов. Один task26 API Product + один автоматически созданный SQL-owner Product/однаSQL; ничего не удалять/переименовывать/создавать заново. Final SQL stopped15:23UTC.
2. Authorize management token только в защищённом процессе, без echo/argv/файлов/логов. Разрешение на существующий токен действует; новые токены/ротация не требуются. Не запускать CLI --help с токеном в env: help может показать env default.
3. Official CLI0.54.0: `nrz build <project-root> --json`, root содержитonreza.toml сentry onreza26/compute.mjs. Не передаватьdist какroot. `nrz functions check <minimal-one-function-dir> --json` проверяет локальный provider runtime, не cloud deploy. Local regression opt-inP22_NRZ_BIN.
4. Управление SQL start/stop — документированный POST БЕЗ JSON body. Empty{} получает400. Timeout create не повторять: GET inventory/reconcile existing IDs. ПередSQL probe фактически дождатьсяrunning, после bounded trial stop и readback stopped. Не weakeningTLS.
5. Сейчас direct/pooled TCP отказалиприrunning; CLI query тоже локальныйTCP. Следующий диагноз только с новой гипотезой (иной разрешённый маршрут/поддерживаемый native binding), не повторять identical probes. Managed migrations ещё не выполнялись.
6. Не начинать remote HEAD/publisher, пока нет доказательства ordering. Не выдавать Function localcheck заKV/ACL/HTTPS success. У нового проекта default environmentProduction; отдельное named staging не создано. При согласованном будущем deploy сохранять IDs/revision и observed serving readback. Существующиеproduction/GAS6/OAuth не трогать.
7. Billing auto толькоentry/24h, lastAttempt/successdurable; manualrate-limited.1GETworkspace/refresh. ДенежныйAPI absencewarning, не самостоятельныйstop. Сверку с панелью/reconciliation не придумывать.

На этом продолжении remote deploy/redeploy/rollback не выполнялись. Следовательно нет servingrevision, которую можно безопасно назвать проверенной rollback-точкой. План ниже — историческая подготовка, не действующийrollback run.

---

## Исторический снимок до разрешённого live-доступа (не текущий статус)

# Приоритетное изменение26-А

Официальное дополнение26-А заменяет прежнее требование доказанного10₽ cap: это advisory target, не гарантия. Финансовые gates — подтверждённый Hobby/no-paid terms, минимальные разрешённые ресурсы, bounded workload и safe after-test. Отсутствие Usage API само по себе не блокирует trial. CLI0.54.0 теперь доступен в task tmpfs и checksum/help проверены. Auth NRZ_TOKEN остаётся BLOCKED_AUTH. workspace list — local config; для live workspace/plan нужен документированный GET /v1/workspace, а whoami получает /v1/user. Help с подключённым секретом выполнять только в дочернем процессе без NRZ_TOKEN. Последовательность и точные маршруты BILLING_RESEARCH.md / operator probe. Прежний текст ниже — исходный runbook до26-А; условия10₽/обязательного billing API и отсутствия CLI в нём переопределены этим абзацем. Остальные security/ordering/deploy gates сохранены.

---

# Продолжение №26 — безопасный runbook (LIVE НЕ ВЫПОЛНЕН)

## 0. Восстановить точку

Ветка feat/task26-onreza-staging, точный code SHA — DELIVERY.json. Не создавать новый номер или конкурирующий backend. №25 не трогать. Local root=/server/alchemist/onreza26; package lock фиксирован, Node24.19.0; старт `node compute.mjs`, PORT от среды, bind0.0.0.0. Секреты только по именам из environment.example. NRZ_TOKEN не передаётся в приложение.

## 1. Read-only gate

`node preflight.mjs` выводит только tokenPresent/cliAvailable. При false —STOP live и ISSUES. Из подтверждённого официального CLI release проверить `--version`, `--help`; не использовать install script без сверки релиза. Документированные read-only команды: `nrz whoami --json`, `nrz workspace list --json`, `nrz projects list --json`, после точного workspace выбора `nrz projects info <observed-id> --json`, `nrz services list --project-id <observed-id> --json`, `nrz db list --json`, `nrz deployments --project-id <observed-id> --json`. Не передавать токен через argv или URL. Сохранить readback только закрыто, stdout/stderr CLI не публиковать целиком. Проверить текущую CLI help: unsupported flag —STOP, не угадывать команды.

Сверить workspace ID (не только отображаемое имя), Hobby, billing.read, текущий кредит, фактические ставки расчётного периода и existing resources. У публичной документации есть новая и прежняя billing model; не применять новую ставку автоматически к существующему workspace. Точный read API тарифов пока не установлен, не выдумывать endpoint. Если CLI не даёт достаточный readback, запросить безопасную информацию панели владельца.

## 2. План ресурсов и цены

Найти protocol22-staging; при совпадениях>1 STOP. Сохранённый ID не найден →STOP, не создавать замену. Compute — Service protocol22-api внутри того же Project, Postgres — одна managed DB с явным STAGING binding; Functions — members active environment release, не отдельный POST create-function API. KV — environment binding плюс `synthetic26:<approved-instance>:` prefix. Нет отдельного публичного KV HTTP API/Compute SDK.

`core/resources.mjs` только сверяет inventory и persisted IDs; никогда не создаёт ресурсы. Недостаток SQL quota →STOP. Выполнить budgetGate с подтверждёнными timestamp/ставками, учётом хранения после теста, предельным временем работы и остановкой обоих Compute/SQL. Если лимит10₽ нельзя доказать, ресурсы НЕ создавать. Не включать оплату/подписку/карту, не менять workspace participants/ACL.

## 3. Код/контекст/предпроверки

`npm ci --ignore-scripts`, `npm test`, `npm run build` локально. Передать только whitelist dist, не весь Flutter checkout. Production deps из lockfile с omit=dev. Проверить исходный commit и build receipt verifierSHA. `.onreza/manifest.json` v2, exact dependency verifier и rules входят в bundle. Подтвердить фактический Node runtime у провайдера; Node/SQLite store22 не переносить под видом pg.

В подтверждённом CLI перед публикацией: `nrz functions check <curated-path>`; documented deploy preflight `--dry` проверить в installed help. Если CLI отвергает manifest/entry/rules —STOP и локальное исправление; не skip-validation/skip-env-check. Onreza Function self-contained, никакого npm bundle в Function. Включать pipeline только с before-cache/failure=closed; ни одно правило не заменяет SQL ACL прямого Compute. Перед deploy всего runtime нужно снять ORDERING_NOT_PROVEN доказанным provider contract/реализацией и тестами, не переключателем.

## 4. Первый deploy, explicit migration

Только после всех гейтов —найти/создать ровно одни ресурсы, IDs сразу сохранить в **закрытом** паспорте. Не включать auto-deploy main. Явно задавать project/service/environment/source commit. Официальная форма: `nrz deploy <curated-path> --project-id <observed-project> --service-id <observed-service> --environment <observed-staging>`; значения только из readback. Это шаблон после review, сейчас НЕ выполнен. Ни `--prod`, ни default branch main.

Только выделенная синтетическая DB и schema p22_stage26; миграция001 явным операторским действием после проверки connection target. Не выполнять миграции при старте процесса. Synthetic identity/session/projection signing keys раздельные, генерировать в защищённом runtime; не сохранять реальные values в Git/логи/Drive. Новый пользователь только после подписанного synthetic identity proof, не client ID.

## 5. Малые live проверки и экономичный остаток

HTTPS health200/404/405, авторизация негатив/позитив, existing/new miss, роль/отзыв, private scopes, outbox commit/write/ack gaps, no regression, одна и та же revision при identical rebuild. Затем повторить deploy **в те же IDs**, прочитать release/revision, проверить что нет duplicates.

Function-only auth/HEAD: сначала подтвердить Compute+SQL suspended наблюдением состояния/метрики, потом несколько малых запросов без keep-alive; снова наблюдать state и Usage с timestamps. Латентность сама по себе сон не доказывает. Записать cold/warm, BFU, SQL/Compute deltas, задержку reconciliation. Неполный billing →PENDING, не0. Телефон РФ/зарубежные точки owner pending отдельно. Если авто-сон не подтверждён, остановить новые Compute/SQL без удаления при поддержке, иначе заранее STOP до создания.

## 6. Rollback/update и сбой

До update сохранить code SHA, complete environment release ID, app revision, Functions revision map, rules revision, SQL migration hash и immutable snapshot hashes в закрытом паспорте. Не удалять SQL/outbox или ресурсы. Для тестового окружения официальный rollback: `nrz rollback --environment <staging> --release-id <previous-observed-release>`. После принятия операции читать documented `GET /v1/environments/<observed-id>/serving`: desired generation совпадает, activeEverywhere=true, observed.releaseId совпадает. Принятая заявка сама не rollback PASS.

Схема001 additive; откат приложения не запускает down migration и не удаляет данные. Если новое состояние не обратно совместимо —STOP и изолированное исправление. SOURCE остаётся на checkpoint branch; rollback serving не означает rewrite Git. При lost SQL commit response повторить requestId/receipt; pending outbox drain bounded после устранения KV сбоя. При no-CAS/потере доказательства порядка STOP publisher, оставить SQL и lastGood в пределах политики. Rebuild только данного synthetic prefix, не workspace purge. Никаких постоянных repair/schedule в №26.
