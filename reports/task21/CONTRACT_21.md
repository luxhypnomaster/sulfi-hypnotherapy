# Candidate wire v1 — NOT production-approved

Provider-neutral contract `alchemist.metadata/1`, schemaVersion1, SHA256 over sorted-key JSON UTF8 (integers only). Node/Dart golden tests retained. Envelopes reuse GAS6 version1 + one-dot operation regex. Existing routes/data unchanged; no backend provider selected. Actual new backing storage is disposable local SQLite with real WAL/FULL/atomic transactions; this is not a claim of SQL in GAS.

| Operation | Result / semantics |
|---|---|
| metadata.capabilities | server-derived scope/principalBinding, nonce echo, expiresAt, schema/hash/canonical ID, atomicHeadReceipt, declared operation set, configScope, canWriteConfig |
| catalog.head | required scope/catalogRevision/snapshotId/snapshotHash/schemaVersion/createdAt; optional etag, NO_CHANGE outcome, validUntil, vitrineHead. No records scan |
| catalog.snapshot | immutable metadata; exact contentId/revisionId/hash dependencies; optional public card projection/catalogItemId; no binary bytes/reader state/private ACL |
| vitrine.configRead | separate config head + immutable config snapshot, scope vitrine:public mapped authoritatively from approved public package scope |
| vitrine.configPrepare | verified owner/explicit server write permission; stable requestId+expectedRevision; persist/readback immutable config; prepareId, no HEAD flip |
| vitrine.configCommit | recheck current actor/scope/write rights, stable requestId/prepare owner, SQLite CAS+head+receipt transaction; receipt COMMITTED with exact config hash/revision/head |

Config revision is independent from catalogRevision. Config-only commit never rebuilds/bumps public catalog. Scope and principal binding are SERVER values, not supplied role/email/APK hints. Existing binding uses the same endpoint-bound subject derivation as AlchemistDiaryApi/AlchemistApi; sandbox derives it from private synthetic principal. No new identity map/OAuth claims.

Required fields unsupported => fail closed. Optional fields explicitly listed above; unknown schema/canonical/hash/operations/nonce/principal disables new protocol and retains legacy API. Feature flag SULFI_METADATA_V1 defaults false; even true requires handshake. No URLs from server capability response are used. UI/headless share one factory and existing queue18. No new worker.

Status:401 AUTH_REQUIRED;403 scope/role/stale/revoked;404 unsupported operation;409 stale CAS/idempotency mismatch;422 schema/hash/config/dependency validation;503 unavailable/non-atomic backing. Arbitrary exception contents are redacted. Operation success is not inferred from HTTP200 alone.

Storage: prepare immutable snapshot → durable readback/hash → BEGIN IMMEDIATE → check expected revision/access epoch → pointer+receipt → COMMIT. SIGKILL before COMMIT preserves old pointer. Lost response after COMMIT replays receipt. Source access epoch/expiry invalidates stale HEAD. Actual GAS storage adapter/ACL overlay/role mapping remain an OWNER gate before any deploy.
