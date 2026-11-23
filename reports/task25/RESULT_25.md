> Актуальное продолжение23.11.2026: [RESULT — новые результаты](candidate29/continuation_sdk37310/RESULT_CONTINUATION_25.md). Полный native-допуск пары остаётся **BLOCKED**; ниже сохранён исторический срез доSDK37.3.10. [Текущая сводка](00_CURRENT_STATUS_25.md).

# №25 — итог продолжения 23.11.2026

**PARTIAL / BLOCKED_FULL_NATIVE_DELIVERY. Две настоящие подписанные APK29 существуют, но пара не допущена к установке на телефон владельца.**

Код приложений: `737ea741636e9abe7c20353d9d5b8301cf44a5bb`. Код инструментов и сохранённый результат: `5977584cfeb14d3f3222d49e45729f76fff35f47`. Доверенная QA main: `e5b91a7e2a68c345dda12a64d079fdc1d6d365b7`. [Draft PR57](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57) остаётся открытым, база PR56; весь app-стек PR51–57 не объединён. Runtime335/native31 без drift; production-флаги21/22/Auth19 OFF.

|Уровень|Результат|
|---|---|
|INTEGRATION_READY|PASS_SOURCE_LOCAL:574 Flutter PASS/2SKIP,114 Node, исходные53 Python; analyzer/format/pins PASS|
|NATIVE_CANDIDATE_MASTER|Actual signed binary PASS; полные controlled update API34 иAPI35: по17PASS; не физическая приёмка|
|NATIVE_CANDIDATE_CLIENT|Actual signed binary PASS; полный controlled update API34:15PASS; AOSP35 прогон BLOCKED до29|
|Полный native допуск пары|BLOCKED: CLIENT host QEMU SIGSEGV на старой28; обе API36 и delivery пропущены обязательным gate|
|Новые инструменты QA|76 controlled tests PASS, actionlint PASS; новый observer исправлен с RED replay и native GREEN|
|SERVER_PROD_READY|false для новых возможностей21/22; production не менялся; сохраняется отдельный Diary17 gap|
|OWNER_DEVICE / REAL_GOOGLE|NOT_RUN; фактическая установленная версия UNKNOWN; устройства не затронуты|
|Выдача APK для установки|BLOCKED; файлы остаются quarantine, APK на Drive не загружались|

[Build45103325755 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45103325755) реально создал обе APK `0.4.21+29`, прежние applicationId и cert `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`. Независимо проверены подписи, SHA, ZIP CRC, размер, версии, SDK/ABI/config и права. Оба APK по194184164байта. Подробности и полные SHA — APK_INFO/APK_READBACK. Новый ключ не создавался; signing credentials не попадали к app/Gradle-коду.

Последний [run45166539406](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45166539406): MASTER35 полный17PASS; CLIENT35 пятьPASS, затем сам QEMU завершился SIGSEGV при паузе в old28 до установки29. Independent15-table readback подтверждает MASTER PASS и общий BLOCKED_NATIVE_DELIVERY. OOM-kill и внешний cancel не наблюдались; faulting module UNKNOWN, minidump не появился. Переход на ранее применявшиеся AOSP35/36 не устранил нестабильность CLIENT. Новых одинаковых запусков нет.

Ранее CLIENT34 полный15PASS (45157723278) и MASTER34 полный17PASS (45164078203) подтвердили реальное обычное install-r28→29, SQLite/media/revisions, модули, программу, историю, настройки, cold restart; MASTER также локальный черновик. Эти доказательства не подменяют незавершённый полный gate35/36 и проверку телефона владельца. Текстовый diary fixture не равен native image/video attachment test.

Старый owner24→25 остаётся UNKNOWN; live Google/OS-transfer29/двухтелефонная приёмка и ограничения22/23 открыты. Ни main app-merge, ни production deploy, ни OAuth/ACL/key/userdata change, ни public release не выполнялись. Исходные отчёты сохранены. 55 критериев перечислены в ACCEPTANCE с точными уровнями; большое число local/binary PASS не означает релизную готовность.
