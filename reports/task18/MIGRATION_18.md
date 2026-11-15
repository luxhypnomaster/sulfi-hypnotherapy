# №18 — сохранность и native release gate

SQLite user_version9 сохранён. Старые card/diary/reader outbox records не заменены другой очередью; app_settings получает только новые download/checkpoint/receipt keys и дополнительные work fields. Pending requestId/session/offset/receipt сохраняются. Чужие сериализованные строки и USER_PAUSED не авторезюмируются, это проверено controlled exact-byte тестом.

Legacy active intents без executor18 получают WAITING_POLICY/LEGACY_EXECUTOR_STOPPED только в текущем owner scope; требуется его явное Продолжить. Нет присвоения бесхозных старых публикаций новому пользователю. Background открывает только существующую schema9 independent connection, allowMigrations=false, не вызывает SessionController.initialize/interruptRun. SQLite busy — WAITING_POLICY, не новая пустая БД.

Download staging отделён от аудио/истории/черновиков. Проверяются recorded prefix/chunk SHA, затем whole SHA/final receipt; только после этого existing transactional importer. Повреждённый prefix остаётся для диагностики, installation success запрещён. Старые общие cache-файлы не удаляются и не заимствуются без owner proof. На pause/cancel не удаляются source/confirmed server публикации.

Отдельный scripts/task18/native_upgrade.py подготовлен для immutable MASTER27/CLIENT27→28, UI-created3WAV/2модуля/положительная пауза/программа/history/current draft, offline local diary MASTER до обновления, exact rows/media/integrity и cold restart. Он NOT_RUN, pair28 ещё нет. Никаких миграций настоящей базы/телефона владельца не выполнялось.

STOP-SHIP до actual native upgrade PASS обеих редакций и SHA/signature/package/config verification. Нельзя подменять этот gate testOnly .transferprobe установкой: у неё другие IDs и временная fixture debug-подпись. Старые APK27, ключи подписи, main/GAS/OAuth/ACL сохранены. Не предлагать uninstall/clear/downgrade владельцу.
