# №26-А — практическое исследование биллинга ONREZA

25.11.2026. Продолжение PR77 / feat/task26-onreza-staging с checkpoint e7ae471. Основание: https://docs.google.com/document/d/1GdcoDyErb579vKXzFWU3-HRjQMKeCWR1Zpax0IP3Cj0/edit . Android UI, production integration и платные действия не выполнялись.

## Вывод

**PARTIAL: документированный read API есть для части данных, полного подтверждённого workspace Usage/credit API пока не найдено в обследованных источниках. Это не доказательство, что такого API у ONREZA вообще нет.**

1. Официальный CLI0.54.0 реально скачан, проверен по release checksums и запущен локально. `--version`, общий/help workspace/fork/db/kv-v2 и `fork usage --help` доступны. Это сняло прежний локальный блокер CLI. NRZ_TOKEN всё ещё отсутствует; защищённых runtime secrets у среды нет. Авторизованных запросов к данным владельца: **0**.
2. Официальный опубликованный OpenAPI CLI содержит `GET /v1/workspace`: identity workspace, role, subscription.planSlug/status/currentPeriodEnd и другие subscription flags. Он **не содержит** поля размера кредита, использованного кредита, остатка, денежных начислений, invoices, прогноза, начала периода или его IANA timezone.
3. Найден официальный **`GET /v1/product-forks/{productId}/{forkId}/usage`**, CLI `nrz fork --product-id <observed-product> usage <observed-fork> --json`. Это **узкая область fork и его точных resources**, а не весь workspace, обычный постоянный staging или месячный баланс. Ответ предусмотрен только с coverage `PARTIAL` либо `UNAVAILABLE`; нельзя объявлять его полной сверкой.
4. **`nrz workspace list` читает локальную конфигурацию**, а не сервер. `nrz whoami` получает `/v1/user`, но workspace name берёт из локального config; сам по себе он не доказывает актуальный plan/credit/workspace. Для серверного readback нужен `/v1/workspace` и сверка ожидаемого закрытого ID.
5. Точные счета и остаток текущего workspace, scope имеющегося ключа, фактическая задержка reconciliation и сверка с панелью **BLOCKED_AUTH / NOT_RUN**. Не публикуются фиктивные суммы, нулевой расход или выдуманная скорость обновления.

Ни отсутствие Usage API, ни неизвестная сумма кредитного остатка сами по себе не блокируют остальные серверные испытания. По №26-А финансовые предусловия — подтверждённый Hobby/отсутствие платных обязательств, разрешённые минимальные ресурсы, ограниченная нагрузка и безопасный остаток состояния после теста. **10₽ — ориентир, не автоматически гарантированный cap.** Сейчас provisioning остановлен по отсутствию защищённого доступа и подтверждённых условий, а не потому, что не найден общий Usage API. Независимый KV ordering gate тоже сохраняется.

## Источники и фактические действия

