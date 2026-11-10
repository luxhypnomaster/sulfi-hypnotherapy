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
