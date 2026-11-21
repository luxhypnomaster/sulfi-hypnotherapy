# SECURITY №20

Запрещённые изменения не выполнялись: production GAS6/Router/OAuth/ACL/main/signing и пользовательские SQLite/медиа не изменены. Auth19 OFF, APK28 сохранены. Изолированный Node contract не включён в GAS bundle.

HEAD и snapshot требуют server-owned scope через authorize. Write допускается проверенной серверной ролью адаптера, не edition/email/client hint. Строгая проекция метаданных исключает owner/readers/token/localPath/Drive IDs/локальный прогресс и бинарные байты. Отзыв прав проверяется отдельно на snapshot/asset boundary; snapshot не является разрешением скачать файл. Тесты ACL/CLIENT-write/private dependency/readback/ID conflict — controlled, не live.

SQLite current/prepared и vitrine drafts изолированы hash(account,scope); проверяются schema, checksum, точные зависимости, owner до и после I/O. Старые SessionRun, аудиоревизии, manifests и file rows не переписываются. LastGood не очищается при ошибке/503/offline.

Новые read-state — diary_local20 с account+entry+activationCycleId, без аудио-интервалов и sync.push. Существующие diary_read и старые outbox/receipts не удалены; явный legacy mode остаётся проверяемым.

MASTER-only sticker и закрытый CLIENT route — интерфейс, не основание серверных прав. Нет production VitrineAdminTransport; кнопка серверной публикации отключена. Локальное сохранение не выдаётся за applied/published. Роли в staging fixtures не являются настоящим Google-входом.

OPEN: реальная интеграция scoped ACL/expiry/withdrawn overlay, runtime negotiated endpoints, server-atomic storage adapter, подтверждённая canonical wire схема, native metadata worker adapter. Только после отдельного согласования deploy. Никакого ослабления TLS/OAuth/ACL.

For_Codex имеет унаследованный anyone:writer по read-only metadata; права не менялись. В доставляемых отчётах только технические результаты и синтетические данные. Исходники приватного репозитория, секреты и APK в папку не загружаются.
