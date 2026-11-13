# №16-Г — протокол фактических проверок

Дата: 13.11.2026 UTC. Полностью проверенный runtime/test source: `11909895da4f2967b77f12a8b8da98ff50b370d5`. Производитель неизменной пары APK26: `9b94f24f3e5302c20a96dce5a2e7bdc074c21a1c`. После него менялись только CI, native-драйвер и отчёты. Равенство семи Git trees (`lib`, `android`, `third_party`, `test`, `server`, pubspec.yaml/lock) проверяется в GitHub Actions перед повторным использованием регрессии и APK, а не принимается на доверии.

## Полная регрессия: PASS

[Verify job CI43350711471](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43350711471): **448 Flutter PASS, 0 FAIL, 1 opt-in live SKIP; 3 CLIENT PASS; 46 Alchemist Node + 24 старого дневника PASS**. Analyze, форматирование 176 Dart-файлов, schema/contract fixtures/негативные проверки PASS. Числа сверены с полным архивом лога: REGRESSION_16G.json, REGRESSION_CI_16G.json. Весь тот workflow завершился FAILURE позднее, при установке Emulator SDK: успешный verify job не называется успешным workflow.

Адресные проверки до полной регрессии: 11 storage; 10 auth/queue/roles; расширенная цепочка program/catalog — 1; 3 новых program/legacy widget + 23 существующих; 28 изолированных UI-fixture; 11 повторных проверок реальных прежних падений. Эти перекрывающиеся числа НЕ суммируются с 448 как независимые тесты. Подробности и все повторы — CODEX_EFFICIENCY_16G.md, CI_RUNS_16G.json.

## Хранение и совместимость

- 11 storage-тестов: отсутствующая DB при медиа/marker/sidecars, нулевой файл, повреждённый заголовок, неполная схема, неверный JSON, неизвестная версия, WAL, горячий rollback journal после прерванной транзакции, одинаковые названия при разных IDs/bytes, здоровое повторное открытие. Производственный preflight проверяет производную копию; SHA исходных DB/sidecars/media сравниваются до/после.
- [Android35 instrumentation43347643988](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43347643988): PASS, 148 секунд. Проверен точный production StorageSafety.java SHA62f94d95b95a20afe7998728616b433138684a9e5298f8aaaaf40e254a5d40f9. Healthy create/reopen; corrupt RW/RO дают SQLiteDatabaseCorruptException; исходные байты/sidecars сохраняются. Это disposable helper, не личная база владельца.
- Schema9/DDL/постоянные пути, template IDs/table/wire/ContentLink сохранены. Legacy capsule roundtrip сохраняет IDs, digest, граф и пользовательское старое имя. Правило PR46 допускает legacy scope только того же server-verified MASTER; другой account/CLIENT/guest запрещены.

## Авторизация, каталог и дневник: controlled PASS

Существующие shared SDK identity, singleflight restore/refresh, 401/403/DNS/abort, owner-bound queue/retry проверены без переписывания слоя. Расширенный тест использует настоящий Dart-клиент и production JS через loopback: модуль с тремя разными треками/паузами/обложкой → authoritative commit → программа со всеми зависимостями → запись дневника/ContentLink → текстовое обновление без повторной передачи неизменных бинарных файлов → выборочная CLIENT-установка точного графа, повтор без дублей. Это **не живые Google-аккаунты и не production Drive**.

## Native APK25→26 и ошибки bootstrap

Фактический итог текущего native CI, before/after/cold inventories, SHA медиа и разрешение/запрет выдачи пары добавляются в RESULT_16G.md. Первые инфраструктурные падения до запуска приложения не считаются испытанием обновления. Два прежних UI-драйвера остановились до обновления; сохранены отдельные receipts/screens. Последний выявленный дефект драйвера — клавиатура закрывала footer Save, несмотря на enabled semantics; исправление проверяет реальный mInputShown и не нажимает под клавиатурой.

## NOT_RUN: участие человека

Настоящие MASTER/CLIENT Google consent/restore/refresh; live GAS6→Drive publication/download; два diary drafts через авторизованный Android UI; физические Wi-Fi/mobile переключения; реальный микрофон; слышимость трёх треков; два телефона; обновление CLIENT25→26 с личными объектами; физическая приёмка MASTER25→26. Никакие fixtures, AudioTrack state или пустая diary-таблица не засчитываются вместо этих проверок. Старые тестовые объекты не восстанавливались по решению владельца; прежний root cause телефона UNKNOWN.
