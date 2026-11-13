# №16-Г — фактические проверки

## PASS controlled

- Пакет7files/6MANIFEST digests/33criteria:1проверка G0. PR45/46 ancestry/diff: общий APK25 source012f7f69; бранч16G отb0cb53f. Исторические full audits не повторялись.
- Storage11tests: missing DB+media/marker/sidecars, zero-byte, corrupt header, partial schema, invalid JSON, unknown version, WAL derivative read без source writes, healthy same-title/different-ID graph reopen, hot rollback journal после прерванной транзакции. Exact DB/sidecars/media fingerprint equality на отрицательных кейсах. G1_STORAGE_FINAL.log.
- Реальная Android35 instrumentation exact StorageSafety.java: run43347643988 SUCCESS, source1391b0334e2ffcca47d05e5ec94c5727a9234666,148sec. Healthy create/reopen; corrupt RW и RO throw SQLiteDatabaseCorruptException, originalSHA/sidecars untouched. NATIVE_STORAGE_16G.json. Helper-only disposable DB, не owner sandbox; production source SHA pinned перед candidate build.
- Existing auth/queue/role targeted10PASS. Extended catalog program test1PASS: actual Dart+production JS черезloopback, module3differenttracks+pauses → authoritative program catalog commit → diary text update no retransmission → CLIENT exact selective install. Fixtures не реальные Google credentials.
- G3:3new legacy/capsule/MASTER+CLIENT program widget tests +23existing diary/workspace=26PASS. Legacy user custom name/ID unchanged, internal template wire/digest preserved.
- G4fixture isolation target task4_ui+task5_ui:28PASS,59sec; новый guard не ослаблен. Отдельные test failures/повторы учтены CODEX_EFFICIENCY, не скрыты итоговым PASS.
- Final local analyzer PASS;176Dart files format PASS. Полный Flutter/Node exact-source CI и native APK25→26 фиксируются после завершения отдельно.

## NOT_RUN / не заменять fixtures

Настоящие Google MASTER+CLIENT consent/restore/refresh, production Drive publication/download, физическое Wi-Fi/mobile переключение, реальный микрофон, слышимость всех3треков человеком, два телефона и owner future-data25→26 приёмка. Старые тестовые объекты не восстанавливаются по решению владельца13.11. Root cause прежнего телефона UNKNOWN не переписывается.

## Финальная полная регрессия — реально PASS

Verify job CI43350711471 source11909895da4f2967b77f12a8b8da98ff50b370d5: **448FlutterPASS/0fail/1opt-inliveSKIP,3CLIENT,46Alchemist+24legacyNode**, analyze/format/schema checksPASS. Полный workflow тогда FAILED только на поздней установке Emulator SDK (No space left), уже после успешной сборки/cert проверки пары; это НЕ общий CI PASS. Raw archive logs прочитаны, REGRESSION_16G.json и REGRESSION_CI_16G.json фиксируют границы. Built pair193782021/193782061bytes NOT_ISSUED, private draft не создавался.

Новый candidate CI43354403069 source78d6b5cacbc5c985b260bb4b986f59b4094f1591 проверил actual GitHub verify-job success и равенство7Gittrees приложения/Android/vendor/test/server/pubspec с1190989; полные тесты не повторялись. NativeStorage callbackSHA тот же, что G1 native proof433476. Исправления после1190989 касались CI resource/evidence gating и отчётов. Результат native25→26 и новой pair readback будет добавлен отдельно.