- Дополнение26-А прочитано полностью и сохранено docs/task26/ADDENDUM_26A.md; основной ZIP и прежние доказательства сохранены.
- Свежий официальный https://docs.onreza.ru/llms-full.txt: HTTP200,809734B, SHA256 `5cfb9918037d26c439709d390c4f29ae878205d36760787766191f3959b83aa8`.
- ONREZA/nrz-cli v0.54.0, source commit `b1c31311170bc9834e1d9db7a8345dd4f044f9b3`; официальный tag/release, не сторонний SDK. linux archive SHA256 `e1b9e1a2390ee9a767fcdf35971d579b20a124b78c7302663350e2de0f9f1492`, checksum совпал. Это проверка release checksum, не заявление об отдельной криптографической аттестации бинарника.
- OpenAPI https://github.com/ONREZA/nrz-cli/blob/b1c31311170bc9834e1d9db7a8345dd4f044f9b3/api/openapi.json :81path, SHA256 `07e783e94863089ed1397fdd229f188f661573ed3bc390e1763fe122261135ee`. Это опубликованный contract CLI, не утверждение о полном перечне внутренних API платформы.
- Source workspace_handler.rs/auth/mod.rs/product_copy.rs и generated client изучены; GET/параметры сверены по schema, URL не угадывались. Не вызывались скрытые dashboard API и mutation endpoints.
- https://app.onreza.ru и https://onreza.ru/pricing реально вернули200 без авторизации. Открылась публичная оболочка/страница, **не кабинет владельца**. Тарифы публичного нового подключения не приняты за индивидуальные текущие ставки.
- Реальный безопасный запуск `research/billing_probe26a.mjs --run`: tokenPresent=false, status=BLOCKED_AUTH, requests=[], workspace=null, fork=null. Никаких поисков ключа в Drive/чате/config/Git и попыток device/login/OAuth.
- Схемы/CLI help/HTTP timestamps/проверки находятся в evidence26a. Контролируемые unit fixtures не обозначаются VERIFIED_LIVE. Help снимался при отсутствующем NRZ_TOKEN; если секрет позже подключён, help выполнять с удалённым из дочернего процесса NRZ_TOKEN (`env -u NRZ_TOKEN ... --help`), чтобы CLI не напечатал значение env в справке.

## Карта показателей

Компактная машинная карта — BILLING_CAPABILITIES_26A.csv. Для каждого поля разделены `source_status`, `live_status`, единицы/область/предпосылки и причины отрицательного результата. **DOCUMENTED ≠ VERIFIED_LIVE**; ни одного VERIFIED_LIVE финансового значения сейчас нет.

| Показатель | Документированный источник | Область и фактическая доступность |
|---|---|---|
| Plan/status подписки | GET /v1/workspace → subscription.planSlug/status | Workspace; DOCUMENTED / BLOCKED_AUTH; nullable subscription не равна Hobby по умолчанию |
| Конец периода | subscription.currentPeriodEnd, date-time/null | DOCUMENTED / BLOCKED_AUTH; null не превращается в конец месяца |
| Начало периода и timezone workspace | В workspace schema отсутствуют | NOT_DOCUMENTED; ISO offset конца периода не определяет IANA timezone или дату старта |
| Включённый/применённый/оставшийся credit | Usage UI и методика описаны, read endpoint в изученном contract не найден | NOT_DOCUMENTED программно; не0₽ и не исторические250₽ |
| Gross/used charges всего workspace | Usage UI/инвойс описаны | Общий read contract NOT_DOCUMENTED; fork total не замена |
| Прогноз | Подтверждённого API/алгоритма нет | UNAVAILABLE для текущего чтения; собственный прогноз только ESTIMATE при достаточном ряде |
| Invoices/подписка/профиль | billing.read документирован для профиля/счетов; metadata subscription есть отдельно | Наличие permission не доказывает конкретный invoices/Usage endpoint |
| Известные расходы fork | fork usage → knownGrossCostCents/currency | DOCUMENTED, только PARTIAL/UNAVAILABLE, сейчас BLOCKED_AUTH; не общий бюджет |
| Детализация Compute/SQL/Functions/build/storage/traffic | fork usage.items: resourceType/moduleKey/meterKey/quantity/unit/grossAmountCents | Generic контейнер DOCUMENTED; конкретные meter types/полнота покрытия не гарантированы schema, live не проверено |
| Объём KV v1 | Документация kv_storage_mb, защитный лимит, без line item | Не денежный расход; read usage endpoint не найден. Это не гарантия нулевой цены remote KV v2 |
| SQL capacity/status | CLI db info / опубликованный database GET schema | Operational CU/status ≠ начисления и не остаток кредитов. Полный raw response может содержать служебные поля — не отдавать в MASTER |
| Квоты и действующие ставки | Панель workspace / публичная pricing для новых подключений | Нормативные units известны; фактические значения/сбросы/спецусловия BLOCKED_AUTH либо NOT_DOCUMENTED программно |

### Единицы, точность и методика

