> Актуальное продолжение23.11.2026: [TESTS — новые результаты](candidate29/continuation_sdk37310/TESTS_CONTINUATION_25.md). Полный native-допуск пары остаётся **BLOCKED**; ниже сохранён исторический срез доSDK37.3.10. [Текущая сводка](00_CURRENT_STATUS_25.md).

# Native update №25 — доказательства и границы

Обе actual APK28/29 имеют прежние cert/applicationId;29>28, target36/min24/3ABI. Только одноразовые GitHub-hosted Android, без owner device, uninstall, clear или downgrade.

|Редакция / платформа|Run|Результат|
|---|---|---|
|CLIENT API34|45157723278|15/15PASS: actual UI baseline→install-r29→cold, old rows/media/revisions/settings/capsule, native audio, offline cached reader|
|MASTER API34|45164078203|17/17PASS: то же плюс локальные draft28 иdraft29; old history completed сохранена|
|MASTER AOSP35|45166539406|17/17PASS, old interrupted history сохранена, independent15-table readbackPASS|
|CLIENT AOSP35|45166539406|5PASS, затем QEMU3168 SIGSEGV на old28 pause before29; no minidump|
|Обе API36|последний run7|NOT_RUN, required dependency failed|
|Владелец / настоящие Google / физический звук|—|NOT_RUN|

Fixture:3WAV с разными SHA и одинаковыми названиями у2треков; module3tracks, module+pause, program/templateIDs, currentdraft, frozen session history (completed или interrupted, точный status в JSON), MASTER text local draft и SAF capsule. Supplemental queue/publiccache/settings вставлены insert-only в настоящую AndroidSQLite, не заменяют UI-created контент и не являются Google.

Независимый readback проверяет actual28/29, SQLite integrity/schema9,15таблиц (включая content_revisions), точное наличие всех old rows, SHA old media/external capsule, cold state, real native audio observed. Native diary-image/video attachment fixture и Google-sub migration NOT_RUN; source/copy-only regressions этих путей отдельно PASS_LOCAL.

Confirmed infrastructure events: QEMU exit-11/SIGSEGV на old28 MASTER/API34 run4, CLIENT/API34 run6 и CLIENT/AOSP35 run7. Wrapper signals[], cgroupoom/oom_kill0; памяти доступно~14GB. Это отсутствие OOM-kill evidence, не исключение allocation fault. Module/function UNKNOWN, NO_MINIDUMP_FOUND. Ранее37.2.13/swangle/lavapipe неудачны; новых слепых повторов нет.

Отдельная ошибка test navigation run5 (16PASS+1BLOCKED при QEMUexit0) исправлена MASTER-only reader→list→author observer, без app Back/role/SQL changes; nativeGREEN17 на34/35 подтверждён.

Требуемый полный набор MASTER/CLIENT×35/36 не завершён. Independent validator возвращает BLOCKED_NATIVE_DELIVERY, поэтому verified tester artifacts не опубликованы. Старые14PASS не подменяются полной приёмкой. Исторический owner24→25UNKNOWN. Телефон владельца не следует использовать как обход этого gate.
