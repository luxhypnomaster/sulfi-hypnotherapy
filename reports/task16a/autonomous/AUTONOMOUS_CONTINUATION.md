# №16/16-А — автономное продолжение

Дата: 2026-11-11. **Задание №16 остаётся открытым. APK24, GAS version6 и реальные данные сохранены.** Выполнены независимые безопасные исследования, регрессионные тесты и подготовка выдачи APK. Настоящие Google MASTER/CLIENT и физические телефоны не заменены тестовыми личностями.

## Откуда продолжено и что сохранено

Прочитаны свежие RESULT_CONTINUATION_24.md, ISSUES_AND_NEXT_24.md, ACCEPTANCE_CURRENT_24.md и PHONE_QA_24.md; проверены их metadata в существующей Drive-папке. Начальная контрольная точка c895291, ветка feat/task16-alchemist-full-server. C0 не повторялся.

- Исходник обеих существующих APK24: **cbe05240d463b9dafbe9a12ee831c967bdbf6113**, версия 0.4.16+24. В этом продолжении APK не собирались и не заменялись. Их существование/размеры/SHA подтверждены GitHub API и скачиванием неизменённых assets в CI.
- Master: 193 718 245 байт, SHA256 **a242d8222af27c936f44c86b47e2cf674c3789072c3a7cac9aa4bba3afe3cda1**. Client: 193 718 285 байт, SHA256 **352e8d087fd6c80f632e6d150b517ff07f41f492d01322e8443ff5fa784da8f1**.
- Сервер — прежний **GAS version6**, исходник **1a0cf8e5a60144075eec793767953586bfa319a2**, тот же Script 1810esAOGDfsUf6EYdT9y7uY5_v0dzBmb5YSfwPZkxtZJsKw_ByEre0Vc и deployment. Production deploy/изменение его данных в этой работе не выполнялись.
- Старый «Сульфи — дневник», private Drive storage, ACL, OAuth-конфигурация, signing key, main и ветка task16 не изменялись. Большой живой E2E повторно не запускался. Настоящие базы не открывались/не мигрировались. GC, удаление artifacts и публичные релизы не выполнялись.

## Изолированные исходники и PR

| Область | Ветка и точный исходник | Черновик |
|---|---|---|
| APK QA и документация | research/task16-autonomous; исполняемый harness e777d851ef0b2e40953f8884446b36c01485950c | [PR44](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/44) |
| G3 inventory/dry-run/rollback | research/task16-g3-revisions; **b76083df2ae7adc2d5a3e0c0fe05a3500d052626** | [PR43](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/43) |
| Drive RPC кандидат | perf/task16-drive-reads; **cd92f95cc44c11bddbc6985288f83b68fcb240ec** | [PR42](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/42) |

Все PR направлены в существующую feat/task16-alchemist-full-server, остаются draft и не объединены. Код G3 и оптимизация сервера не попали в текущие APK. Документационные checkpoints: 89454f5, 361525f; итоговые файлы сохраняются следующими коммитами этой же research-ветки. Точный SHA каждого CI указан в GitHub run, а не приписан более позднему docs-коммиту.

## 1. Android без настоящих аккаунтов

Локально /dev/kvm, adb/emulator отсутствуют; свободного диска недостаточно для SDK/AVD, поэтому локально они не устанавливались. На GitHub Ubuntu24 KVM доступен — hardware gate выполняется до скачивания system image. Используется Android35 google_apis x86_64, существующие APK23/24, SHA allowlist и disposable emulator с airplane mode. Реальные Google-аккаунты не добавлялись, роль в базе не подделывалась.

Фактический окончательный результат эмулятора: **PENDING_FINAL_EMULATOR_RESULT**. Подробные case-результаты будут зафиксированы в EMULATOR_QA_AUTONOMOUS.json. Гостевой restart не является проверкой authenticated logout. Наблюдение нативного audio player не означает слышимый звук на физическом телефоне.

