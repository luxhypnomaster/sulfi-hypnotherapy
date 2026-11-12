# №16-В — Android SQLite corruption handler

## Подтверждено в реальных APK24/25

Все17 native DEX файлов двух APK побайтно совпадают: `NATIVE_DEX_COMPARISON_16V.json`. В classes10.dex присутствует реальная `com.tekartik.sqflite.Database`; disassembly `SQFLITE_NATIVE_DEX_16V.txt` показывает:

- `open()` вызывает 3-argument `SQLiteDatabase.openDatabase(path,null,flags)` с CREATE_IF_NECESSARY (и опциональным WAL). Употребляется стандартный Android DatabaseErrorHandler.
- `openReadOnly()` вызывает 4-argument overload с явно заданным custom `DatabaseErrorHandler` (noop).

Проверена pinned dependency sqflite_android2.4.5 из pubspec.lock. Её исходник прямо поясняет для read-only: «Change default error handler to avoid erasing the existing file»; «default implementation delete the file». Следовательно, отсутствие delete/recreate в Dart catch НЕ доказывает отсутствие destructive Android framework behavior при corruption.

## Статус

Потенциальный destructive путь подтверждён кодом/реальным DEX. **Это не доказательство повреждения или удаления базы владельца**, и не новый diff24→25: dependency/native code одинаковы. Связь с конкретным инцидентом UNKNOWN. Подтверждение Android runtime на controlled helper-owned corrupt DB фиксируется отдельно native evidence (если выполнено); не выдаётся за native24→25 UI upgrade.

## Границы исправления

Простой catch в Dart не перехватывает действие Android handler до исключения. Нельзя объявлять bootstrap безопасным на основании текста «Данные не сброшены». Read-only preflight/noop-handler мог бы остановить часть проблем, но сам по себе не защищает от последующей corruption/TOCTOU при RW-open/query. Нельзя под видом минимального fixes включать неподтверждённый reset/restore/GC.

Постоянная native no-delete error-handler коррекция требует отдельного проверенного подхода (например, аккуратно pinned/reviewed backend patch), полного snapshot+failure regression и review. В этом checkpoint backend dependency не заменялась, не форкалась и не обновлялась; ключи и Android источники приложения сохранены. **Дополнительный STOP-SHIP для APK26**, пока безопасный путь не доказан.

## Runtime evidence (native Android35, run43259518712)

Реальный helper-owned controlled DB (не Sulfi, не owner) создан, закрыт, скопирован, затем намеренно повреждены первые16 bytes каждой копии. Старые/source bytes пользователя не участвовали.

- Default RW open: corrupt SHA `f7fc9f6d9daf4ba3253827533e2dd0d4fdeb437eafc2043a403f797613309e03` → `fcc764519d2c607f2501288ae7200254f30f2a4c0eb78ea63a5c3385357e44bd`, `exception=none`, `exists=true`. Подтверждено изменение/recovery-open вместо fail-closed на этом corruption.
- Read-only custom noop-handler open: тот же corrupt SHA неизменен, `SQLiteDatabaseCorruptException`.

Это доказывает небезопасный механизм на Android35 и возможность недеструктивного отказа read-only на этой fixture. Не доказывает, что owner DB была повреждена; не является permanent RW fix и не доказывает восстановление. Точное JSON в NATIVE_UI_UPGRADE_RUN5.json/case native_dependency_corruption. Коррупция не вносилась в sandbox Sulfi. App-native24→25 сохранность проверяется отдельно; этот тест её не заменяет.
