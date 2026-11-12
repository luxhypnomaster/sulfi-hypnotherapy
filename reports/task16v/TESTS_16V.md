# №16-В — проверки и границы

## Код / локально PASS

- `flutter pub get --enforce-lockfile` — PASS, pubspec.lock без изменения.
- `dart format --output=none --set-exit-if-changed lib test` — PASS,173 files без изменений.
- `flutter analyze --fatal-infos` — PASS.
- Полный `flutter test --reporter json` — **434 PASS / 1 intentional opt-in live SKIP**, failures0. FLUTTER_SUMMARY_16V.json + logs/flutter-tests.jsonl. Пропущенный live тест не объявляется пройденным, production E2E не повторялся.
- CLIENT defines: `task5_client_build_test.dart`, `task15_client_test.dart` — **3 PASS**. Это fixtures, не реальные Google пользователи.
- Node Alchemist security/domain — **46 PASS**; old diary — **24 PASS**, серверный код не менялся/deploy не выполнялся.
- Python read-only diagnostic — **9 PASS**: intact WAL rows, unchanged source .sqlite/WAL/SHM bytes, absent DB not created, corrupt DB not reset, missing media references preserved, invalid JSON preserved, external path not followed (отдельные assertions объединены в6 cases).
- Legacy scope regression — RED на исходном25, GREEN с узким patch; две controlled subjects, CLIENT/guest deny, exact original diary row/order/media bytes retained. Подробные RED/GREEN logs.

## CI PASS — именно автоматические регрессии

- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43255233809 — success, source47fe11c.
- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43255433079 — regressions job success, source0aecc56:434/analyze/format/Node/Python/CLIENT. Native job completion этого run НЕ preservation PASS (сценарий создания заблокирован).
- Dart/Android/pubspec/server tree последующих checkpoint совпадает с протестированным source; CI_EVIDENCE_16V.json фиксирует проверку. Изменения harness/docs не выдаются за новую сборку приложения.

## Native / Owner

Итог native UI-created baseline/update проверок — UPGRADE_REPRO_16V.md и machine-readable inventories. Оригинальные неудачные harness runs сохранены. Пустой before-state нельзя засчитать. Google auth не подменялся fixtures в APK. Ни physical owner sandbox, ни реальный Google MASTER24 UI diary, ни все lifecycle B/C, ни owner recovery не испытаны: BLOCKED.

Новая Sulfi APK26 не построена. Вспомогательная Instrumentation APK — только отдельный test helper на disposable CI emulator, не продукт/не recovery-кандидат/не для владельца; Sulfi package/certificate не меняет и никакого доступа к данным владельца не имеет. Подмена результатов физического Android отсутствует.

## Native dependency fault probe

Run43259518712, controlled **helper-only** DB: default RW corruption changes SHA without exception; readonly noop-handler retains SHA and throws corruption. Source/binary/runtime механизм подтверждён. Это не native UI upgrade сохранность и не owner RCA/recovery. Никакой DB injection/corruption в Sulfi для этого probe не выполнялась.

Последние3 Python cases расширяют первоначальные6: нулевой rollback journal inventory, hot rollback journal после SIGKILL незавершённой транзакции (недеструктивный readonly отказ на derivative copy), symlink audio directory not followed. Исходные DB/sidecars сохранены byte-for-byte. Это локальные controlled tests, не owner recovery.
