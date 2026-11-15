# №18 — сохранность и native release gate

SQLite user_version9 сохранён. Старые card/diary/reader outbox records не заменены другой очередью; app_settings получает только новые download/checkpoint/receipt keys и дополнительные work fields. Pending requestId/session/offset/receipt сохраняются. Чужие сериализованные строки и USER_PAUSED не авторезюмируются, это проверено controlled exact-byte тестом.

Legacy active intents без executor18 получают WAITING_POLICY/LEGACY_EXECUTOR_STOPPED только в текущем owner scope; требуется его явное Продолжить. Нет присвоения бесхозных старых публикаций новому пользователю. Background открывает только существующую schema9 independent connection, allowMigrations=false, не вызывает SessionController.initialize/interruptRun. SQLite busy — WAITING_POLICY, не новая пустая БД.

Download staging отделён от аудио/истории/черновиков. Проверяются recorded prefix/chunk SHA, затем whole SHA/final receipt; только после этого existing transactional importer. Повреждённый prefix остаётся для диагностики, installation success запрещён. Старые общие cache-файлы не удаляются и не заимствуются без owner proof. На pause/cancel не удаляются source/confirmed server публикации.

Отдельный scripts/task18/native_upgrade.py подготовлен для immutable MASTER27/CLIENT27→28, UI-created3WAV/2модуля/положительная пауза/программа/history/current draft, offline local diary MASTER до обновления, exact rows/media/integrity и cold restart. Он NOT_RUN, pair28 ещё нет. Никаких миграций настоящей базы/телефона владельца не выполнялось.

STOP-SHIP до actual native upgrade PASS обеих редакций и SHA/signature/package/config verification. Нельзя подменять этот gate testOnly .transferprobe установкой: у неё другие IDs и временная fixture debug-подпись. Старые APK27, ключи подписи, main/GAS/OAuth/ACL сохранены. Не предлагать uninstall/clear/downgrade владельцу.


## Actual gate result15.11 11:38UTC
MASTER14/14 and CLIENT12/12 PASS in43708103115/sourcecea4897. Source27 UI-created distinct3WAV/2modules/positivepause/program/history/current draft preserved exactly in real normal-package install -r update28, cold restart and UI/nativeAudio. MASTER local diary draft created in27 before update also preserved; new28 local draft saved/cold readback PASS. Read-only copied SQLite/WAL integrity checks, no synthetic SQL replacement.3 independent SHA/cert/config readbacks match candidate cache.

Boundary: no real Google owner in emulator, so APK27 owner-bound cloud queue retention remains controlled unit verification; not a physical or authenticated queue migration PASS. Native background new-source/API35/36 and delivery gate remain separate. No changes on owner device, no forced downgrade/uninstall/clear/import.
