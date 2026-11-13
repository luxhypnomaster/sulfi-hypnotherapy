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

## Native APK25→26: PASS controlled

[CI43403971950](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43403971950), native driver sourcec3b8f06b5fc600e5ab20af5424ae66d4702b9c86, APKproducer9b94f24: **13 PASS / 1 NOT_RUN**. Реальный Android35/KVM; неизменённая MASTER25 установлена без удаления. Через UI/system picker созданы3разных WAV,2одинаковых названия при разных IDs/bytes;2модуля (3трека и общийтрек+пауза5секунд),1программа с полным трёхтрековым графом, текущая композиция и1история interrupted. Пауза5сек установлена настоящим вертикальным жестом по bounds маховика и подтверждена в SQLite. Никаких SQL seed/подмены identity.

Штатный `adb install -r` подписанной MASTER26 поверх25: **PASS**. SQLite schema9/integrityOK; exact rows/IDs/граф/история/current и SHA медиа сохранены сразу после update и после cold restart. Все3трека и2модуля видны в UI, наблюдалось native AudioTrack started для UID приложения. Это не подтверждение слышимости человеком. Свежая CLIENT26 установлена в отдельный sandbox: новые надписи «Программы» PASS; обновление CLIENT25→26 здесь не выполнялось.

## Actual app fail-closed: 3 PASS

После healthy update использован тот же UI-created набор в одноразовом эмуляторе. Только в нём намеренно повреждён заголовок DB, затем DB перемещена в сохранённый backup, затем убран ready-marker. Во всех3состояниях приложение показывает безопасную ошибку, не пустую библиотеку; исходные файлы и медиа после приготовления fault неизменны по SHA, новая пустая DB не создана. FAULT_APP_16G.json хранит точные до/после fingerprints. Ничего не делалось с телефоном владельца.

5native JSON/PNG-подтверждений восстановлены из фактического полного CI лога с SHA-проверкой: NATIVE_LOG_READBACK_16G.json. NATIVE_UI_UPGRADE_16G.json SHA915d2d61a8f3bc3cfbd348181b6fa3264e617d36a78afebe4fc7f4a1756ba9f6; FAULT_APP_16G.json SHAf71c334200f0d79769b22f1c3f8b2dba25b798491f8e2392400ccaa706204c28. Снимки: screens/25-before-upgrade.png,26-library.png,26-modules.png,26-client-programs.png.

Полный CI43403971950 завершился FAILURE **только позднее**, на создании GitHub draft: GITHUB_TOKEN integration403. Native step SUCCESS подтверждён реальным GitHub API. Повтор Android/сборки не нужен: существующим авторизованным доступом создан один private draft444069048; отдельный delivery job переносит неизменную cached pair после проверки обоих прежних successful test steps и SHA receipts. Фактический результат скачивания/подписей — APK_READBACK_16G.json и RESULT_16G.md, не предположение об успехе upload.

## NOT_RUN: участие человека

Настоящие MASTER/CLIENT Google consent/restore/refresh; live GAS6→Drive publication/download; два diary drafts через авторизованный Android UI; физические Wi-Fi/mobile переключения; реальный микрофон; слышимость трёх треков; два телефона; обновление CLIENT25→26 с личными объектами; физическая приёмка MASTER25→26. Никакие fixtures, AudioTrack state или пустая diary-таблица не засчитываются вместо этих проверок. Старые тестовые объекты не восстанавливались по решению владельца; прежний root cause телефона UNKNOWN.

## Выдача и независимое скачивание: PASS

[Delivery-onlyCI43406075443](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43406075443) SUCCESS; источник721722fb18ed6aec9b188af78b92e1fb60c00a44. Нет повторного emulator/build/signing/Flutter suite. Actual native receipts и шаг предыдущегоCI проверены, прежние7app/testtrees1190989 идентичны. Одна неизменная параproducer9b перенесена в существующий private draft444069048.

ОбеAPK затем независимо скачаны с GitHub: SHA/размер/сертификат/package/версия26/compiledGAS6endpoint/WebClientID/nativeDexguardPASS. APK_READBACK_16G.json. MASTER193782021байт SHA0686e546e2d077768557b5c9f48c014d39e21567d798e403cb3040dd5fd3e05a; CLIENT193782061байт SHA0e9dee30d62b0a05097652d159ea0c035b4c1bad424e662516ede822dbe64a0c. Это signed debug QA builds со стабильной существующей подписью, не production release и не физически проверенные APK.