Первые запускающие проверки выявили ограничения harness: private draft assets недоступны read-only integration token (403), холодный старт debug APK требовал ожидания SQLite, а adb shell терял quoting составного run-as. Они исправлены в тестовом сценарии, не в приложении. Ранний run 43100461153 завершился SUCCESS при BLOCKED cases: он **не считается QA PASS**. После удаления системного препятствия выявлен неполный тестовый JSON шаблона (description/isDefault); он заменён сериализацией реальных моделей и проверен roundtrip через их fromMap/toMap. Это ошибка фикстуры, не данных владельца. Прежние зелёные jobs с недоступным UI не считаются функциональной приёмкой. Теперь install/seed/update/client требуют ещё и готовый интерфейс приложения, при ошибке job завершается с отказом.

Workflow допускает emulator job только для manual workflow_dispatch в точной research-ветке этого приватного repository. Для GET draft assets нужен transient GITHUB_TOKEN contents:write; actual release/ACL mutations не выполняются. OAuth/clasp/signing secrets этому job не передаются, credentials checkout не сохраняет. Используемый emulator action закреплён по полному SHA.

## 2. G3 — результат и пределы

**8 новых + 3 существующих boundary-теста: 11 PASS локально. Финальный CI 432 Flutter PASS; прежний CI431 сохранён отдельно.** Реализованы readonly inventory с проверкой bytes/SHA/size, plan fingerprint и blockers; dry-run; отдельный VACUUM INTO backup и sandbox DB; immutable revision/ref/head таблицы; exact(logicalId,revisionId,blobSha) без fallback; переключение head на B при сохранении history A; rollback в отдельную проверенную копию.

Фикстура: 2 ревизии одного ID, 2 blob, 2 pinned refs, 0 записей в source. Проверены active session, stale plan, ambiguity history/metadata, повреждённые blob, injected pre-commit crash и SQLite integrity. G3_DRY_RUN.json относится только к синтетической Fixture15, не к базе владельца.

**Продуктовая G3 ещё не внедрена.** Нынешняя защита SqliteLibraryRepository.save от подмены байтов тем же ID сохранена. До её снятия нужны exact readers в session/history/preview/library/module/template/capsule/install/startup, consistent backup+lock и crash/no-space матрица. Полный список — G3_RESEARCH.md. Исследовательский rollback не обещает восстановление настоящего телефона.

## 3. Производительность GAS/Drive

| Локальная измеренная передача | version6 fixture | Кандидат |
|---|---:|---:|
| Байты / chunks |1048617 /5|1048617 /5|
| Metadata RPC |15|10|
| Permissions RPC |15|10|
| Range reads |5|5|
| Всего RPC |35|25|
| Полный SHA и точные байты |PASS|PASS|

Сокращение **28,57% обращений** на verify-проходе загруженного файла. Обычный download-путь и количество его RPC не оптимизировались; ускорение скачивания не заявляется. Удалена повторная проверка того же файла внутри chunk: объединённый read проверяет parent/file ACL, owner, MIME/size непосредственно перед Range. Между chunks ACL не кэшируются; SHA не ослаблен. Отзыв folder/file доступа, смена owner, неверные MIME/size и отзыв после завершённого прохода отвергаются до новых bytes. **45 Node PASS**, GAS source build PASS.

Это operation counts реального adapter в VM с контролируемым Google SDK double, **не новое время живого Drive**. Fixture GasTransfer.version6.js byte-identical файлу server6:SHA256 1bcb447ded5321bbde20dd3f5533e77e61e86bd182d5119a3b1b2e099e51a7d7. Исторические 51:42 / 193 API и max publish 67,910 s не являются временем чистого скачивания и не позволяют вычислить новые секунды. Production сравнение — NOT_RUN, нужно отдельное разрешение на ограниченный live-контроль.

Дополнительно найдены повторный byte-readback immutable index при setHead и затраты числа snapshot commits. Их оптимизация отложена: экономить на ACL/SHA/атомарности нельзя. Подробности и воспроизводимый счётчик — PERFORMANCE_RESEARCH.md/PERFORMANCE_COUNTERS.json.

