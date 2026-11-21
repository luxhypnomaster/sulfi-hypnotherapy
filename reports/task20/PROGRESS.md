# №20 — checkpoint 0, 2026-11-21

Ветка feat/task20-catalog-vitrine от dca81961146747adc4a3f06107012df429ed747a (PR50 draft). Архив и все семь manifest записей PASS. PR48/49/50 не объединены; их код сохранён по ancestry.

BASELINE → HEAD-SNAPSHOT → CLIENT-SYNC → DIARY-LOCAL-READ → DIARY-HOME → MASTER-VITRINE → regression/evidence.

GAS6, OAuth, ACL, main, signing, данные и APK28 не менять. Auth19 OFF. Live HEAD/admin API отсутствует: только изолированный адаптер и честный BLOCKED live.

В работе: аудит классов/SQLite/SDD и адресные тесты. Android/CI/owner доказательства отдельно.

## Checkpoint 1
HEAD/snapshot изолированный Node adapter: light read, immutable prepare/readback, atomic commit boundary, scoped ACL, idempotency, CAS, config1..60. Не подключён к Router. SQLite lastGood sync использует существующие download tasks;6intents/1job/equalHEAD/no-full-fetch, scope/corrupt/atomic tests PASS. Local-only read namespace additive; legacy completed cycles перенесены без удаления, старый режим проверяется явно. Targeted Flutter26 PASS. HOME/settings код добавлен; widget/security/regression проверки в работе.

## Checkpoint 2
15 новых unit/integration +5widget и2прежних provider/client теста PASS. Исправлены: не сбрасывать полный круг при quiet refresh, сохранение новых drafts во время publish receipt, точный конец последней rendered/scrollable страницы; ContentLink не вызывает media resolver, собственное audio manual read не зависит от прослушивания. Верифицированный config может применяться из account-bound snapshot; draft save не применяется. Legacy catalog UI/production API сохраняются, snapshotTransport по умолчанию null. Первый full run509PASS/2SKIP/1старое ожидание FAIL; тест обновлён под новую явную отметку, legacy tests отдельно сохранены. Финальная общая регрессия и compile далее.

## Итоговый checkpoint — 2026-11-21
Source9e898024a51f23c602fe216784b0532e4bee90e4, draftPR51. Финальные514FlutterPASS/2SKIP,54Node+24legacy,5JVM, fixedCLIENT1, analyze/format clean. MASTER/CLIENT Android-arm64 Flutter bundles compile PASS, noAPK. Hosted CI44933039652 blocked billing/spending before0steps; retry не выполнялся. Матрица24:16PASS(local/injected/source),6PARTIAL,1BLOCKED,1NOT_RUN. Docs-only delivery checkpoint далее.

Drive folder13hLTnJEjQCx_SrNw4lEojOPA-ZPQX4q2 создана внутриFor_Codex; inheritedanyonewriter не менялся; туда только технические отчёты/screens, не APK/source/secrets. Native Gradle/KVM/realGoogle/ownerLive gates не пройдены. Возобновлять с интеграционных OPEN в ISSUES_20, не повторять ужеPASS локальные треки без изменения/новой гипотезы. ProductionGAS/main/Auth19/ACL/signing/APK28 сохранены.

## Доставка
13 файлов (10 отчётов/матрица, evidence ZIP и2PNG) загружены в папку №20 и независимо скачаны: полное совпадение байтов/SHA-256 и parent PASS. Этот PROGRESS загружается последним; окончательная машинная ведомость с SHA иDrive IDs — DRIVE_DELIVERY_20.json. EVIDENCE ZIP: 9c84eb101ab71bc5f8d7a0d4085b27d5c98925582226ef57d604f0d664eba211. Никаких APK/source archives наDrive.

Финальное сохранение — только docs/reports/README/BACKLOG commit с [skip ci], чтобы не повторять заведомо заблокированный hosted CI для неизменённого source9e89802. Это не PASS CI и не обход review; main не merge. Возобновление с OPEN integration/native/owner gates в ISSUES_20.
