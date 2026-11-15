# Задание №18 — PARTIAL, продолжение 15.11.2026

Исходник обеих кандидатных APK28: `de408f1cae08fce16069a701d147a0b1064053ba`, версия `0.4.20+28`. Ветка `feat/task18-native-background-transfer`, draft [PR49](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/49) основан на **необъединённом PR48**. Main `b88637a105b2182c7b836311ebb3de7ad037b08f` не менялся. Предыдущие карантинные APK59/a894 не выдаются.

## Реализовано

Передача принадлежит Android JobService/foreground service и отдельному Flutter engine, а не экрану приложения. Единая существующая SQLite-очередь, проверенный owner/role/lease, сохранение подтверждённых блоков и receipts. Установка использует staging, SHA и прежний транзакционный importer. Уведомления позволяют поставить на паузу или отменить; Home/блокировка больше не равны ручной паузе. Системные ограничения Android, logout и ручной Force Stop не обходятся.

Подтверждённые при native-испытаниях дефекты исправлены: короткий сетевой сбой на Android13 оставлял задачу в очереди ОС без скорого запуска; после гибели процесса regular job мог долго оставаться в batching; общий однопоточный sqflite executor блокировал COMMIT за чужой SQLite connection. Сохранены один SQL worker, прежние timeout/WAL/schema9/StorageSafety, исходники аудио и очередь. Подробности: ROOT_CAUSE_BACKGROUND_18.md, SQLITE_SCHEDULER_PROOF_18.md.

## Фактические проверки текущего исходника

- [43744944796](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43744944796): verify SUCCESS — 489 Flutter, 3 CLIENT, 47 Node Alchemist и 24 legacy, contracts/analyze/format. Обе нормальные APK собраны, проверены package/version/config/SHA/прежняя подпись и отсутствие probe-кода. CLIENT27→28: 13/13 PASS. Общий run FAIL: сам QEMU упал SIGSEGV ещё на старом MASTER27, до установки28; OOM не зафиксирован. Это не PASS и не ошибка миграции28.
- [43744948169](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43744948169): API34 full SUCCESS11. Настоящее уничтожение UI engine, экран выключен, network/cancel/exact range, единичный commit программы, 3 WAV/whole SHA/атомарная установка/холодное офлайн-воспроизведение через AudioTrack. SIGKILL: PID2975→3205, автоматическое продолжение за6,98sec без UI и принудительного старта recovery.
- [43764140442](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43764140442): native legacy queue conversion SUCCESS в обеих редакциях; сохранены foreign/unbound/user-paused bytes/request/session/attempts. Это отдельный controlled test, не Google-вход и не замена обновления обычных APK.
- [MASTER27→28 /43764129343](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43764129343): **15/15 PASS** на официальном AOSP API35, те же обычные подписанные APK и прежние UI/data критерии.3WAV/2модуля/положительная пауза/программа/history/current config/старый diary draft и5supplemental controlled legacy queue rows сохранены; integrity/cold restart/новый offline draft28 PASS.
- Full [API33 /43764132106](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43764132106), [API35 /43764134857](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43764134857), [API36 /43764137702](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43764137702): **по10/10 PASS**, те же cached fixture inputs DE408, без новой сборки/подписи. MASTER upload→CLIENT exact resume/atomic install/offlineAudio. Все6gates привязаны к actual successful job, source/driver/SHA receipts и фактическому AOSP systemImage в DELIVERY_GATE_18.json.

## Проверенная пара для приёмки

Все шесть native gates текущего исходника PASS. [Выдача43765843573](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43765843573) SUCCESS: восстановлены **те же** кандидатные APK из кеша, заново проверены байты/cert/config/gates, добавлены только2новых файла в существующий закрытый draft445425835, каждый независимо скачан через GitHub asset API и сверены SHA/подпись. Старая пара27/manifest, privacy/draft/target сохранены. Новый релиз/tag/main/публичная публикация не создавались, signing не повторялся. Доказательства: APK_PAIR_18.json, DELIVERY_GATE_18.json, DELIVERY_READBACK_18.json, evidence/DELIVERY_DE408_18.log.

- [MASTER28 — обычная APK, 193,900,724байт](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-c7073f0a5871b5fb707c/alchemist-master28-task18-de408f1.apk), SHA256 `2bec82df8b75dcc6b8e6b49faf5f4244627003c137c2ded25b844d611cdd4d6e`.
- [CLIENT28 — обычная APK, 193,900,756байт](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-c7073f0a5871b5fb707c/alchemist-client28-task18-de408f1.apk), SHA256 `637195c8eb9771208be822fcfbef586023240c658072eb5c4edcbc3176026051`.

Ссылки **закрытые**: нужен вход владельца GitHub; это не открытая выдача любому тестировщику. При404 сначала войти в GitHub, затем открыть [существующий draft](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/tag/untagged-c7073f0a5871b5fb707c) и выбрать файл. Можно передать скачанный APK через мессенджер. Работа browser-cookie download с телефона ещё NOT_RUN; фактическая authenticated API-загрузка обоих файлов доказана. APK28 на Google Drive не загружались; разрешение на публичный CLIENT27 не расширяется автоматически на28.

Две неуспешные попытки выдачи сохранены:43765533682 obsoleteSDKpackage'tools' и43765701087 trailingSlash repositorymetadata404. Обе остановились до append; узкие исправления SDKbuild-tools и canonicalURL покрыты9guardtests. Ни одного native gate не ослаблено, новых сборок/подписаний не делали.

## Что остаётся

OWNER LIVE / реальные Google MASTER+CLIENT, два физических телефона, фактическое обновление личной базы владельца, OEM, слышимость, reboot, active-transfer Force Stop, длительные квоты и live GAS throughput — **NOT_RUN**. Controlled TCP/native не заменяют эти проверки. MASTER download и CLIENT read-sync upload подключены к общим адаптерам, но не объявлены полноценно native/live пройденными. Матрица25критериев:24PARTIAL, QA25BLOCKED до человека; отдельные CODE/EMULATOR/OWNER_LIVE колонки.

По скорости доказаны повторяющиеся RPC/checksum phases и измерения real loopback TCP1/15/50MiB с SHA/бюджетом запросов. Стабильное ускорение GAS/Google Drive не заявляется; серверные оптимизации требуют отдельного diff/rollback/разрешения. GAS6 остаётся без изменений; известный №17 message-only Diary EMPTY_ENTRY требует отдельного разрешения на patch, здесь не исправлялся. ContentLink проверять настоящим элементом, не авторской фразой.

Первый шаг владельца — скачать нужную APK28 и штатно обновить поверх27, затем проверить прежние материалы **до** сетевой приёмки. Не удалять приложение/данные, не делать downgrade. Точный протокол: PHONE_QA_18.md. Задание №18 остаётся PARTIAL, это кандидат для OWNER QA, не физический PASS.

Дополнительно обе опубликованные **в закрытом draft** APK скачаны непосредственно в рабочую среду, независимо от CI, и повторно проверены verify_pair.sh: SHA/размер/прежняя подпись/package/version/config/permissions/noProbe PASS. Это binary-readback, не физическая установка и не Google-вход. DELIVERY_READBACK_18.json.
