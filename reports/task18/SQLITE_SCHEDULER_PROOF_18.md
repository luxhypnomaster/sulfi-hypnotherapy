# SQLite: подтверждённый контроль кандидата, не проверка пользовательской APK

Run43739426806 / driver e748c834b8e32791c0b46858f72a1e18ff38456a.
`sqlite_scheduler_control/probe/native-pool-1.json` скачан из реальных CI logs,
проверен по byte count/SHA (READBACK.json). Нативный AndroidSQLite исполнил обе
записи, rows=2, integrity=ok, errors=[], порядок A_COMMITTED перед B_WRITE_STARTED.

Это кандидатный source overlay DatabaseWorkerPool/TransactionScheduler из
build-only JAR перед неизменёнными зависимостями APKef50fc5. Это НЕ исполнение
исправленного кода из обычной MASTER/CLIENT APK. Внутренняя строка
ACTUAL_APK_NATIVE_SQFLITE_POOL_ANDROID_SQLITE осталась от первоначального
контроля и неточно описывает overlay; внешний script classification и данное
описание задают фактическую область. Исторический raw receipt не переписывается.

Общий run FAILURE: observer ошибочно требовал busyTimeoutMs=0, хотя параметр0
означал не менять штатный timeout, а его readback=2500. Функциональные результаты
2commits/integrity реально получены; это не повод объявлять весь CI успешным.
Новое имя configuredBusyTimeoutMs отделяет запрос от readback. Отдельный повтор
того же контроля ради зелёной отметки не выполняется; следующий gate — настоящие
собранные приложения и обновление исходных27.

Ранее stock pool1 и4 оба дали SQLiteDatabaseLockedException, а4+busy2000 также
не прошёл. Эти стратегии отвергнуты. После положительного native source overlay
и5standaloneJVM ordering invariants кандидат переносится в прежний single-thread
executor: другие DB connections ждут COMMIT/ROLLBACK владельца транзакции,
который может обойти ожидающую чужую SQL-операцию. No second business outbox.

THREAD_COUNT1, штатный busy_timeout/WAL, schema9, IDs, StorageSafety/corruption
callback и данные пользователя не меняются. Fresh full verify, actual APK native
background и MASTER/CLIENT27→28 gates ещё обязательны. Google/owner phones NOT_RUN.