Fork API возвращает quantity и денежные *Cents как **строки**; не переводить их через float/Number. Currency может быть null. Контракт не фиксирует универсальный currency exponent: сохранить provider-cent-string до проверки валюты/семантики, не называть cents долларами. Крупные значения сохраняются без округления. Schema задаёт тип string без numeric pattern; prototype принимает целую строку Cents и отклоняет несовместимый формат, пока его семантика не подтверждена. В расчёте кредита Number входы прямо запрещены (отдельный RED→GREEN тест), чтобы не принять уже округлённую сумму. План/технические CU показывать отдельно от денег.

Актуальные docs различают действующую для периода модель и новые условия, опубликованные08.11.2026: Compute CU-seconds→CU-hours, Functions BFU-seconds→BFU-hours, storage byte-seconds→GiB×30days, Traffic IN/OUT отдельно, build CU-hours. Исторические страницы содержат whole-hour blocks/build_minutes/старый network BFU и GB-month. Не суммировать старую сетевую составляющую с новым Traffic и не переводить существующий workspace на новые ставки по одной дате публикации.

В invoice diagnostics документированы quantities/grossUsage/includedUsageCreditApplied/extraUsage/limits; это описание состава инвойса, **не найденный HTTP endpoint**. При сверке приоритет: применимые договорные условия → выставленный invoice конкретного периода → применимые pricing/limits → методика. Promo/adjustments не смешиваются автоматически с included credit.

## Воспроизводимая последовательность после подключения секрета

1. Bool presence и pinned CLI version; ожидаемый workspace ID поступает из защищённого паспорта, не по названию. NRZ_TOKEN не в argv/URL, только разрешённый secret runtime. Текущий script не ищет локальные credential/config файлы.
2. Сначала **GET https://api.onreza.ru/v1/workspace**. Сверить id с ожидаемым внутри backend; в shared evidence оставить только совпадение, plan и допустимые metadata, без raw ID. При mismatch STOP. API auth варианты: workspace API key Bearer/X-API-Key; session cookie тоже объявлена schema, но browser cookies не извлекать.
3. После совпадения workspace **GET /v1/user** для identity. Эти GET по данным независимы, но исследовательский script сериализует их, чтобы прекратить работу при неверном workspace. Полные whoami email/name и token scopes в отчёт не копировать. Точный набор atomic permissions для этих route не объявлен в OpenAPI; token scope остаётся UNVERIFIED до readback. billing.read не даёт права предположить расходные поля.
4. Для workspace metadata project ID/period ID не нужны. Для обнаружения проекта есть GET `/v1/projects/` с query `limit/offset/name`; это не Usage pagination. Не загружать всю историю без необходимости. У fork usage path обязательны productId+forkId; query периода/pagination не объявлены, поля ответа period могут быть null. Нельзя подставлять staging project ID вместо fork ID.
5. Только если существующий разрешённый fork уже указан закрытым паспортом: проверить GET `/v1/projects/{id}`, затем GET `/v1/product-forks/{productId}/{forkId}/usage`. Ни создание новой копии, ни изменение её retention ради биллинга не разрешены. У обычного постоянного staging этого fork может вообще не быть: тогда NOT_APPLICABLE, не provisioning fork ради цифр.
6. Подготовлен operator-only `node research/billing_probe26a.mjs --run`. Требует NRZ_TOKEN и P22_ONREZA_WORKSPACE_ID. Optional P22_ONREZA_PRODUCT_ID/P22_ONREZA_FORK_ID — только наблюдаемые IDs. Максимум4GET на запуск, без retries, redirect:error, timeout10s, ограничение опубликованного ответа; raw credentials/IDs не печатаются. Без токена —0HTTP. Это не mounted API приложения.
7. 401 →BLOCKED_AUTH;403 →permission denied, без повышения scope/эскалации;404 опубликованного route →UNAVAILABLE/неподтверждённое соответствие, не вывод «API не существует»; network/5xx →UNAVAILABLE, не0. Отсутствие поля и отсутствие документации — разные причины. Repeated failure без новой гипотезы не повторять.

