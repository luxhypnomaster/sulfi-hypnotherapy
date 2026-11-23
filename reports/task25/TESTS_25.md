# Проверки №25 — фактические результаты

Код: `737ea741636e9abe7c20353d9d5b8301cf44a5bb`, runtime tree равен PR56/d0417027. Отчётные commits после него не меняют lib/android/server/third_party/.github/test/scripts. Локальные команды выполнялись в /dev/shm/sulfi25, Flutter3.47.9/Dart3.13.7/JDK21/Node24/Python3.12. Временные DB/медиа синтетические; cleanup удалял только собственные temp fixtures.

|Команда/группа|Результат|Доказательство|
|---|---|---|
|flutter pub get --offline --enforce-lockfile|PASS, lockfile unchanged|logs/pub_get.log|
|flutter test --reporter expanded, исходный полный baseline|571 PASS /2 SKIP /0 FAIL|logs/flutter_baseline.log|
|flutter test --no-pub --reporter expanded, окончательный snapshot|574 PASS /2 SKIP /0 FAIL|logs/flutter_final.log|
|flutter test test/task25_integration_test.dart|3 PASS|logs/integration25.log|
|flutter test --no-pub --dart-define=SULFI_EDITION=client test/task5_client_build_test.dart|1 PASS|logs/client_edition.log|
|flutter analyze --no-pub|No issues|logs/analyze.log|
|dart format --output=none --set-exit-if-changed lib test|238 files /0 changes|logs/format.log|
|node --test server/alchemist/test/*.test.mjs|79 PASS /0 FAIL|logs/node.log|
|node --test server/google_apps_script/test/backend.test.mjs|24 PASS /0 FAIL|logs/legacy.log|
|node --test scripts/task17/test_approved_diary_patch.mjs|11 PASS /0 FAIL, controlled only|logs/diary_patch17.log|
|python unittest scripts/task16v|10 PASS|logs/python16v.log|
|python unittest scripts/task17|17 PASS|logs/python17.log|
|python unittest scripts/task18|9 PASS|logs/python18.log|
|python unittest scripts/task23|13 PASS|logs/python23.log|
|python unittest scripts/task25|4 PASS|logs/python25.log|
|javac -source17 -target17 -cp Android36 android.jar StorageSafety.java|PASS_TYPE_COMPILE,1 module-path warning|logs/android_type_compile.log|
|git diff --check; scripts/task25/source_gate.py|PASS_SOURCE,335 protected +31 native pins|SOURCE_GATE_25.json|
|Actions runner availability, main only, no secrets|SUCCESS,9 steps, one dispatch|CI_PROBE_25.json; logs/runner_probe.log|

Node total114, Python total53. Targeted tests входят в/пересекаются с полным suite, не складывать их повторно для завышения общего Flutter-count. Baseline запущен до появления трёх новых тестов; полный окончательный повтор оправдан добавлением тестов и freeze code. Других повторных полных прогонов не было.

Два SKIP: task16_live_cloud_test — нет SULFI_LIVE_ENDPOINT/реальной Google-пары; task18_performance_test — нет TASK18_PERF_OUTPUT/специального benchmark run. Это не PASS и не утверждение скорости production.

Новые интеграционные проверки: настоящий LocalCatalogSource экспорт/выборочная установка программы MASTER→CLIENT,3AAC+2pauses, неизменность установленного модуля после author revision2, existing SessionEngine с controlled transport, completed frozen history, user-paused persistent queue и8таблиц после headless открытия SQLite-копии; mediaSHA неизменны. Две controlled TCP/Node SQLite backend проверки доказывают отсутствие candidate21/22 запросов при флагахOFF, отдельно MASTER/CLIENT. Synthetic tokens не Google-вход.

Полный suite заново проверил schema6/7/8→9 и9→9, corrupted/alternate/missing path, WAL/SHM/journal copy recovery, capsule hashes/manifest/owner/cancel/concurrency, unknown staging preservation, frozen history/program refs, existing auth/retry/queue logic, catalog cache/HEAD/CAS/receipt,3ratings/NOT_CALIBRATED, courses exact refs, F038/K025/026/027/029/030/037,9:16 и client editing boundaries. Никакого нового runtime defect не воспроизведено; runtime fixes0. Названия старых тестов RED→GREEN — исторические regressions №23/24, не новые RED-прогоны №25.

## Продолжение: реальные APK и native

Защищённая сборка45103325755 SUCCESS; actual Flutter/Gradle build обеих editions, unsigned credential-free; подпись отдельной trusted-main job. Независимый apksigner/aapt/package/version/SHA/CRC/SDK/ABI/config/permissions PASS (APK_INFO/APK_READBACK, candidate29/).

`PYTHONPATH=scripts/task25 python3 -m unittest discover -s scripts/task25 -p 'test*.py'`: **70 PASS**,2026-11-23; отдельный текущий инструментальный набор, не складывать с53исходного baseline как уникальные все-project tests. `actionlint1.7.12 -shellcheck= -pyflakes=` verify workflow PASS, официальный бинарник проверен по provider SHA. Embedded Python compilations и credential/context restrictions покрыты controlled tests.

Native45157723278: CLIENT34 **15PASS**, MASTER34 **5PASS+1BLOCKED** (old28 QEMU SIGSEGV), API36bothNOT_RUN, deliverySKIPPED. Actual controlled Android evidence независимо прочитаны и проверены дополнительным fail-closed validator: CLIENT PASS, completeFourGates false, pair BLOCKED_NATIVE_DELIVERY. Это не успешная Android-приёмка пары.

Все70tools tests включают8synthetic minidump parser tests, отсутствие чтения memory payload, bounded metadata, отказ некорректных offsets, symlink skip, корректный NO_MINIDUMP_FOUND; они не заменяют native root cause. Run45161085603 — отдельная secret-free MASTER-only diagnosis. Его terminal output фиксируется отдельно.

Flutter574/Node114 целиком заново не повторялись после report/tool-only правок: protected runtime335/native31 unchanged. Среда после остановки восстановлена в /dev/shm/sulfi25-resume; прежние APK exact bytes проверены без rebuild/resign.

**NOT_RUN:** реальные Google/users/физические телефоны, фактически услышанный звук, реальная запись, новый29OS-kill transfer receipt, API36, min24/35native и production22/livebackup. Исторические native17/18 и source compile не названы current25nativePASS. Оригинальный owner24→25causeUNKNOWN. Никаких действий на телефоне владельца.

Дополнительные2tests используют завершённый CLIENT34 артефакт: exact old content_revisions PASS и удаление ревизии из копии отчёта → BLOCKED, несмотря на исходные casePASS. Никакая настоящая база не изменялась. Независимо проверяются15таблиц; пустые таблицы не выдаются за проверку непустых image/attachment fixtures. Native diary-image attachment fixture пока NOT_RUN.70 включает прежние68, не складывать счётчики.
