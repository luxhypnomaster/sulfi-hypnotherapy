# TESTS №20 — фактические уровни, 2026-11-21

Source: `9e898024a51f23c602fe216784b0532e4bee90e4`, PR51 draft от PR50. Flutter3.47.9/Dart3.13.7, JDK21, SQLite FFI в Linux. Команды выполнялись из worktree `/dev/shm/sulfi20`, Flutter в `/workspace/tools/flutter/bin`, `TMPDIR=/dev/shm`. Логи в `logs/`.

| Проверка | Фактический результат | Доказательство |
|---|---|---|
| ZIP CRC / SHA / manifest lengths+hashes | PASS, 7/7 записей и8файлов | BASELINE_20, docs/task20/07_MANIFEST.json |
| `flutter pub get` | PASS, pinned lock unchanged | pub-get.log |
| `flutter analyze --no-pub` | PASS, no issues | analyze-final.log |
| `dart format --output=none --set-exit-if-changed <21 changed Dart files>` | PASS,0changes | format-check.log |
| `flutter test --no-pub --concurrency=2` | **514 PASS,2 SKIP,0FAIL**,4m02s | flutter-final.log |
| Новые scoped SQLite/contract/carousel/read/admin tests | **15 PASS** | target-final.log |
| Новые5widget + прежние2provider/client tests | **7 PASS** | widgets-final.log |
| `flutter test --no-pub --dart-define=SULFI_EDITION=client test/task5_client_build_test.dart` | **1 PASS** | client-flag.log |
| `node --test server/alchemist/test/*.test.mjs` | **54 PASS** (7новых) | node-final.log |
| `node --test server/google_apps_script/test/*.test.mjs` | **24 PASS** | legacy-node.log |
| Existing production SQLite scheduler + invariant checker, `javac/java` | **5 PASS**, pure JVM | scheduler-jvm.log |
| `node scripts/alchemist/build.mjs /dev/shm/task20-gas-drybuild` | PASS, no cloud operations | gas-drybuild.log |
| `flutter build bundle --debug --no-pub --target-platform=android-arm64` | **PASS MASTER**,25files/121393991B | android-bundle.log; bundle-master.json |
| Та же команда с `--dart-define=SULFI_EDITION=client` | **PASS CLIENT**,25files/121393991B | android-client-bundle.log; bundle-client.json |
| Native Gradle APK/signing/installation/upgrade | **NOT_RUN** | ограничения ниже |
| GitHub Actions PR check | **BLOCKED_ENV**,0steps | CI44933039652 / ci-annotations.json |
| Real GAS HEAD/config publication / real Google accounts /2phones | **BLOCKED_OWNER / NOT_RUN** | OWNER_PHONE_QA_20 |

Два SKIP общей suite: `task18_performance_test` opt-in measured benchmark (нет TASK18_PERF_OUTPUT) и `task16_live_cloud_test` (нет SULFI_LIVE_ENDPOINT). Они не выдаются за PASS и не перезапускались ради отчётности.

JVM5 проверяет неизменённые DatabaseTask/TransactionScheduler и прежний SchedulerInvariantCheck; compile-time Nullable annotation предоставлена простым stub. Это **не** Android SQLite runtime, не Kotlin instrumentation и не OS transfer proof. Kotlin/Android/third_party исходники не менялись; старые результаты №18/19 сохранены, заново не объявлены текущим native PASS.

Новые тесты: equal HEAD →0snapshot fetch, six intents →1existing durable task, atomic prepared/current, cold cache, A/B+package isolation, timeout/bad hash/stale response, exact dependency cycles, UTF8 Node/Dart golden, immutable/fail-before-flip/idempotency/CAS,100objects/20shared modules, ACL/privacy negatives, config revision/1..60, lost response and request reuse, concurrent saved edits, carousel3/7/1:1/N3/N4/N1/allunread, quiet refresh/reannounce, local legacy protection, true rendered/scrolled final page, explicit own-audio mark without listening, ContentLink resolver0calls, existing shared player/no read pause, MASTER tabs/CLIENT denial.

PNG `screens/home20-splash.png` и `home20-entry.png` — настоящие Flutter test renders720×1280 (360×640dp,2×). Синтетический пост и существующее утверждённое artwork. Это **не** снимки Android-телефона. Header/board/navigation rect equality проверена автоматически; физическая визуальная приёмка NOT_RUN.

## CI и ограничения сборки

[CI44933039652](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/44933039652) создан автоматически PR51. GitHub не выделил runner: jobverify имеет0steps, annotation: recent account payments failed / spending limit. Это не падение выполненных тестов. Billing не меняли, workflow не гоняли повторно. PRchecks поэтому не зелёные.

Обе Android-target bundles скомпилированы и имеют разные kernel SHA в JSON. Это проверка Flutter/Dart/assets, **не APK**: Gradle упаковка, Android plugins, signing и runtime не проверены. Локальный Gradle не повторялся после известного OOM №19: cgroup8GiB, root~146MB свободно и dangling прежний Gradle cache; /dev/kvm отсутствует. Новые APK20 не созданы/не выданы, APK28 не заменены. Не создавался новый debug signing key. Следующий native build только в пригодном runner с прежней signing-конфигурацией и новым согласованным versionCode.

## Промежуточные сбои, исправления и повторные проверки

Первый full run:509PASS/2SKIP/1FAIL — историческое ожидание «после Дочитано ещё обязательно слушать аудио». Обновлено под явное правило №20; legacy-compatible tests сохранены. Финальный полный прогон514/2/0 выше. Ограниченные widget diagnostics обнаружили unconstrained test width и await completed fake-zone future при переносе одного controller между fake/real zones. Исправлен harness с отдельной view; после этого5widget и provider регрессия PASS. Эти диагностические логи сохранены, но не объявляются успешной приёмкой. Повторные full/native CI без причины не выполнялись.
