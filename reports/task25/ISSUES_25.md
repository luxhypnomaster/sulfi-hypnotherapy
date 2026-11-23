# №25 — оставшиеся проблемы после реальной сборки29

|ID / уровень|Факт|Статус / следующий безопасный шаг|
|---|---|---|
|P0-NATIVE25|MASTER34 QEMU SIGSEGV на old28, до обновления; CLIENT34 полный15PASS|BLOCKED_NATIVE. Метаданные аварии из MASTER-only run45161085603; без новой гипотезы не повторять. После устранения нужны все4гейта34/36, никаких пропусков паузы/SQLite/media assertions|
|P0-SIGN25|Trusted build/sign45103325755 и обе независимые подписи PASS|RESOLVED_FOR_BINARY_ONLY, key прежний. Не означает native/physical готовности|
|P0-ID25|Code29>baseline28, package/cert совпадают; actual installed version владельца UNKNOWN|OWNER_INSTALL_BLOCKED до native PASS и readback версии/отдельного согласия. Не применять downgrade|
|P0-OWNER-HISTORY|Случай исчезновения owner MASTER24→25 не исследован на физической базе|UNKNOWN/PARTIAL, не объявлен исправленным. Личные материалы/устройство не трогали|
|P1-LIVE22|Production21/22 adapter/private full backup/restore не доказаны|BLOCKED_LIVE; флагиOFF, GAS6 не менять|
|P1-IAM22|Настоящие Google MASTER/CLIENT/refresh/роль/два телефона не испытаны|NOT_RUN_LIVE/OWNER, controlled identity не OAuth PASS, Testing не обходить|
|P1-BG29|Полная реальная background отправка/скачивание/OS recovery29 с живыми server receipts не испытана|PARTIAL. Local logic и CLIENT persistence проверены; прежние18 evidence не переименовывать в29|
|P1-REV22|Automatic revision rematerialization/module→program apply неполны|PARTIAL, exact refs/frozen history/immutable blobs сохраняются|
|P1-TAX22|Full merge/reclassification categories отсутствует|PARTIAL, данные не удалять/обнулять|
|P1-BACKUP22|Большое real video/ScriptProperties streaming/production-shaped private restore не доказаны|PARTIAL/BLOCKED_LIVE, не активировать|
|P1-ADMIN22|Backup schedule/settings/full role/moderation dashboard неполны|PARTIAL, не выдавать placeholder за finished|
|P1-POLICY22|Weighted coefficients не утверждены;>1000target batching неполон|OPEN/PARTIAL, NOT_CALIBRATED/null, веса не выбирать|
|P2-COURSE22|Утверждённого Rubedo artwork нет|PARTIAL, оставить safe missing-asset state|
|P1-DELIVERY25|Quarantine artifact истекает26ноября; For_Codex наследует anyone:writer, repoPUBLIC|Не менять ACL/видимость; только sanitized reports, без raw dumps/keys/private data. Пока нет nativePASS — не выдавать APK как проверенную. SHA readback моментный, не гарантия будущей неизменности|

Подтверждён новый инфраструктурный факт — QEMU SIGSEGV, а не дефект миграции APK29. Приложение unchanged. Избыточных повторных Flutter suites/build/signing после успешного source freeze нет. Старые неудачные renderer эксперименты17 не повторять наугад. Если диагностический дамп отсутствует — module UNKNOWN, не выдумывать место падения и не перезапускать ту же гипотезу.

Владельцу сейчас не нужны новые Google consent/пароли/ключ/компьютер, и не нужно удалять приложение. Работа с телефоном и production не является решением инфраструктурного gate без отдельного разрешения.
