# Canonical wire and acceptance flow — to be finalized by source preflight

## Minimum non-negotiable fields
`HEAD`: exact `scope`, `catalogRevision`, `snapshotId`, `snapshotHash`, `schemaVersion`, `createdAt`; server principal/capability gating, explicit errors. `SNAPSHOT`: immutable content metadata limited by ACL, stable contentId and immutable exact revision IDs, explicit dependencies with revision, hash/size for verification; no binary bytes, local read state, secrets, owner personal details. Vitrine config revision must not silently share unrelated public catalog revision. Unknown schema fails safely; optional fields ignored only if declared optional.

## Atomicity proof
prepare staged immutable file/manifest → read-back and checksums → locked/CAS current HEAD pointer update → idempotent commit receipt. Demonstrate abort before flip, duplicate request, stale expected revision and concurrent writers. If backing GAS cannot guarantee CAS/atomicity under existing lock contract, document gap and fail closed. Do not invent SQL transaction semantics.

## Client end to end
- unchanged HEAD returns `NO_CHANGE`: zero snapshot download and no UI flicker;
- changed HEAD: one shared bounded sync in existing durable queue; verify auth/scope/hash/schema/dependencies then SQLite transaction swap + one notifier; never auto-download all audio;
- 401/403/expiry/offline/500/corrupt: lastGood retained, private scope isolation, no automatic auth account chooser loop;
- admin config save/publish: local draft/saved vs server applied receipt, exact published revision and access checks; CLIENT denied writing;
- static Home banner preview: selected draft displayed without carousel/read/no extra HTTP, true banner dimensions and accessible text;
- Android 9:16 real on-device QA NOT automatic; preserve native UI and session audio.

## Compatibility and escalation matrix
Old API still works when capability absent. No automatic cutover. If staging E2E can be created without external credentials, run it with synthetic data; otherwise carry fully reproducible local mock/integration evidence and note owner gate. If CI account billing prevents runner, no automatic workaround with paid or anonymous services. If mobile APK cannot be compiled under memory limit, stop native and pass source evidence, no false installable link.
