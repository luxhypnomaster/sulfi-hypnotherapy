# Источник истины, ревизии и безопасная миграция №15 G3

## Модели

`CatalogItem` (track/module/template/collection/package), `CatalogCard` (description/annotation/tags/visibility/cover), `CatalogPublicationRevision`, `CatalogDependency`, `DriveFolderRegistry`, `InstallPlan`, `Account`, `Grant`, `DiaryEntry` (authorPrivate/public projection), `Block{text,image,audio,video,contentLink}`, `PublicationRevision`, `ActivationCycle`, `ContentLink`, `LibraryAsset`, `AudioAsset`, `VideoAsset`, `MediaBlob` (sha256 immutable), `PackageRevision`, `Module`, `Template`, `Session`, `ReadState` (per user), `UploadSession`, `DownloadReceipt`, `SyncCursor`, `AuditEvent`. Для каждой сущности `schemaVersion`, ownership, updatedAt, revision/etag, deletedAt/tombstone. Нельзя публично сериализовать raw private Drive file IDs, session tokens и таблицу grants.

## Ключевая историческая ошибка №15

Один прежний `audioAssetId` не гарантирует точного сосуществования разных байтов v1/v2 в старых сессиях. В рамках №16 обеспечить **полную** version identity `(logicalId,revisionId,sha256)` и строгую ссылку на immutable blob. Миграция старой SQLite схемы: inventory+backup+dry-run+rollback+reconciliation tests, сохранение последней открываемой версии, отсутствие подмены старого аудио новым. Не менять checksum/byte content старых файлов, не чистить разделяемые assets до ref-safe GC. Если невозможно безопасно мигрировать в один проход — об этом указать и fail-closed на конфликтных случаях, не приносить старые данные в жертву полному серверному запуску.

## Публикация и синхронизация

**Каталогизация:** отдельно stable `catalogItemId`, content logicalId, `assetRevisionId`+sha256, и `metadataRevision`, `publicationRevision`, `visibility`. В `Module` должны быть exact immutable track refs + упорядоченные шаги/паузы; `Template` должен ссылаться на версии модулей; `Collection` — на состав. Обновление annotation/category/cover metadata не пересылает неизменные аудиобайты. Отзыв каталожной карточки не удаляет установленные личные клиентские копии. Публикация только после проверенного полного dependency graph и byte readback; сперва immutable manifest, затем atomically active published pointer. `DriveFolderRegistry` хранит idempotent pathKey→folderId и ACL verification, а не слепо доверяет имени.


Постоянные IDs; новый snapshot записывается после `media.commit`; `LockService`+expectedRevision/version guards, idempotency key and payload digest. `quiet edit` меняет редакцию без новой активности; `reannounce` увеличивает activationCycle и может сбросить read-indicator на клиенте; `close`/expiry скрывает из активного feed без удаления history и blob. Клиент хранит локальный read-state и download states, серверный per-user sync при явном согласии не должен смешивать разных читателей.

Дифф bytes: metadata-only=0 media upload; changed image=1 image; changed audio=1 new immutable blob; unchanged ZIP=0. Download must check exact descriptor; client cache must not reuse wrong byte revision. Отложенная очистка только по проверенной reference graph и restore window; все старые imports/exports имеют path and hash tests.

## Backup, recovery

Версионированный Git source, server config export без секретов, список Drive immutable roots, snapshots/backups, LocalCatalog backup. Rollback version/deployment НЕ откатывает данные; отдельный восстановительный документ для хранилища. API error revisions/schema incompatible: оставлять старый стабильный контент, не автоматом удалять. Каждый destructive migration: preflight + backup + dry-run + reversible step + report.
