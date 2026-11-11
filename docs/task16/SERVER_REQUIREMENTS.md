# Полный GAS backend, не минимальный mock

## Архитектура и среда

- `server/google_apps_script` (V8): `Code` routes `doGet/doPost`; `Auth`, `Registry`, `DriveRepository`, `PublicationService`, `PackageService`, `MediaTransferService`, `Audit`, `Migration`, `ErrorEnvelope`. Использовать локальный тестируемый pure JS core + GAS bindings, без Node globals в GAS. Repo исходники должны импортироваться в GAS целиком.
- Drive private root — один реальный у владельца **под существующей папкой `Проект Алхимик` (Drive ID `1b-FP_emjwE5LpTyx4TFzkbzlffEE7pLl`)**: новая отдельная `Хранилище Сервера Проекта Алхимик` и полный layout из `CONTENT_CATALOG_AND_STORAGE.md` (Система, Дневник с картинками/аудио/видео, Библиотека с библиотечными аудиотреками и модулями, Медиа, Пакеты, Каталог, Техническое). Прежде создания приватных данных перепроверить ACL/наследование. Создавать только отсутствующие папки по exact parent/key/id, иметь bootstrap/migration marker и readback, не дублировать при повторных workflow. IDs/credentials в Script Properties/защищённом registry, не в APK/публичных индексах. Физические деревья ≠ логические категории; общий blob может иметь одно физическое расположение и много ссылок.
- Модель ролей/permissions отдельно от UI, per-object ACL; `author`, `client`, `anonymous viewer` только для явно публичных объектов. Owner/admin bootstrap без статических мастер-паролей.
- API: версии `v1`, структурированный envelope `{ok,status,requestId,serverTime,revision?,result?,error?}`; Apps Script HTTP doGet/doPost могут не поддерживать произвольные HTTP status/headers, потому приложение интерпретирует логический код, а не выдуманный `HTTP 412` от ContentService. Параметры, размер payload, version, authentication проверяются на входе. **ПРЕ-ФЛАЙТ ОГРАНИЧЕНИЕ:** `doGet/doPost(e)` не документируют произвольные request headers, а ContentService возвращает TextOutput: нельзя реализовывать `Authorization: Bearer` в `e.headers` и binary Range/206 output будто это обычный HTTP server. Построить проверяемый HTTPS JSON POST envelope/token validation; binary upload/download в допустимых bounded chunks JSON/base64 или только через реально доступный Drive OAuth+ACL. Расходы/лимиты отчитаться без выдуманного video streaming.

## Функциональные операции, реализовать реально

**Наблюдение:** `health`, `capabilities`, `serverVersion`, публичная информация без чувствительных путей, `whoami` с подтверждённой identity.

**Публикации:** `feed.list`, `entry.get`, `entry.createDraft`, `entry.patchDraft`, `entry.publish`, `entry.updateMetadata`, `entry.reannounce`, `entry.close`, `entry.unpublish`, `entry.archive`, `entry.visibility`, `entry.deleteSoft`, `entry.restore`. Обновление записи/блоков/очередности/категорий/TTL/ContentLink/thumbnail; категории и page progress не терять, подписки/read-state изолировать per user.

**Каталог:** `catalog.list/search/get`, фильтры по типу/тегам/категориям/автору/версии/доступности, курсор/страницы, sinceToken, consistency snapshots, удалённые/закрытые tombstones, cache ETag. **Это НЕ завершённый редактор:** также `catalog.createDraft/patchDraft/attachAsset/validateDependencies/publish/updateMetadata/withdraw/archive/restore/getRevision/getInstallPlan/checkUpdates`, карточка с аннотациями, тегами, обложками, статусами/версией, relation graph track→module→template, client selective dependency install. Полное ТЗ — `CONTENT_CATALOG_AND_STORAGE.md`.

**Библиотека:** `audio.list`, `video.list`, `image.list`, `template.list`, `module.list`, `session.list`, `package.list`, `package.getManifest`, `package.publish`, `package.revoke`, `package.importRecord`, `download.receipt`, `library.versionCheck`.

