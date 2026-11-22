# Открытые вопросы №25

|ID / уровень|Подтверждённый факт|Статус и следующий шаг|
|---|---|---|
|P0-NATIVE25|Новых signed APK и native install-r свидетельств нет; emulator/KVM/signer отсутствуют|BLOCKED_ENV. Не выдавать обновление владельцу; disposable UI-created baseline→candidate обеих editions после защищённой сборки|
|P0-SIGN25|Секретов в Cloud нет, GitHub secret inventory403; current source не поддержан trusted main workflow|BLOCKED_OWNER. Отдельно reviewed isolated manual workflow/managed signing environment; никогда новый key/секретыPR|
|P0-OWNER-HISTORY|Исходный owner MASTER24→25: исходное состояние телефона/причина пустых списков UNKNOWN|Остаётся UNKNOWN/PARTIAL, не «исправлено». Синтетические guards не доказывают судьбу старых материалов; восстановления/доступа к телефону не делали|
|P0-ID25|Future candidate code должен быть выше installed; actual installed version UNKNOWN|До owner readback установка запрещена;28 в source не новый кандидат. Same IDs/source certificate только historical/source proof|
|P1-LIVE22|Нет production GAS22 adapter/private full backup/readback/restore/rollback|BLOCKED_LIVE, flagsOFF; main/GAS6/OAuth/ACL unchanged. Source tests не закрывают этот gate|
|P1-IAM22|Настоящие Google MASTER/CLIENT и роль/refresh/два телефона не испытаны|PARTIAL/NOT_RUN_LIVE. Controlled verifier не реальный OAuth. Никаких обходов Testing или email-linking|
|P1-REV22|Automatic audio revision rematerialization/module→program update apply неполны|PARTIAL; exact refs/frozen history/immutable blobs проверены в существующих ограничениях; не заменять старые байты|
|P1-TAX22|Merge/reclassification categories complete workflow отсутствует|PARTIAL, без удаления/обнуления/новых дублей|
|P1-BACKUP22|Большие real video/ScriptProperties stream и production-shaped private restore не доказаны|PARTIAL/BLOCKED_LIVE, не активировать|
|P1-ADMIN22|Backup schedule/settings/full roles/moderation dashboard неполны|PARTIAL, не маскировать placeholder как success|
|P1-POLICY22|Финальная weighted методология/числовые веса не утверждены;>1000targets batching неполон|OPEN/PARTIAL;3slots, weightedNOT_CALIBRATED/null. Не выбирать коэффициенты самостоятельно|
|P2-COURSE22|Утверждённого Rubedo artwork нет|PARTIAL, сохранить safe missing-asset/graceful state, не придумывать знак|
|P1-DELIVERY25|For_Codex наследует anyone:writer; repoPUBLIC|ACL не меняли, только sanitized reports. SHA readback моментный, не обещание вечной неизменности; приватные медиа/credentials туда не загружались|

Новых воспроизводимых source-level P0/P1 defects в проверенном runtime не найдено. Это не отсутствие всех ошибок на реальном Android. Native blockers не сняты одним javac или успешным Actions runner. Существующие ограничения №22/23 не выданы за закрытые. Ошибка доступа403 к именам secrets не означает, что старый ключ потерян.

Следующий безопасный шаг: review draft57 и подготовка/provision отдельного доверенного signing+Android пути с точным source/diff и разрешением, если нужен main. **Production и ACL разрешение не требуется и не запрашивается.** После снятия блока — новый native P0 run, два independently read-back APK, лишь затем owner QA. Не надо присылать private key/DB, удалять приложение или повторять Google consent ради отчёта.