Чтение project/workspace/fork data не зависит от SQL/Compute нашего staging и не должно создавать ресурсы. Docs API keys сообщают5000requests/hour/key и429; это **DOCUMENTED**, не измеренный лимит этого ключа или гарантия полей quota/reset headers.

## Актуальность, reconciliation и панель

Документация говорит об агрегационной задержке Usage без численного SLA; для финансовой сверки рекомендует закрытый период. Fork schema имеет freshness:string и lastReconciledAt:string|null; допустимые значения freshness, их точный смысл и гарантированная частота **не описаны**. lastReconciledAt не переименовывается молча в measuredAt; fetchedAt — момент нашего получения, не измерения.

Фактическая baseline/after-load пара, наблюдаемая задержка и panel comparison: **NOT_RUN / BLOCKED_AUTH**, не PENDING измеренного расхода. Никакой дополнительной нагрузки для искусственного появления суммы не создавалось. Процесс на будущее: read baseline →один уже разрешённый малый серверный сценарий →read after →максимум ещё одна сверка в согласованном окне, если record ещё не reconciled, записать PENDING и завершить; не polling/keep-alive. Время ожидания — локальная политика, не SLA. Проверку на панели выполняет владелец при возможности.

Официальная панель https://app.onreza.ru →нужный workspace →Billing Information/Usage/Invoices. Прямая deep-link конкретного кабинета не наблюдалась и не выдумывается. Публичная pricing-страница не заменяет эту сверку.

## BillingAdapter для MASTER: предложение и проверяемый прототип

Контракт описан в BILLING_ADAPTER_PROPOSAL_26A.md; переносимый прототип core/billing26a.mjs **не подключён** ни к production, ни к UI MASTER. Для каждого поля: capability.discovery/supportedDirect/verifiedLive, source, scope, value, currency/unit, periodStart/End/timeZone, measuredAt/reconciledAt/fetchedAt, ACTUAL/ESTIMATE/STALE/UNAVAILABLE/PENDING, reason, derived/formula. Недоступно ≠0; all-null credit честнее ложного остатка. Данные fork неизменно помечены partial scope.

Server IAM проверяется до cache read/refresh, CLIENT/чужой workspace не получают финансы. Административные ключи не попадают в APK; backend использует только защищённый NRZ_TOKEN минимально подтверждённых permissions. Proposed event-driven cacheTTL5min, ручной refresh с coalescing и min30s (настраиваемые инженерные значения, не сведения ONREZA). Никаких фоновых таймеров/polling. Provider failure отдаёт старое как STALE;401/403 скрывает прежние финансовые данные.

Остаток можно вычислить только из **трёх совместимых авторитетных компонент** одного scope/period/as-of/currency/unit: periodGrant + grantSpecificAdjustments − appliedIncludedCredit. Gross charges не подставляются вместо appliedIncludedCredit; invoice adjustments и промо не подмешиваются без явной ledger семантики. Нет одной компоненты/смешаны периоды/отрицательный невозможный итог →UNAVAILABLE/PENDING. Расчёт отмечен derived с формулой. Сейчас компонентов нет, фактический остаток не вычисляется.

16 адресных tests PASS: precision, no fake zero, no private IDs, scope separation, derive guards, IAM-before-cache, stale/denied, coalescing, zero-HTTP missing secret, safe read-only sequence/mismatch/network, новые финансовые условия и reproducible curated build. Все mock responses — CONTROLLED, не LIVE. Старый36/32 прогон не повторялся.

## Приёмка

T26-19 PARTIAL; T26-20 PARTIAL; T26-21 BLOCKED; T26-22 PASS LOCAL (контракт/предложения/тесты, без UI и production). Детали в ACCEPTANCE_26A.csv и общей22-строчной ACCEPTANCE. Следующий независимый шаг — предоставить защищённый runtime доступ и подтвердить Hobby/условия; не требуется платный тариф или поиск недокументированных маршрутов.
