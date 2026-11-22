# №23 v1.1 — фактические проверки

Дата: 2026-11-22 UTC. Проверяемый исходник приложения/тестов/инструментов: **`5fae671c9829c021151e3c9e6ed0467692a7867a`**. Последующие коммиты изменяют только отчёты; CHECKPOINT содержит tree-хеши и проверку этого утверждения. Среда: Codex Cloud Linux, Flutter3.47.9/Dart3.13.7, Node24.19, Python stdlib SQLite + sqflite_common_ffi. Не Android runtime.

| Проверка | Фактический результат | Доказательство |
|---|---|---|
| ZIP7718B, SHA/CRC, 7 файлов, manifest6 hash+bytes | PASS; SHA `123d4bd298ebecc92176eec44fed718eecc6f04b09472e10ca197e3627d46a69` совпал с независимой оперативной записью | ARCHIVE_23.json; SOURCE_GATE_23.json; `check_source.py --archive ...` |
| `flutter pub get --offline` | PASS, pubspec/lock не менялись | logs/pub-get.log |
| Исходные негативные repro до исправления | **4 FAIL/0 PASS ожидаемо**, assertions подтверждают дефекты, не compile failure | logs/repro-red.log |
| Те же воспроизведения после исправления | **4 PASS** | logs/repro-green.log |
| Capsule/migration адресно | **37 PASS** | logs/g1-targeted.log |
| Дополнительная сохранность | **11 PASS** | logs/preservation-g2-final.log |
| `python3 -m unittest discover -s scripts/task23 -p 'test_*.py' -v` | **13 PASS** (9 copy/recovery, 4 plan-only/source/version) | logs/python-final.log |
| `dart format --output=none --set-exit-if-changed ...` изменённых Dart-файлов | PASS, 7 файлов / 0 изменений | logs/format-final.log |
| `flutter analyze --no-pub` | PASS, No issues found | logs/analyze-final.log |
| `flutter test --no-pub --reporter expanded` | **554 PASS, 2 SKIP, 0 FAIL**, один полный прогон после заморозки кода, ~7m30s | logs/flutter-full.log |
| Protected source / diff / `git diff --check` | PASS, 43 файла №22 неизменны; нет diff Android/server/workflows/pubspec | SOURCE_GATE_23.json; TASK22_PROTECTED_23.json |
| Native prerequisites read-only и будущее расписание | PASS_SOURCE/план, не build | FUTURE_RELEASE_PLAN_23.json; native_source_pins.json |
| Новые hosted CI / Actions APK | **не запускались**, ветка Task23 total_count0 | GITHUB_BASELINE_23.json; GITHUB_DELIVERY_23.json |
| APK/AAB, Gradle, emulator, install-r, новые cert/manifest bytes, два телефона | **DEFERRED_BY_OWNER** | OWNER_PHONE_QA.md |
| Live Google / production GAS / изменение Drive storage/ACL | **NOT_RUN / NOT_CHANGED** | scope audit; это не требуется для локальных фикстур |

Два SKIP не добавлены заданием №23: opt-in TCP benchmark №18 и live-cloud №16 без `SULFI_LIVE_ENDPOINT`. Никаких реальных Google/серверных credentials для них не загружали, не имитировали live PASS. Контролируемые локальные JS/HTTP fixtures из существующих тестов исполнились в рамках Flutter, не против GAS production.

## Новые содержательные сценарии

- Отказ headless-create до возникновения пустого SQLite и old-schema до RW original open.
- Schema6/7/8→9 и 9→9 на изолированных копиях: три файла, модуль, паузы, программа, текущая конфигурация, frozen run/checkpoint, offline draft, capsule ZIP, unknown bytes. Два холодных открытия без Google; raw IDs/payload/old-column values/SHA сохраняются.
- Другая SQLite под альтернативным именем не выбирается автоматически и не сопровождается новой пустой заменой.
- Роль MASTER без scope proof не экспортирует A/B private; существующие точные legacy/current aliases разрешают только одного владельца. A→B, logout и malformed hint не удаляют строки/байты. Expiry/offline cold restore дополнительно покрывают существующие №16/17 тесты.
- Mutable preview после inspect и на beforeCommit отвергается; transaction/новые материализованные файлы откатываются; original bytes не заменяются. Stale alreadyImported preview после изменения audio не скрывает проблему успехом.
- Смена owner во время ZIP и missing media отклоняют экспорт, сохраняя DB и прежние файлы.
- Snapshot-tool dry-run не создаёт цель; SHA/owner/path/link/missing/extra/tamper/corruption/изменяющийся источник/overwrite/nested target отрицательны. Отдельно WAL-only committed rows реально извлекаются из копии без SQL-write оригинала.

Полный suite также содержит старые capsule conflict/cancel/concurrent DB token, legacy6/7/8 roundtrip, точные зависимости/selective filenames, историю, interrupted journal, worker queue/idempotency и 13 исходных тестов №22. Их не переписывали ради зелёного результата.

Повторы были адресными: первый новый preservation-файл исправлен после двух compile-опечаток (`ModuleCatalog.load`, `topicText`); затем расширен двумя дополнительными сценариями. Первые lint-замечания (braces) устранены. Полный suite запущен **один раз** после этих изменений, native/CI повторов нет. Финальные отчёты содержат успешные логи и первоначальный RED как доказательство; промежуточные compile/style логи не выдаются за проверку приложения.
