# №23 — P0 сохранность данных Android и подготовка воспроизводимой native QA (без сборки APK сейчас)

## Цель
Найти и устранить сохранившиеся реальные риски потери/невидимости личных данных после штатного обновления MASTER/CLIENT, а также ПОДГОТОВИТЬ документированный будущий APK native gate без преждевременной сборки. Максимум доказательного кода без новых продуктовых обсуждений.

## A. Preservation / P0 data integrity
1. Read-only review PR46, PR47, PR48/49/50/51, existing SQLite schema9, startup bootstrap, corruption handler, cleanup/GC, account-bound namespaces, restore, migration/recovery and test fixture coverage.
2. Reproduce in synthetic/copy sandbox the MASTER24→25 failure: user-created audio/tracks/modules/templates, offline local diary drafts, history, capsules became invisible after update; do not assume physical bytes erased. Explain what is proven and unknown.
3. Add invariants/tests for app update, cold start, expired/no Google session, account swap, malformed preferences, DB corruption, missing media, duplicate alias, sideload same applicationId and increased versionCode. Personal data must never be reset because cloud auth is not ready.
4. If root cause is demonstrated, implement smallest additive/non-destructive correction and read-only legacy recovery path. No speculative cleanup, no overwriting user-owned files, no migration that destroys past schema. Keep rollback/readability.
5. F-010: audit existing selective export/import/capsule semantics. Implement narrowly scoped, backwards-compatible safety repairs only if objectively proven incomplete: verified manifest/exact ID revisions, filenames, transactional/dry-run import, explicit duplicate/conflict policy, userSelected entries. Do not invent new personal cloud sync.

## B. Native Android reproducibility
6. Independent native build/safety gate: confirm exact Flutter/JDK/Gradle/Android SDK/toolchain, source ref, appIds, native Kotlin/plugins, signing fingerprint and versionCode policy from existing builds. Do not create a new signing identity, clear app data, downgrade, or claim an ARM bundle is an APK.
7. Provide reproducible future native build commands/README/test protocol and verify versionCode/signing requirements by read-only source checks; do NOT execute a native Gradle build, GitHub Actions build, simulator run, or sign APK during task23. CI billing status may be noted once but need not be remedied here.
8. Produce synthetic APK upgrade/no-clear acceptance plan, adb read-only checklist and ready/deferred report; NO APK artifacts, emulator runs, phone changes, or distribution in this task. Device QA postponed to the future release stage.

## Scope boundaries and parallel ownership
Primary ownership: local DB recovery, capsule integrity, migration tests, read-only native build prerequisite audit and future scripts/checklist, Android QA documentation (no executable native build). No changes to server/GAS, catalog HEAD, ratings, admin panel, course scheduling, authentication19 provider/ACL or diary carousel. If a changed file overlaps active #21/#22, do not overwrite; isolate patch, mark dependency, stage as independent draft PR for later rebase. #22 may address wider release integration; coordinate from latest base and do not duplicate completed native work.

## Deliverables
Draft PR `feat/task23-data-integrity-native-qa`; `reports/task23/{RESULT,TESTS,ISSUES,CHANGES,MIGRATION,OWNER_PHONE_QA}.md`; runnable checks and observed source sha. Backup/restore tooling must support dry-run, verifying owner and checksums. If no real device/build available, substantial unit/integration tests and harness still count only at their real level.
