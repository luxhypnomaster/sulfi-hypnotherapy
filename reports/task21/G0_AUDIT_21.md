# G0 — независимый preflight №21

BASE_SHA / PR51_HEAD_SHA a7c29a7b478b6c3b001d70d3158b4a65d57b3c50. Проверенный code №20 9e898024a51f23c602fe216784b0532e4bee90e4; после него только docs. PR51 open/draft/not merged, base feat/task19-auth-stage01. Цепочка PR48(506619a)→PR49(363a024)→PR50(dca8196)→PR51(a7c29a7) сохранена. Новая feat/task21-runtime-sandbox от актуального PR51; main b88637a не меняем.

Архив14177B SHA064b51f2fcf002a3718cb3fbc388817fa45e72d444c65df37d2ad4157d887fc7, CRC/8manifest hashes+sizes PASS; прочитаны все9файлов. Свежее содержимое6отчётов №20 и5SDD/IAM получено черезDrive, сравнивается с рабочим кодом. SOURCE_READBACK и CHECKPOINT №20 сохранены в ancestry.

SERVER_IMPL: server/alchemist/src/Router.js понимает POST v1 с one-dot operation names, catalog.*→Catalog.js; готовых metadata.capabilities/catalog.head/catalog.snapshot/vitrine handlers в действующем коде нет. Только experimental/catalog_snapshot.cjs с injected store. AtomicStore/Drive+LockService нельзя считать SQL-транзакцией. Новый adapter остаётся sandbox; никакого Router/live подключения. GAS6 — существующий deployment по прежним отчётам, новый admin readback не выполнен (CI0steps), не выдаём историю за свежий live proof.

Gaps №20: nullable snapshotTransport не создаётся runtime/headless factory; cloud reader UI AlchemistStoreScreen продолжает catalog.list; настройки publish disabled без transport. configRevision лежит внутри catalog snapshot, поэтому нужен отдельный authoritative config stream, а не второй конфликтующий current. Preview editor.preview сохраняет draft и открывает reader; отдельного статичного Home preview нет.

Queue18: одна app_settings очередь AlchemistWorkQueue; Android headless uses SessionController.sendCloudTask. Metadata uses existing alchemist_download kind catalogSnapshot20. Требуется control priority только при выборе следующей задачи, без preemption активного файла. Native SQL scheduler unchanged.

Auth19: android/auth19 and lib/main_auth19 isolated OFF. Не менять Google auth/role definitions. Capability calls reuse existing verified identity boundary, bounded timeouts, без picker. Server sandbox principal resolves from private synthetic credential table/callback, не request roles/email. Новый S-D-IAM §8 governance остаётся product direction; назначение ролей и live grants не реализуем по №21.

PR46/16-В риск: физическая причина потери видимости старых пользовательских данных не была полностью доказана. Последующие no-delete storage bootstrap/SQLite safety и upgrade tests не равны восстановлению прежних данных. Schema9, media paths, template IDs, histories, read-state/outbox оставляем. Добавочные metadata namespaces тестируем на disposable fixtures с исходными аудио и старым состоянием; реальных баз/телефона нет.

Ограничения: Node24.19 node:sqlite доступен — можно доказать atomicity на настоящем локальном SQLite, не выдавая его за выбранный production provider или GAS SQL. Android SDK/Flutter есть, root137MB, cgroup8GiB, прежний Gradle cache dangling и KVM не подтверждён. Native preflight G4 отдельный; не повторять известный OOM/CI billing.

Расхождение вводного описания21: actual ACCEPTANCE_20 row022 BLOCKED_OWNER для live GAS, не исключительно CI billing; остальные native/CI ограничения отмечены отдельно. №20 остаётся PARTIAL, не FULL PASS.
