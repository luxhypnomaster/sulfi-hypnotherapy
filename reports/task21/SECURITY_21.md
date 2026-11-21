# SECURITY №21

**Результат:** локальные negative gates PASS; production security approval НЕ получено и не подразумевается. Sandbox — не live GAS/Google.

- Envelope v1; canonical sorted-key UTF8 JSON / safe integers / SHA256. Unknown schema/hash/canonical/operations, неверные nonce/binding/scope/expiry/atomic capability отключают новый протокол. Capabilities не предлагают новый endpoint; ExistingMetadataRpc использует прежнюю HTTPS/redirect/credential policy, один bounded request,20sec timeout.
- Сервер получает principal исключительно из приватного resolveCredential callback. Synthetic fixture tokens не выдаются за Google JWT. Null/expired actor401; чужой scope403; CLIENT config write403; request roles/email/APK hints не дают прав. Config commit повторно проверяет текущие права после prepare. Реальная role registry/OAuth не менялась.
- Backing store обязан объявить и доказать atomicHeadReceipt. Настоящие SQLite transactions/readback/immutable triggers и lost-response receipts проверены; не приписываем SQL/ACID существующим GAS/Drive. Production adapter остаётся STOP до доказательства равных гарантий.
- Отозванный/устаревший/истёкший scope не читает старый server snapshot. Локальный lastGood разделён по verified owner+package scope, config по той же границе; settings20 остаётся в прежнем readerScope namespace. Account/epoch проверяются до локального применения. Старые приватные записи не удаляются.
- Экспериментальные модули не включены в production Router/GAS build. Test loopback server требует SULFI_TEST21_SANDBOX=1, слушает только127.0.0.1, работает с временной БД. Control seed/mode не являются live API.
- Нет second queue/worker, Google chooser loop, автоматического скачивания медиа, новых secrets, Auth19 ON или provider cutover. Unexpected server exceptions редактируются до bounded allowlist code.
- Static selected preview читает только уже локальные изображения, не вызывает resolver/player/mark/save. Screenshot и fixtures синтетические.

SOURCE_PURITY_21.json подтверждает0изменений protected paths от PR51, main readback b88637a. Это read-only Git proof, а не новый административный readback GAS6. Production deployment/ACL/OAuth операции не выполнялись. Node/Dart tests не подтверждают реальные Google grants, role assignment или двухтелефонную приёмку.

For_Codex и новая папка21 наследуют anyone:writer. Права НЕ изменялись. Загружаются только обезличенные отчёты/логи/render, без APK, исходников, БД, аудио и токенов. Readback SHA подтверждает байты на момент проверки; не гарантирует неизменяемость этой общей папки в будущем.
