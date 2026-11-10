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
