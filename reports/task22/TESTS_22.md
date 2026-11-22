# Проверки №22 — фактические уровни

Кодовая точка `a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde`; ветка `feat/task22-server-ratings-admin`, base PR52 `40b7c59e67921f456c3c5a4e943bd40f7232f336` → PR51 `a7c29a7b478b6c3b001d70d3158b4a65d57b3c50`. PR51/52 OPEN DRAFT, не merged. main `b88637a105b2182c7b836311ebb3de7ad037b08f` не менялся. Draft PR22: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/54.

Среда Flutter3.47.9/Dart3.13.7,Node24.19,node:sqlite/SQLite FFI,Linux. Все данные disposable synthetic. Ни Google-user login, ни Android-device E2E это не заменяет.

| Команда/проверка | Результат | Evidence |
|---|---|---|
| python3 scripts/task22/verify_input.py ARCHIVE |13files/CRC/12manifest hashes+sizes/docs bytes PASS | ARCHIVE_INTEGRITY_22.json |
| flutter pub get --offline | PASS, pinned pubspec/lock неизменны | logs/pub-get-resumed.log |
| flutter analyze --no-pub | PASS, No issues | logs/analyze-delivery-source.log |
| flutter test --no-pub --concurrency=2 | 539 PASS / 2 SKIP / 0 FAIL | logs/flutter-full-final.log |
| Node --test server/alchemist/test/*.test.mjs |79PASS | logs/node-full-final.log |
| Node --test server/google_apps_script/test/*.test.mjs |24PASS | logs/legacy-node-final.log |
| Новые server22 targets |17PASS, входят в79 | logs/final-overview-target.log |
| Новые Flutter models/runtime/UI/priority |12PASS восстановленного target; затем UI/runtime8PASS после batch UI;13 новых тестов в full | logs/recovered-target.log;target-ui-batch.log |
| node scripts/alchemist/build.mjs /dev/shm/task22-gas-drybuild | PASS, no cloud operations;22 не включён в GAS | logs/gas-drybuild.log;SOURCE_PURITY_22.json |
| node scripts/task22/release_readiness.mjs | PASS, inspect-only, versionCode28 сохранён | logs/release-readiness.log |
| Hosted CI | NOT_RUN №22; прежний run44959026009 billing0steps не PASS | CODEX_EFFICIENCY_22.md |
| Existing endpoint GET health |200/JSON, READONLY only | LIVE_READONLY_HEALTH_22.json |
| Live GAS22/private Drive full restore/real Google | BLOCKED/NOT_RUN | SERVER_BASELINE_22.md |
| APK/bundle/native Gradle/cert/emulator/phone | DEFERRED_BY_OWNER, не запускались | OWNER_QA_22.md |

## Что именно доказано
- Реальный SQLite WAL: cold receipts, lease race/fencing, changed request conflict, lost response after COMMIT, bounded retries, one redacted incident. CAS/concurrent legacy21 и transaction tests входят в полном Node suite.
- Полный disposable server SQLite+роль+feedback+heads+реальный файл зашифрован/считан/восстановлен в другой новой директории; cold readback и SHA совпали. Тестовый private destination — interface fake, не Google ACL proof. Настоящий GAS backup не заявлен.
- Loopback TCP→тот же API broker→существующая queue18→Node SQLite; six refreshes→one overview/overlay; equal revision→zero new snapshot; owner A→B cache скрывается,403 скрывает privileges,503 lastGood сохраняется.
- Local feedback opt-in→receipt→lost-response retry→correction/revoke→new independent ratings overlay; non-app_settings tables и исходные media SHA не меняются. Private notes отсутствуют в wire.
- Pure playback interval union и actual SessionEngine+fake audio transport с настоящим local DB/media: seek не делает8000ms прослушанными; это controlled transport, не native playback.
-15MiB synthetic файл + blocking task + actual metadata HTTP: active task не вытесняется, metadata обгоняет waiting file только на dispatch boundary; SHA сохранён. Это не15MiB network benchmark и не Android audio/lock proof.
- Flutter-rendered PNG720×1280 показывает реальные fixture counters и unknown quotas. Это не screenshot с телефона. Optional form не меняет Completed history; course/batch UI подтверждают actual persistent server receipt, repeat без дубля.

Два исторических SKIP: opt-in live cloud без credentials и performance18 без output flag. Они не PASS. Предыдущий временный workspace потерян при перезапуске: recovery targets запускались заново; syntax/lint recovery failures и их исправления сохранены отдельно. Полные прогоны повторены после подтверждённых receipt/revoke и wire-order ошибок; одинаково неуспешных полных CI или native прогонов не было.

## Итоговый исходник и дополнительные проверки

Итоговый code source a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde: полный Flutter539PASS/2SKIP/0FAIL завершён4m28s после всех изменений. Предыдущие54c1932 и9113800 полные прогоны сохранены отдельно, но не подменяют этот final. Node79 запущен на52ea01c; все Node bytes вa5a4c77 идентичны ему. Legacy24 source не менялся. Послеa5a4c77 — только docs/evidence/delivery, без новых app/server changes.

Последний all22 target13PASS,CLIENT define1PASS,analyze No issues и format26files/0changes: final-all22-target2/client-flag-final/analyze-delivery-source/format-final logs. Их не прибавлять к539. Ошибка промежуточного final-all22-target была реальной зависимостью UI от canonical JSON key order после кеширования; исправлена явным приоритетом mini-KPI, ожидания теста не ослаблены.

Существующий production endpoint GET health(read-only): HTTP200/JSON/name/schema1/source stamp; не administrative version proof, не authenticated API E2E. SCRIPT metadata:shared=true при единственном видимом owner permission, private ACL не подтверждён; права не менялись. Доказательства отдельные LIVE_READONLY_HEALTH/SCRIPT_METADATA_READBACK.
