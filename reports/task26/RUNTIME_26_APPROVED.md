# Окончательный readback разрешённого продолжения

25.11.2026 19:34UTC: повторный deploy, откат официальным CLI и возврат завершены. Наблюдается второй Git deployment, FINISHED/SUCCEEDED/activeEverywhere=true. Проверены health200 и закрытая диагностика 403. SQL observed/desiredstopped. Один Service,3deploymentrecords (незавершённая исходная CLI +2Git); откат не создавал новый build. Новые composition IDs после активации отличаются от исходных retainedrelease IDs — проверены фактически обслуживающие deployment/member.

Итоговая матрица 22:8PASS/14PARTIAL. Все 69 кодовых testsPASS. Native SQL из ONREZA PASS, KVolder-overwrite доказан. HEAD/publisher закрыты; live authority/migrations/auth/outbox/HEAD и глобальный Compute sleep не объявляютсяпройденными. Plain-fileSHA256 и provider snapshotHash — неподтверждённые разные домены; независимой byte-integrity проверки нет.

19:35UTC GETworkspace снова подтвердил HOBBY/ACTIVE/тотже periodEnd. Денежныеполя не предоставлены; стоимость/остаток/reconciliation неизвестны. Токеновыйпроцесс закрыт; секреты не вошли в Git/ZIP/отчёты. Private паспорт обновляется отдельно, owner-only.

---

# Разрешённый логический STAGING на Hobby

Постоянный отдельный проект protocol22-staging, тот же единственный Service. Стандартный slot Production используется по узкому разрешению владельца. Он не является действующим GAS6 и не подключён к APK. Точные IDs/URL/releases — в отдельном owner-only паспорте, не в этой папке с наследуемым доступом.

## Источники и доставка

Проверенный код:1ad664552af20ec06e2e077f2aea051e243165e4,69NodePASS. Curated source: deploy/task26-hobby-context, commit eb7056dab8f104402e28dd6972d15c8629766ba2.27файлов,70764B до SOURCE_PIN.json, безAndroid/секретов/личных данных. Корректность локального build и обеихFunctions/3EdgeRules проверенаCLI0.54.0. Production dependencies установлены изlockfile безdev/scripts; Node24.19.0 запрошен вconfig.

Первый SourceV2 CLI deploy: packaging30ms/admission200ms успешны; transfer_and_publication deadline23711ms. Официальныйpublisher использует direct Iroh/QUIC, relay disabled. Точная низкоуровневая причина не установлена. Операция не была слепо повторена; source Git build на стороне ONREZA принят и перешёлLIVE. Старая CLI запись не удалена.

## Контур и безопасность

PostgreSQL0.25CU/suspend60s подключена по exactService/ProductEnvironment/ownerProductEnvironment/providerBranch к Functions. Auto-inject DB URI=false; backendadminNRZ не передаётся приложению. Compute250millicores/idle60s. Functions protocol22-light и protocol22-native-probe, namespace synthetic26:task26:. Public registration/publish и неподтверждённый HEAD выключены.

Диагностическая capability случайная, только в памяти; ONREZA хранитSHA256 какsecret. Время≤1200s, byte cap512, auth доSQL/KV. ФиксированныйSELECT1 безSQLwrites; KV толькоunique synthetic key/counter сTTL60 иcleanup. modeoff проверен403 со старой capability. Rollback восстанавливает snapshot config и может вернуть временное окно, поэтому независимый expiry и повторная проверка после возврата обязательны.

## Фактические измерения

|Проверка|Результат|
|---|---|
|health GET|200,2430ms; не называем это доказанным cold start|
|health POST|405,938ms|
|unknown route|404,1067ms|
|native без capability|401,1081ms|
|SQL из активнойFunction|200,PASS_NATIVE_SQL_READ,4137ms,writes0|
|KV stale overwrite/counter|200,2631ms,2→1,counter1/2,cleanuptrue|
|modeoff доrollback|403,1566ms|
|rollback health|200,1359ms|
|старый snapshot окна послеrollback|422 на неизвестнуюфиксированнуюоперацию; SQL/KV не вызваны|

SQL stopped подтверждена до и послеKV, не выводится изlatency. Runtime logs показывают Function name дляnative paths. Global Compute sleep не наблюдён независимо. Финальный redeploy/rollback/restore и closure описаны по последнему readback в DELIVERY_APPROVED_26A.json и NATIVE_PUBLIC_EVENTS.json.

## Provenance limitation

Observed Git commit совпал сcurated immutable commit. Provider sourceSha256 равенsourceSnapshot.sourceHash, но неSHA256 обычногоentry-файла. Snapshot canonicalization неизвестна; не выдаём сравнение разных доменов заPASS и не утверждаем подмену кода. Совпадают имена/entrypoints, snapshot fileCount1 и уникальное фактическое поведение; это ограниченный, а не полный byte-verifier. No mock bindings принимались заLIVE.
