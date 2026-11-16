# №19 G0–G1 — безопасность и threat model

| Риск | Реализованный барьер | Доказательство/остаток |
|---|---|---|
| Refresh rotation race UI/headless | Один native broker, install/project mutex + OS file lock, сохранить rotated credential до follow-up user check | JVM concurrency + stale rejected-token tests; real cross-process Android execution NOT_RUN до runner |
| Cross-account task | expectedUid before refresh, /user equality, authority epoch, no automatic legacy ID substitution | JVM ownerB/staleEpoch denial; real Google/accounts NOT_RUN |
| Callback replay/hijack | Random S256 verifier, nonce, strict callback, encrypted pending state, consume once | JVM negative callbacks; custom scheme interception can deny delivery, future App Links gate |
| 401/503 confusion | One refresh before REAUTH; 503/429/DNS/timeout preserve credential, bounded retry | Core+REST adapter tests; managed live errors NOT_RUN |
| Untrusted role/edition | Prototype grants no application MASTER/entitlement roles; GET/user identity only, no client supplied app_user_id mapping | Existing47server tests preserve server-sub policy. A CLIENT Google subject cannot self-grant MASTER via flag. The real MASTER sub inside CLIENT still has serverMASTER: edition is UX, not proven security boundary |
| Token/secret leakage | Keystore AES-GCM, noBackup, snapshots/toString redacted; no body/URL/token logging; response bounded; no redirects with bearer | SOURCE/JVM; actual Android vault runtime pending. No real credentials used in tests |
| Wrong production cutover | FlagdefaultOFF, isolated .auth19 suffix + entrypoint guard, source excluded from default build, no GAS adapter replacement | SOURCE+Android type compile; packaging defaultOFF gate prepared, actual final build status in TESTS |
| Unreadable vault/power loss | Preserve encrypted file; atomic local write; do not delete SQLite/media or claim exactly-once remote refresh across crash | SOURCE; Keystore/cold process controlled harness prepared, not physical PASS |

Only sb_publishable_ key allowed by staging config; service_role/JWT signing secret/Google client_secret never input to app/workflow/repository. Google client_secret belongs solely in owner-controlled staging provider settings. No Google Drive scopes requested by prototype. A public key is not a role or licence. No public database table/Storage/bucket/ledger deployed; G2 RLS remains a future gate.

NativeMethodChannel is in-process, not an exported network service. Exported callback Activity accepts no authority directly from URI; exchange proof+server identity required. Background method allowlist requires pinned owner and never returns refresh token. Future consumers must check epochs and task user intent on every RPC. Android rooted/compromised OS and deliberate source modification by a malicious client are not solved by a client flag. Server must enforce all future permissions.

Signing configuration/keys, production Google OAuth ACL, GAS6/main unchanged. Local SDK tool cache uses a copied Java truststore with the environment's preinstalled proxy CA only for build dependency access; TLS/hostname verification remains on, no Android trust config or shipped CA change. GitHub billing error was not bypassed through payments, public repo or secret exposure.
