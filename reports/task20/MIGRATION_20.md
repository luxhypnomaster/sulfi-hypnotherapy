# MIGRATION / rollback №20

Реальные пользовательские базы не открывались и не мигрировались. SQLite schema9, template IDs, track paths, capsules, история и текущая сессия без изменений схемы.

Добавочные app_settings namespaces: catalog20:<hash(account,scope)>:prepared:<hash>/current; vitrine20:<hash(account)>; diary_local20:<JSON account,entry,cycle>. Очередь остаётся alchemist_download:... с kind catalogSnapshot20, использует AlchemistWorkQueue. Новый native worker/вторая очередь не создавались. Transport default null, legacy catalog UI продолжает существующий GAS6 API.

Read compatibility: load копирует только read=true того же readerId/цикла из diary_read в новый namespace (insert ignore). Прежние partial audio intervals и строки сохраняются без изменения. Новые read marks/quiet edits остаются local-only; explicit reannounce меняет cycle. Старые reader sync tasks/receipts сохранены, автоматически в новые задачи не преобразуются. При corrupt legacy JSON completion не предполагается. Проверено на фикстурной SQLite, не на телефоне владельца.

Локальный snapshot: проверка HEAD → fetch → schema/hash/scope/dependency validation → prepared → SQLite transaction current swap → один notifier. Fail до commit оставляет lastGood. Metadata sync не устанавливает аудио и не меняет SessionRun. Prepared retention/ограничения объёма — OPEN; GC не добавлен.

Будущая GAS-интеграция: административный readback точного Script/version/source (с отдельным разрешением), сравнение legacy кода, согласование wire schema и непротиворечивой ACL overlay; реализация durable compare-and-swap HEAD+receipt под существующим lock/storage; version negotiation, fail-before-flip/reconcile на staging. Лишь затем запрос узкого production diff/deploy с сохранённой immutable version6 и проверкой исходного HEAD rollback, не затрагивая старый дневник. Текущий experimental adapter не доказывает, что GAS6 уже поддерживает эти гарантии.

Откат кода: закрыть draft PR/не включать feature branch; при последующем внедрении — corrective commit и новый versionCode, не Android downgrade/clear/uninstall. Исходные namespaces игнорируются старым кодом и не удаляются. Нет команд, переписывающих базы владельца. Старые APK28 не заменены.