## 4. APK для тестировщиков

Проверено: существующий release 442038688 всё ещё private draft; anonymous HTTP 404, read-only integration download 403, разрешённый owner-capable job скачивает и проверяет прежние SHA. Draft-ссылка не является общедоступным каналом выдачи. Actions artifact quota исчерпана; старые artifacts не удалялись, release assets остаются на месте.

Уже возможный бесплатный способ: владелец Android скачивает два файла через свою GitHub-сессию, клиентский APK передаёт через Quick Share/Bluetooth. Тестировщику не нужны GitHub-аккаунт, исходники или токен. Google Drive для APK не используется. [Существующая страница обеих APK24](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/tag/untagged-9962b11f7ce0aa819785).

Для самостоятельных ссылок подготовлена схема отдельного public binary-only repository без source/secrets; **не создавалась/не публиковалась**. Нужны отдельное разрешение владельца и review содержимого. Согласно проверенной справке GitHub: каждый asset < 2 GiB, до 1000 assets; APK ~185 MiB подходят. APK_DISTRIBUTION_PLAN.md содержит точные шаги и ограничения, manifest фиксирует bytes/package/cert/SHA.

## 5. Проверки и CI

| Проверка | Фактический итог |
|---|---|
| [G3 CI 43105927067](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43105927067), b76083d |SUCCESS: 432 Flutter, 43 Alchemist Node, 24 legacy Node, 3 CLIENT; analyzer/format/contracts/source build PASS |
| [Perf CI 43102167730](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43102167730), cd92f95 |SUCCESS: 424 Flutter, 45 Alchemist Node, 24 legacy Node, 3 CLIENT; analyzer/format/contracts/source build PASS |
| G3 targeted |11 PASS; flutter analyze --fatal-infos: No issues found |
| Python harness syntax |py_compile PASS |
| Новая сборка APK |NOT_RUN — APK24 сохранены по заданию |
| Deploy нового GAS / повтор большого live E2E |NOT_RUN — не разрешён/не нужен |
| Реальный Google MASTER/CLIENT |NOT_RUN; BLOCKED до участия двух настоящих пользователей |
| Physical update, звук/BT/lockscreen, authenticated logout |NOT_RUN; BLOCKED до двух устройств |

Тесты двух веток не суммируются как уникальные: финальная G3 содержит 424 старых + 8 новых; 45 Node включают 43 старых + 2 новых. Старый backend тестируется локальными doubles, его живой проект не вызывается. Краткие извлечения actual CI и targeted log приложены. Исходная 147-критериальная матрица ACCEPTANCE_CURRENT_24 сохранена; автоматический research не превращает её физические/Google пункты в PASS.

## Что можно принять сейчас и что отложить

**До физических тестов:** после code review принять документацию, протокол безопасной выдачи неизменённых APK, дополнительные регрессионные тесты и изолированный G3 sandbox. Продолжать точные readers отдельной веткой, не снимая save guard. Performance candidate готов к review, но не к самовольному production deploy.

**Отложить:** настоящую миграцию G3/GC, замену APK24, live-внедрение оптимизации без разрешения, публичные ссылки без разрешения, закрытие Google/двухтелефонной приёмки. Задание №16 не объявляется завершённым.

**Первый шаг владельца, когда появится возможность:** прежняя мастерская APK24 → «Дневник» → «Подключение и права» → «Войти через Google» под аккаунтом владельца → «Проверить права на сервере»; сообщить текст результата. При конфликте установки не удалять приложение/аудио. Второй телефон подключается затем. Компьютер, пароль/токен в чате и повторный clasp-login не нужны. Полный сценарий: PHONE_QA_AUTONOMOUS.md.

Отчёты добавляются в существующую [папку №16](https://drive.google.com/drive/folders/1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z), старые файлы сохраняются. DRIVE_UPLOAD_INDEX_AUTONOMOUS.json содержит проверенные IDs/размеры/parents новых файлов. После завершения uploads выполняется metadata readback и byte-проверка итогового отчёта.
