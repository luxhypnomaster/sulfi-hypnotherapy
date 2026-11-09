# TASK_015 — точки продолжения

Ветка: feat/task15-pre-server-readiness. База №14: 9982df546aa032d014244df8f4483434294f350b. Не начинать задачу заново. Протокол: docs/task15/RESUME_INSTRUCTIONS.md. after_sha — коммит кода/результата gate; последующий metadata-коммит сохраняет эту запись, не меняя проверенный код.

## G0 — COMPLETE
- before_sha: 9982df546aa032d014244df8f4483434294f350b
- after_sha: 31b731a (docs/task15 baseline)
- PASS_IDs: BAS-01, BAS-02, BAS-03, BAS-04 (аудит и прежний restricted diff; окончательный CI BAS-05 наG6)
- PARTIAL_IDs: прежние №14 EXP-08/VER-02/CAT-03/CAT-04/CAT-06 остаются открыты, не переносить PASS на№15.
- open blockers: root был около9МБ; build cache без удаления перенесён вRAM, symlink build сохранён. G3 exact audio byte retention ещё не реализован. Live server запрещён. ФизическогоAndroid нет.
- touched files/tables: docs/task15/, никаких пользовательских таблиц/файлов. Архив №14 подтверждёнmetadataDrive в TASK_014.
- last tests: flutter test --no-pub test/task14_composition_test.dart test/task14_content_test.dart --reporter expanded — 4PASS; повтор всего379 baseline не нужен при неизменномSHA.
- next gate: G1 ACTIVE — occurrence A/B/C, отдельныйmarker, Home shield/shared sheet.
- next command: rg -n 'metadata refresh|moduleDiffersFromSource|_privacy' test/mvp_structure_test.dart lib/services/session_controller.dart lib/ui/library_screen.dart

## G1 — COMPLETE
Читать TASK_RU.md §1 и acceptance UI-01…UI-13. Не переписывать уже работающий CapsuleService/плеер. Проверить гипотезу: editor.reload обновляет durationMs всем старым экземплярам, но источник хранит прежний кеш длительности; новая копия C не проходит этот refresh. Прежде фикса написать regression с такой metadata drift и реальным A/B/C, persistence и Undo. Сохранить существующий тест metadata refresh.

G2: COMPLETE. G3: PARTIAL (safe slice committed; exact migration deferred). G4: COMPLETE local slice / K008 PARTIAL. G5: COMPLETE local conformance / CI artifacts in G6. G6: ACTIVE. SERVER_READY: NO до завершения P0. Отчёты: https://drive.google.com/drive/folders/1rq9fFTwMDmayx8M6eNdbIiNJALYLJwmS

### G1 checkpoint
- before_sha: 5177c62
- after_sha: bcedbb0dfd7b896e2d7e01eded57192d45638987
- PASS_IDs: UI-01…UI-13; BAS-03 restricted paths unchanged.
- PARTIAL_IDs: none for G1; source legacy ambiguity remains neutral by design.
- root cause: library duration cache refresh changed all old occurrences; semantic comparison now uses the same measured metadata for both source and occurrence. Exact sourceRevision persisted on new module instances; no source mutation.
- files/tables: composition_identity, ModuleCatalog/PhaseChild/SessionController, ChangedContentName, Home/Library/shared space_sheet; optional JSON fields only, schema remains9.
- tests: G1 reproduction failed beforefix [true,true] vs[true,false]; afterfix 13 unit/storage regressions PASS; UI11 PASS (9 sizes/scales +markers +clientEdition); legacy metadata-refresh/style2 PASS; analyze clean.
- evidence: /workspace/scratch/task15/g1-*.log, report/screenshots/g1-*.png.
- next exact step: G2 TASK_RU §2 + EXPORT_IMPORT_UX.md; inspect MainActivity saveZip hardcoded EXTRA_TITLE, add deterministic filename/UTC originalTitle, visible import using sameLocalCatalogSource. Do not rerunG1/full suite without cause.

