# Current checkpoint — C1.6 / C3 vertical slice (2026-11-10)

C0 remains COMPLETE, not repeated. Repository CLASPRC_JSON is present and LIVE read-only verification succeeded from trusted main: Actions run 42792367833, identity marker and script-list marker verified. The old AUTH_PENDING lines below are historical; current clasp authorization is VERIFIED, not missing.

Implemented canonical cross-language content manifests, persistent deduplicated media aliases, lost-final-PUT reconciliation by preallocated Drive ID, author track/module/template publication editor and local outbox, client catalog with explicit selective install through existing LocalCatalog/CapsuleService. Durable download checkpoints now live outside disposable capsule workspace. Tokens cached only in RAM; concurrent chunk operations share one SDK login and logout invalidates pending login. No changes to RunScreen/art or destructive data migration.

Verified: Node 14 PASS; Flutter cross-language integration and identity tests 2 PASS (real SQLite/Dart + production JS domain via local HTTP, injected Drive byte adapter). Includes track→module selective download, two pauses preserved, deduplicated upload, metadata-only edit, lost publish response/restart receipt, withdrawal with offline copy preserved. This is NOT a live Google Drive/Android E2E.

In progress: Operations.js admin/sync/audit extension needs dedicated tests; full diary/video/package integration, full-suite CI/two APKs and production deployment remain unfinished. Additional configuration blocker: Android Google Sign-In web client ID is absent from repository build variables; clasp deploy OAuth is separate and must never be embedded in APK. Continue independent implementation. SERVER_LIVE=NO, FULL_CODE_IMPLEMENTED=NO, FULL_E2E=NO. No production source deployed or new GAS project created.

# Latest resume — user continuation, repository OAuth now present

Continue existing C1.5; do not repeat C0. User confirms completed clasp and repository-level CLASPRC_JSON. Secret NAME verified via gh secret list, not value. Auth check only workflow added to main via workflow-onlyPR18 (owner specifically requested trusted main execution); commit8bb3d2d4a52366c69fc248304b6194cb1a08c887. No server/app source merged into main. Manual check running; actual OAuth result must be recorded, not inferred from secret presence. No environment secret. All secret-bearing workflows now restricted manual main-only; production still blocked until complete source/tests/readback.

# TASK16 checkpoints

C0 COMPLETE; база b599df6, ветка feat/task16-alchemist-full-server. См. PREFLIGHT.md (сохранён ДО моделей). Архив20/147verified. Node24PASS, baselineCI411PASSverified. AUTH_PENDING: repo CLASPRC_JSON отсутствует, environment отсутствует. Ни нового Script/Drive root/deployment, ни secret/OAuth actions не выполнялось. Старый дневник не тронут.