**Файлы:** `media.beginUpload`, `media.uploadChunk`, `media.commitUpload`, `media.abortUpload`, `media.getDescriptor`, `media.beginDownload`, `media.downloadChunk`, `media.finalizeDownload`, `media.metadata`, `media.linkToEntry`. Раздельные media types image/audio/video/ZIP; сохранить originals + MIME/size/digest/duration (из проверенных метаданных; не выдумывать длительность), thumbnail если доступен.

**Обмен/синхронизация:** `sync.pull`, `sync.push`, `outbox.status`, `conflict.resolve`, `events.list`, `snapshot.get`; idempotencyKey, ifMatch, schema migrations, retry/backoff, dedup и atomic publication commit. Автор может экспортировать пакет на Drive и опубликовать его в каталоге; клиент скачивает и ставит пакет с проверкой хеша.

**Учетная запись и безопасность:** `auth.whoami`, `auth.roles`, `auth.revoke` (владелец), `grant.list/set/revoke` (admin), `audit.list` (owner), механизмы минимальной privacy и управления публикациями. Никакая авторская операция не допускается по `role=author` из запроса.

## Требования к консистентности

**Публикационный контракт:** `upload committed` и `catalog published` — ДВА разных состояния. Никакого публичного каталога по невалидным/непроверенным blobs, никакого «Успешно» в мастер-приложении до server readback; asset manifest immutable. Хранить author draft metadata отдельно от public index. Для большого каталога использовать shard/index strategy вместо одного неизменяемого глобального JSON.


1. Стейджить (ВНУТРЕННИЙ temporary storage, а не отдельный Apps Script test project) новые медиа, проверить длину и sha256, затем атомарно обновить указатель опубликованной immutable revision в рамках LockService/optimistic ETag; сбой сохраняет предыдущую ревизию.
2. Изменение текста не вызывает повторную передачу несменённых blob. Изменение одного видео меняет только соответствующий digest; одинаковые байты переиспользуются по content hash с собственностью/ACL. Нельзя удалять blob, если на него ссылается старый контент.
3. Полный аудит record create/update/publish/unpublish/access denial without raw secrets; журнал имён и операций без содержания приватного медиа. Удаление/политика retention отделены от бизнес-статуса закрытого дневника.
4. Поле `source={author app/client}` — только telemetry, не authorization. ACL проверяется при list, manifest и КАЖДОЙ выдаче байт. No arbitrary fileId read/write. Path traversal, replay, zip-slip, zip-bomb, oversized payload, abuse, partial write, corrupted checksum — reject с кодом.
5. Node test harness + действительно исполняемый GAS project source; ошибки API без backend header support не маскировать.
6. Внешние API/методы должны документировать реальные сценарии с примерами последовательностей запросов, размером чанков, действиями retry, identity handling и offline.

## Невозможность гарантий

Google Drive — хранилище, не полноценный видео-CDN. Apps Script — orchestration/API, не бессрочный стриминг-процесс. Если выбранная архитектура оказывается непригодной для реального большого приватного видео, нужен отчёт с точными замерами и альтернативой, не фальшивый PASS.

## Catalog publication and storage bootstrap

See mandatory `CONTENT_CATALOG_AND_STORAGE.md`. Provide typed catalog records and immutable exact asset revision references, independent metadata revisions, publication state machine, owner-only catalog mutations, public/restricted read projection, indexed search/pagination, idempotent publish/withdraw, install-plan including transitive dependencies, signed/authorized transfer path, and `storage.bootstrap` with exact named idempotent Drive folder hierarchy. Persist folder IDs and schema version, check parent ACL, never expose private diary/Google Drive file IDs in catalog. Protect against collisions/conflicts, partial upload and mixed public/private authorization. Supply live readback to prove written folder tree and client catalog. Never claim GAS ContentService provides arbitrary video binary or HTTP Range headers.
