# №25 — native normal-upgrade

**Обе редакции: BLOCKED_ENV; фактических установок0.** API34/35/36/min24 NOT_RUN. Физический Android/настоящая Google-пара NOT_RUN. Локальный Flutter FFI тест не является Android sqlite/WAL, PackageManager или звуковым выводом.

|Редакция|Историческая baseline|Новая signed APK|UI dataset в старой APK|install-r|Cold/IDs/SHA/queue|
|---|---|---|---|---|---|
|MASTER|28: исторический source de408f1cae08fce16069a701d147a0b1064053ba, подпись по №18|BLOCKED|NOT_RUN|NOT_RUN|NOT_RUN|
|CLIENT|28, отдельный .clienttest package, тот же исторический cert|BLOCKED|NOT_RUN|NOT_RUN|NOT_RUN|

Прежние №17/18 native receipts не переименованы в №25. Историческая подписанная baseline доступна по прежним материалам, но её194MB не скачивались без пригодной native-среды; проверка downloaded baseline cert в этом этапе NOT_RUN. Внезапный пустой scope/SQLite телефона24→25 остаётся UNKNOWN, не заявлен исправленным.

Причины: нет emulator/KVM/signer; текущий trusted default-branch signing workflow не умеет брать новый approved source. Никаких бесполезных emulator installations, повторов0steps или авто-debug-keystore. SDK36 source/type checks отдельно PASS_READ_ONLY/PASS_TYPE_COMPILE в ANDROID_AUDIT_25, не nativePASS.

Будущая disposable fixture обязательно через UI baseline:3реальных synthetic AAC, модуль с паузами, программа/templateIDs, current draft, offline-local diary+media, frozen history+checkpoint, pending/USER_PAUSED transfer, capsule. Supplementary queue injection, если необходима, отмечается отдельно и не заменяет UI-created контент. До/после normal install-r без удаления: counts/IDs/revision refs/bytes SHA/SQLite integrity/paths/queue checkpoints и owner isolation. Сначала обе редакции, затем независимая выдача.

Запрещены действия на телефоне владельца, uninstall, clear, downgrade, импорт/перезапись настоящих материалов. План не является выполненным тестом.