C1 ACTIVE: catalog/storage backend +tests. C2–C5 NOT STARTED. FULL_CODE_IMPLEMENTED=NO; SERVER_LIVE=NO; FULL_E2E=NO; APK_BUILT task16=NO; Android NOT_RUN. Не сокращать147критериев. Следующая команда: node --test server/alchemist/test/*.test.mjs после создания source. G3 retain fail-closed until proven migration. Создание production требует реального CLASPRC_JSON; без него продолжатькод.

## C1.1 — domain implementation checkpoint (C1 remains ACTIVE)
- before_sha:458e8a8; C0 commit complete before model edits.
- Implemented Catalog.js (typed annotations, lifecycle, ETag/idempotency, exact DAG/missing-byte plan, public listing), Storage.js (prescribed40paths, ACL/exact-name/registry guards), Transfer.js (bounded aligned chunks, retry/hash/actor/revocation guards).
- Node5PASS; VM executes same GAS source, five publication types in scenario loop. These are UNIT tests, not live. No C1 COMPLETE claim: see server/alchemist/IMPLEMENTATION_STATUS.md atomic receipt/persistent adapters requirements.
- env: npm cache filled root; cache preserved in RAM with symlink, retry with explicit RAM npm cache. No user data removed; Flutter build cache already RAM fromTask15.
- next: finish C1 persistent GAS adapters/atomicity + tests, then C2 protected clasp workflow. C3 Flutter publishing/catalog/video integration still NOT STARTED. AUTH_PENDING; SERVER_LIVE=NO; FULL_CODE_IMPLEMENTED=NO. Do not rerunC0 or reduce147scope.

## C1.2 — persistent transaction and deployment guard checkpoint
- AtomicStore.js: immutable sharded metadata+receipts, root-pointer atomic switch; process-crash fault fixture keeps old row+receipt consistency. GasFiles.js: actual GAS Drive/Permissions/Properties adapter, private JSON readback; LIVE execution NOT_RUN.
- Prepared no-secret Node-only workflow and manual develop/environment-restricted deployment guard; clasp3.4.1 installed in RAM and actual CLI help verified. Full CD is NOT READY: no create-once/push/readback/deploy/bootstrap implementation yet; guard intentionally forbids deployment of incomplete source even with credential.
- Node7PASS; C1 stillACTIVE, not complete. C2 source guard prepared only, C3–C5 pending. Missing OAuth does not account for unfinished Flutter/backend functions; these remain CODE_PENDING.
- next exact step: integrate AtomicStore with catalog tests using real IO fixture, complete GAS JWT subject/grants +router+bootstrap adapters, then media Drive resumable and hash verification. Do not deploy incomplete source. See server/alchemist/IMPLEMENTATION_STATUS.md. Keep147scope.

## C1.3 — GAS bindings checkpoint
- GoogleJwt.js derived from existing audited RSA verifier: signature/issuer/audience/time/email verification plus SERVER subject grants, not caller role. Node auth negatives use controlled verifier fixture; live OAuth NOT_RUN.
- GAS Router.js uses only postData JSON envelopes, logical status, actual private Drive AtomicStore adapter for supported catalog operations. Public health explicitly says fullSourceReady=false; media/journal/package/full catalog actions not all wired. Build script assembles new source +existing licensed RSA vendor without touching old diary code. No runtime /exec created.
- Public manifest rejects private locator/credential fields; publishing public dependencies now validates anonymous readability through full DAG. These are local code tests, not cloud evidence.
- Node8PASS after expected negative code updated for new transitive ACL check; C1 remainsACTIVE. Next implement production storage.bootstrap binding+real Drive resumable sessions/incremental digest, remaining catalog/diary/package operations and failure tests. C3 author/client UI stillnotimplemented, source scope unchanged147.

## C1.4 — chunked Drive source and hash checkpoint
- AlchemistSha256 bounded-memory serializable checkpoint SHA validated against Node crypto (padding boundaries,3MiB+17, restart every8191bytes); no whole-video buffer.
- GasTransfer.js actual UrlFetch owner-internal Drive resumable PUT +authenticated Range GET, private session URL/file IDs never returned by transfer API; verification advances one256KiB per request. This is source+mocked API execution, NOT realDrive throughput/largevideo proof.
- Receipt ledger avoids reading incomplete Drive file on retransmit; atomic session/chunk ledger binding and final-lost-response reconciliation still required before runtime routing/deployment. Media operations not yet wired intoRouter; C1 NOT_COMPLETE.
- Node10PASS (includes real GAS adapter code with controlled Google API responses). Next: persist sessions/chunk receipts withAtomicStore, bootstrapregistry binding, Drive status/reconcile, complete diary/packages/catalog APIs; C3 Flutter author/client catalog/video stillpending.

## C1.5 — bootstrap binding and consumer transport checkpoint
- Actual GasFolders.js Advanced Drive adapter: owner subject+verified email gate, effective ACL/owner/MIME/parent readback, named registry, ScriptLock, private stored folder IDs; bootstrap returns only count/schema receipt. Source only, no live folders created.
- Catalog index revision split from generic media/receipt writes so chunk checkpoints do not invalidate client pagination; unit regression added. Domain public publication grants/read authorization still require completion for transitive/shared and withdrawn assets before production.
- AlchemistApi Dart consumer protocol implemented separately from legacy diary: no default/fake endpoint; POST credential envelope, allowlisted Google redirect without token forwarding, logical errors/HTML denied, sanitized error codes. Flutter2PASS, analyzerclean; not wired to main/UI yet, so C3 NOT_COMPLETE.
- Node11PASS, CI no-secret server workflow runs on pushed checkpoints. Full Flutter/dualAPK not rerun on this unfinished intermediate app integration. Old diary source/RunScreen/assets unchanged, SQLite9/signing/version untouched.
- NEXT C1: persistent upload sessions+chunk receipt transactions, reconcile final Drive PUT lost response, asset publication-reference ACL after withdrawal/shared dependencies, all required catalog revisions/diff/update/attach methods, diary/package routes. Then C2 complete clasp create-once/readback/deploy; C3 full author editor/client installer/video; C4 live only after OAuth. READ server/alchemist/IMPLEMENTATION_STATUS.md. Do NOT deploy partial source or call workflow ready.

## Auth continuation verified
Read-only workflow42792367833 SUCCESS onmain8bb3d2d. Both actual runtime markers verified: owner identity and list-scripts API. No credential/ID output and no cloudwrites. Repository secret confirmed valid for these read operations; write/deploy scopes not yet exercised. AUTH_LOGIN_VERIFIED=YES; previous missing-secret blocker resolved. Server/code readiness stillnotcomplete; no prematuredeployment.

## C1.6 — resumed after verified repository OAuth
- before_sha:6d5f3b2; auth-only PR18 merged ONLY workflow into main under explicit owner instruction; main app/server untouched. Manual-main read-only auth workflow42792367833 SUCCESS; repository CLASPRC_JSON verified without exposing value. Not environment secret. Actual markers verified, no cloud writes/deploy.
- Added AlchemistMediaRuntime persistent session/request/chunk/asset bindings to AtomicStore. Publication-reference ACL rechecked for descriptor/chunks; withdrawal blocks new bytes but retains blobs. Added immutable catalog revision snapshots/getRevision/diff/checkUpdates/attachAsset and operation-bound idempotency digest.
- Node12PASS including integrated REAL domain+transaction-store test (not live Google): upload->private->publish->anonymousbytes->withdraw->deny->reopen/receipt/history. Source test does not substitute for live E2E.
- Next: Drive final PUT response-loss reconciliation and persistent dedup; complete diary/package/sync/auth operations; Flutter author annotations/client selective installer/video. C1 stillACTIVE, scope147 preserved; no full-code/deploy claim. C0 not repeated. AUTH check is complete; no owner re-login required.

## C1.7 — diary and immutable public snapshots
- Diary RPC create/patch/publish/quiet metadata/close/reannounce/unpublish/archive/restore now uses same atomic catalog transaction and operation-bound receipt; retry cannot generate second cycle/revision. Text/image/audio/video/ContentLink blocks retain ordered typed references. Source/controlled test only; actual Google data not yet written.
- Published snapshot separated from working draft; pending private edits never leak via list/getRevision or a quiet metadata update. Immutable per-item metadata snapshots retained. Added regression for private working text +quiet title +stale historical revision access.
- Node13PASS. Remaining C1: reconciliation/finalize dedup, remaining package/catalog/auth/sync methods, complete boundary validation and live adapters. Do not call C1 complete or deploy yet. OAuth read-only validation succeeded; no repeat login required. Continue C1 in same branch.
