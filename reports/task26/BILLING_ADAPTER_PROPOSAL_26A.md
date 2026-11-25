# BillingAdapter26-А: предложение контракта для будущего MASTER

Статус DESIGN + LOCAL PROTOTYPE. Не P22 wire migration, не Android UI, не подключение к production. Исходные S-D-ADM-001 REQ-022/TST-010 и provider dependency25.11 сохраняются.

## Порт

`readOverview(serverVerifiedPrincipal, serverOwnedWorkspaceBinding, requestedPeriod) -> BillingSnapshot`.
Авторизация — существующий IAM22/Auth19 server authority; не локальный режим MASTER/не role header. Backend allowlist решает, какие billing поля видны конкретному ADMIN/OWNER. Административный ключ хранится только в серверном protected runtime. Нельзя проксировать произвольный provider URL из APK.

Snapshot содержит schemaVersion, scope{workspace|project|fork|resource} без раскрытия закрытого provider ID, source{provider, officialContractVersion, authorityLevel}, selectedPeriod, fetchedAt и dictionary полей. У каждого поля:

- capability: discovery DOCUMENTED/VERIFIED_LIVE/BLOCKED_AUTH/NOT_DOCUMENTED/UNAVAILABLE/PENDING, supportedDirect, verifiedLive;
- value:null при отсутствии; status ACTUAL/ESTIMATE/STALE/UNAVAILABLE/PENDING; reason/error code;
- source+scope; money decimal-string либо integer minor-unit-string +currency/явный exponent, quantity decimal-string+unit;
- periodStart/End/timeZone, measuredAt/reconciledAt/fetchedAt независимо;
- coverage COMPLETE/PARTIAL/UNAVAILABLE; derived + formula при вычислении;
- цель freshnessPolicyVersion и maxAge отдельно от provider обновления.

`ACTUAL` не значит финансовую финальность invoice; это значение полученного авторитетного источника в указанных пределах. В тестовой фикстуре sourceType=CONTROLLED_FIXTURE, current live values не заявляются. PARTIAL fork никогда не заполняет workspace total/remaining. Server currency=null не превращается в RUB по расположению сервиса; неизвестная единица не переводится. Raw JSON provider, encrypted credentials/connection URIs и resource IDs не выдаются в MASTER.

Публичный prototype имеет normalizeWorkspace/normalizeForkUsage, unavailableBilling, deriveRemainingCredit и BillingCache. Полный backend transport/provider credentials намеренно остаются operator-only research script: production integration не разрешена. Capability flags workspace credit остаются NOT_DOCUMENTED; для plan/subscription/end DOCUMENTED, verifiedLive=false.

## Отображение без разработки UI сейчас

| Источник/состояние | Будущий вывод MASTER |
|---|---|
| VERIFIED provider metadata | «Hobby / активен», источник и время получения; дату обновления не придумывать |
| NOT_DOCUMENTED credit API | «Провайдер не отдаёт через подтверждённый API» +официальная панель |
| BLOCKED_AUTH/403 | «Нет доступа к данным провайдера», без Google-picker и без показа чужих/stale приватных финансов |
| PARTIAL fork amount | «Известные расходы копии — частичная детализация», не «Расход всего сервера» |
| Неизвестная freshness / незавершённая сверка | «Ожидается сверка», raw value при допустимой политике с явным PENDING |
| Offline с ранее допустимыми данными | «Устарело, получено…», STALE; не зелёный статус по умолчанию |
| Собственные счётчики/тарифный расчёт | «Оценка», отдельные единицы и версия расчёта, не фактический остаток |
| Отсутствующие N/сумма/period | «Нет данных», никогда не0₽/100% свободно |

Доступ к overview сам не должен будить SQL/Compute лишь ради частого provider polling. Event-driven cache, per-scope/per-period isolation, ручной refresh и coalescing; refresh не обходит ACL. ПредложенныеTTL5min/minRefresh30s конфигурируемы и не выдаются за лимиты ONREZA. Будущая page-секция остаётся частью прежних7 разделов MASTER, не новый экран/дизайн.

## Бюджетный gate

По дополнению26-А прежняя проверка обязательного численного10₽ cap заменена в core/budget.mjs. Неизвестный Usage API/estimate теперь warning; 10₽ — advisoryTarget, guaranteedCap=false. STOP сохраняется при непроверенном Hobby/оплате/workspace, отсутствии разрешения на ресурсы, неограниченной нагрузке или неподтверждённом безопасном состоянии после теста. Результат READY_FOR_CONTROLLED_TRIAL_REVIEW не создаёт ресурсы и не обещает финансовый cap. Проверка свежести административного readback5min — местная review policy, не provider SLA. Можно подтвердить тариф/условия допустимым owner readback панели, не только Usage API.
