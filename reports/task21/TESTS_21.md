# TESTS №21 — фактические проверки

Окончательный code source `8546bc66137bc7796954cd04f0b65cdc2851c416`; после него допускаются только отчёты. Worktree `/dev/shm/sulfi21`, Flutter3.47.9/Dart3.13.7, Node24.19, JDK21, Linux SQLite FFI/node:sqlite. Это не Android-телефон и не Google JWT authentication.

| Проверка | Фактический результат | Evidence |
|---|---|---|
| Outer ZIP SHA/CRC,8manifest entries/9files, unchanged docs copies | PASS | ARCHIVE_INTEGRITY_21.json |
| `flutter pub get --offline` | PASS, pinned pubspec/lock unchanged | logs/pub-get.log |
| `flutter analyze --no-pub` | PASS, No issues found | logs/analyze-release-source.log |
| `dart format --output=none --set-exit-if-changed <18 changed Dart files>` | PASS,0changes | logs/format-final.log |
| `flutter test --no-pub --concurrency=2` | **526 PASS,2 SKIP,0FAIL**,4m18s | logs/flutter-final.log |
| New runtime/UI/preview/queue target before receipt refinement |10PASS | logs/g2-g3-final-target.log |
| Final receipt recovery2 +runtime5+UI2+legacyadmin3 |12PASS | logs/receipt-recovery-green-final.log |
| Existing admin/widget/runtime intermediate compatibility |14PASS | logs/g2-g3-regression.log |
| CLIENT define test |1PASS | logs/client-flag.log |
| `node --test server/alchemist/test/*.test.mjs` | **62PASS**, incl8new persistent runtime tests | logs/node-full.log |
| `node --test server/google_apps_script/test/*.test.mjs` | **24PASS** | logs/legacy-node.log |
| Existing JVM transaction scheduler invariants |5PASS, pure JVM | logs/scheduler-jvm.log |
| `node scripts/alchemist/build.mjs /dev/shm/task21-gas-drybuild` | PASS, no cloud operations, production modules unchanged | logs/gas-drybuild.log; SOURCE_PURITY_21.json |
| `flutter build bundle --debug --no-pub --target-platform=android-arm64 --asset-dir=/dev/shm/task21-bundle-master` | PASS,25files/121462047B | bundle-master.json; logs/android-master-bundle.log |
| Same bundle with `--dart-define=SULFI_EDITION=client`, separate asset-dir | PASS,25files/121462047B; kernel differs | bundle-client.json; logs/android-client-bundle.log |
| Native Gradle APK/cert/install/upgrade/emulator | **BLOCKED_ENV / NOT_RUN** | NATIVE_PREFLIGHT_21.json |
| Hosted CI44959026009 | **BLOCKED_ENV,0steps** | ci-jobs.json; ci-annotations.json |
| Production GAS metadata / real Google / two phones | **NOT_RUN / BLOCKED_OWNER** | OWNER_CHANGE_GATES_21; OWNER_PHONE_QA_21 |

12 новых Flutter тестов входят в526, адресные counts НЕ складываются с общим итогом. Node62/legacy24 запускаются отдельно. Node62 был выполнен до последней правки только Dart settings recovery; Node sources после него не менялись. JVM5 — существующие реальные DatabaseTask/TransactionScheduler + SchedulerInvariantCheck, с compile-only Nullable stub; не Android SQLite/instrumentation. Два bundle logs пусты при успешном CLI; внешний `set -e` завершился0, JSON содержит реальные файловые SHA/размеры. Native плагины/Gradle/подпись не проверены этими bundle.

Два SKIP: opt-in `task18_performance_test` без TASK18_PERF_OUTPUT; `task16_live_cloud_test` без SULFI_LIVE_ENDPOINT/credentials. Большой старый live E2E/benchmark не повторялся ради отчётности. Не делались новые утверждения о live скорости или квоте сервера.

## Что именно доказано

- **Server LOCAL:** real SQLite/WAL/FULL, immutable UPDATE/DELETE deny, cold reopen, readback hash, real rollback после HEAD до receipt, child SIGKILL в транзакции, lost response после COMMIT, два независимых соединения/CAS, stale revision, null/expired principal, scopes, CLIENT write deny/role hints, role revoke между prepare/commit, revoked epoch/withdrawn/expiry, non-atomic adapter reject и redacted exceptions.
- **Flutter LOCAL / synthetic STAGING:** реальный loopback TCP и Node SQLite, существующий Alchemist API envelope, synthetic owner/client authenticated через fixture; factory→capability nonce/binding/schema/expiry/atomic→existing queue→HEAD/snapshot→SQLite current→catalog UI. Шесть intents дают одну задачу, equal HEAD0snapshot requests, нет media.* requests. Config prepare/receipt → CLIENT entrySeconds11; catalogRevision не меняется. Неверный principal/unsupported/defaultOFF, bad hash, actual503/403, scope isolation, transient capability retry и namespace20 saved сохранены.
- **Receipt RED→GREEN:** потерянный COMMIT ответ + cold settings + refreshApplied ранее менял requestId. Исправление удерживает pending intent/CAS и восстанавливает receipt1; отдельный concurrent writer config2 не откатывается в applied cache. Финальные2recovery + прежние admin3PASS.
- **Queue LOCAL:** active file1 не прерывается; control intent обгоняет waiting file2 только на dispatch boundary; owner/offset8192/attempt1/stage catalog_checked сохранены. Старые pause/recovery/outbox/tests18 проходят в full suite.
- **Data LOCAL:** non-app_settings tables canonical equality,3media SHA неизменны, PRAGMA integrity_check=ok после sync и отказов. Это не native upgrade proof PR46.
- **UI LOCAL:** реальный static selected unsaved draft в Home9:16, rect equality header/board/nav,35sec без rotation/save/read/remote/audio; close возвращает в тот же editor, старый full reader preview доступен. CLIENT admin route deny покрыт прежним widget20, write deny — новым actual server test. PNG720×1280 — Flutter render, не Android screenshot. Крупный шрифт/TalkBack на телефоне NOT_RUN.

## Промежуточные сбои и ограничения

Первый real-loopback run получил Flutter test HTTP400 из глобального harness override; исправлен только private test-zone HTTP client. Analyzer2unused imports устранены. Новый recovery RED подтвердил логическую ошибку; первый полный run прерван SIGINT для её исправления (shutdown stream error, не PASS). Промежуточная syntax error тестовой скобки устранена адресно; окончательный full526/2/0 выше. Повторов прежних неудачных native/OOM/CI без новой гипотезы не было.

[CI44959026009](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/44959026009) автоматически создан PR52 на b584e61: runner не выделен, verify0steps, annotation failed recent account payments / spending limit. Последний Dart fix и docs помечены [skip ci], hosted проверки source8546 отсутствуют; локальные проверки указаны отдельно. Billing/privacy/workflows не менялись.

Root117MiB free, cgroup8GiB, dangling old Gradle cache, noKVM и отсутствие прежнего signing env не дают безопасного native path; известный OOM19 не повторялся. Signing preflight снят на b584e61; последующая правка8546 затрагивает только Dart receipt recovery, все native/protected sources неизменны. APK21 не создан, APK28 не заменён. Установка и физическая приёмка NOT_RUN.

Текстовые log-файлы и CSV нормализованы к LF без завершающих пробелов; диагностическое содержимое/результаты не менялись. Empty bundle logs оставлены пустыми.