## G2 — COMPLETE
- before_sha: f6af956
- after_sha: 62b6944dff769f4e0f29a9c2187f5a747d50a9f5
- PASS_IDs: EXP-01…EXP-11 (native physical SAF remains owner NOT_RUN; fake provider and native CREATE_DOCUMENT code verified).
- PARTIAL_IDs: none for G2 scope; exact multi-byte revisions are G3.
- touched files/tables: export_file_name, existing CapsuleService/LocalCatalog UI, shared sheet, Android EXTRA_TITLE, pinned unorm_dart0.3.2; no schema/table change.
- tests: new4PASS (300 Unicode unsafe names, date/UTF8/ZIP3audio+2pause/fresh import/repeat/conflict, fakeSAF suffix, actual UI import+preview); America/New_York timezone fixture1PASS; legacy capsules32PASS; old export menus1PASS; analyze clean.
- next gate: G3. Main risk paths: SessionEngine resolves3times bylogicalID, SessionController.snapshotForStart/replayIssues/current asset lookup, LibraryService.fileFor/initialize/discard, CapsuleService export/restore, LocalCatalogSource.installed/plan. Registry snapshots alone do not bind physical blobs or old exact readers. Inspect before invasive migration.
- next command: sed -n '195,225p' lib/services/session_engine.dart; sed -n '200,223p' lib/services/local_content_catalog.dart
- proposed safe G3 slice: verify ownership cleanup against retained revision hashes, correct missing-bytes vs metadata comparison, reproduce simultaneous audio version blocker and subprocess SIGKILL/reopen of existing importer. Do not introduce placeholder CAS tables or rewrite acceptedplayer to claim DONE. If exact binding cannot be proved across ALL readers, record MIGRATION_BLOCKER and continue independentG4/G5, SERVER_READY:NO.

## G3 — PARTIAL (safe stop, continue G4)
- before_sha: 17ee04d
- after_sha: ef78f09
- PASS_IDs: REV-07/08/09/10/11/12; REV-06 metadata missing-bytes fixed, physical cross-ID dedup not shipped. REV-01 not an audio migration claim.
- BLOCKED: REV-02/03/04/05, full REV-01/06 pending exact audio reader/storage migration. Concrete evidence: docs/task15/MIGRATION_BLOCKER.md, task15_revision_boundary_test.dart same-ID candidate safely refused.
- tables: audio schema9 and paths unchanged; startup retention honors old hash references; preflight storage breakdown only.
- tests: 34 PASS safe/legacy; actual separate-process SIGKILL+reopen/retry 2 PASS; analyzer clean. No power-loss or physical Android claim.
- next gate: G4. Read docs/task15/DIARY_AND_CLIENT.md and existing DiaryController/Reader/Editor/Audio; add reader-local state and publication metadata without live API changes.
- next command: sed -n '145,180p' lib/main.dart
- SERVER_READY: NO (P0 exact audio storage blocked).

## G4 — COMPLETE local slice / DAY-20 PARTIAL
- before_sha: b47132c
- after_sha: c94f95d
- PASS_IDs: DAY-01…19, DAY-21 local/unit/widget evidence (actual Android audio and live networking NOT_RUN). DAY-17 further two-store provider check onG5.
- PARTIAL: DAY-20 author DiaryReader preview is real and side-effect-free; Home media preview BLOCKED by unapproved K008 layout. No new media design.
- files/tables: DiaryPublication, DiaryReadStore app_settings namespace, DiaryController/Reader/Editor/Audio, exact picker, DiffPlan. No schema change; old root/readingState retained.
- tests: g4-final 8 PASS; g4-retest 38 PASS including 30 legacy multimedia; analyze clean. Screenshot evidence g4-*.png; no actual private media.
- next gate: G5, same-code client edition and independent stores FakeProvider; no live server. Add explicit clienttest Android suffix without changing author applicationId or signing. Keep provider injected, no HTTP default.
- next command: cat .github/workflows/checks.yml; cat android/app/build.gradle.kts
- SERVER_READY: NO (G3 + K008).

## G5 — COMPLETE local conformance, builds verified on final G6 SHA
- before_sha: 9ebc030
- after_sha: bfbfb56539ea36f2f134659c1afbb0e128c97ade
- PASS_IDs: CLI-01/02/03/06/07/08/09/10, SRV-02/03/04/05/06 local consumer tests. CLI-04/05 final APK diagnostics pending CI onG6.
- files/tables: same-code SULFI_EDITION=client companion .clienttest, default author ID retained; build18 version0.4.13, persistent CI key unchanged. Injected DiaryContractProvider/cache/outbox (no HTTP default), server role/ETag/idempotence/entitlement FakeProvider, canonical index shared by picker and ZIP.
- tests: g5-tests.log 10 PASS (G4 eight +two-store e2e/contract); client dart-define g5-client-build-tests.log 3 PASS; analyzer clean. Regression fixed initial completed-Future in fake-zone readstore load; no uninitialized reader crash. Screenshot g5-client*.png. Actual audio completion callback covered in G4; e2e uses deterministic completion fixture.
- touched tables: app_settings namespaced private outbox, existing diary_public cache and usual content installer. No audio schema migration, no live accounts/permissions.
- blockers: G3 exact audio revision coexistence; K008 Home media; physical Android and server remote NOT_RUN. No local mode is a server grant.
- next gate: G6. Write complete SERVER_HANDOFF schemas/playbooks, validate fixtures, full Flutter +Node suite once at stable source; final CI both APKs, PR, Drive report upload+readback.
- next command: mkdir -p docs/task15/SERVER_HANDOFF/JSON_SCHEMAS
- SERVER_READY: NO.
