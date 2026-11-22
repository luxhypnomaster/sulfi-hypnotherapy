# Server baseline/delta №22

Кодовая точка `a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde`; ветка `feat/task22-server-ratings-admin`, base PR52 `40b7c59e67921f456c3c5a4e943bd40f7232f336` → PR51 `a7c29a7b478b6c3b001d70d3158b4a65d57b3c50`. PR51/52 OPEN DRAFT, не merged. main `b88637a105b2182c7b836311ebb3de7ad037b08f` не менялся. Draft PR22: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/54.

Исторически действующий сервер — существующий GAS6, не новый Script. Read-only исходный baseline взят из проверенных reports/task21/G0_AUDIT_21,OWNER_CHANGE_GATES_21 и сохранённых №16/17 readbacks. Это **не свежий административный readback deployment/version/source в №22**. Последний известный CI44959026009 не выделил runner (billing0steps); заново не запускался вслепую. deployment-readiness.json — историческая запись, не live-health доказательство.

Current→target delta: production Router/23-module GAS source остаётся прежним; candidate Node24 runtime21/22 реализует atomic SQLite storage, negotiated metadata/ratings/jobs. Script GAS/Drive нельзя объявить SQL-транзакцией, поэтому произвольного переноса Node модулей в live нет. src/OAuth/ACL/подпись/main не изменены относительно PR52 (SOURCE_PURITY).

## Backup/restore
Candidate backup: одна pinned read transaction экспортирует schema/tables всех namespaces, identity/roles/grants/catalog/diary/revisions/assets/index/config и текущие+исторические медиа с hash. Missing asset/hash mismatch — fail closed. AES256-GCM, ключ только внешний Buffer, не config/APK/лог/архив. Private destination interface требует independent proof; upload/hash/decrypt НЕ restore proof. restoreVerifier возвращает фактически восстановленные database/files/manifest. Новая директория0700/файлы0600, существующая не перезаписывается.

Actual complete candidate restore подтверждён Node test (logs/node-full-final). Production Google Drive tree/все immutable assets/ScriptProperties/secrets/ключи/atomic pointer adapter **не экспортированы**. Текущая папка For_Codex наследует anyone:writer; это НЕ место закрытого backup. В неё загружаются только очищенные отчёты. ACL не менялся.

## STOP перед live
1. Exact existing Script/deployment/version/полный исходный readback и current grants; не полагаться на repo HEAD или старые отчёты.
2. Полный scoped backup реального хранилища, закрытый destination, независимый hash/readback и isolated restore всех DB/media/identity.
3. Реализация/доказательство выбранного production adapter CAS+immutable snapshot+receipt+ACL; compatibility со старым GAS6.
4. Узкий reviewable additive diff, проверенный rollback исходников И deployment/heads без затирания concurrent изменений. Отдельные разрешения, если требуются для identity/ACL/deploy.
5. Staged capability opt-in двух verified accounts; затем решение о включении. В №22 ничего этого не применено.

Откат кандидата: оставить SULFI_PROJECT22/metadata feature OFF; не удалять derived namespaces, raw feedback, personal tables или файлы. В isolated SQL policy rollback переключает прошлую policy через новый verified ratings head на текущих consented reviews, не resurrects отозванные отзывы. Боевой сервер не менялся — production rollback не запускался.

Ограничения portable prototype: Buffer/base64 экспорт не доказан для больших production видео; нужен streaming adapter/лимиты до live, без выдуманных квот. Это не лицензия на публичную или разрушительную миграцию.

## Свежие безопасные read-only наблюдения

22.11 GET health существующего endpoint из подтверждённого ADMIN_READBACK_17:200/JSON, «Сервер Проекта Алхимик»,schema1,authorizationPolicyVersion2,self-reported sourceSha1a0cf8e5a60144075eec793767953586bfa319a2. GET не вызывал bootstrap/POST/публикации/storage writes. Это не чтение deployed immutable version/source через admin API; numeric version6 остаётся историческим admin readback, не новым доказательством.

Drive metadata того же Script:shared=true, listed permissions только user/owner. Эти данные недостаточны для доказательства приватности; они также не доказывают публичный доступ к исходникам. Никакие права не менялись. Private storage root ACL и full restore не подтверждены. См.SCRIPT_METADATA_READBACK_22.json. Все live-write гейты остаются закрыты.

Remote main b88637a подтверждена GitHub API. Local main более старая dcec7ed4f8562c8c394918faa68bcea8b468ee43, не переписывалась. Primary ZIP повторно raw-downloaded: тот же наблюдаемый SHA; это consistency readback, не owner-pinned checksum.
