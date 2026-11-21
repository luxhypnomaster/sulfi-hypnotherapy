# Ограничения для безопасной высокой скорости

Owner is currently the only real end-user, and explicitly prefers rapid engineering progress over freezing all server work. This authorizes preparation and **reversible additive** server work when evidence gates pass; not irreversible data loss.

Before any live write: exact source and server revision readback; backup including identity, roles/grants, content indexes, objects and manifests; independent restore proof; dry-run/migration plan and rollback; staging tests; scope security review; timeouts/backoff; a small canary on owner account and readback of old clients. Preserve published old GAS version, identity and user data. Never push secrets/public OAuth tokens or change account access to world-writable. If any gate fails, continue all independent tasks and document blocker without fictitious SUCCESS.

Do not invalidate existing API endpoints, Google sub mapping, locale, app package IDs, signing, private diary/media; never wipe/migrate in place without verified recovery. Production data changes require explicit evidence and must be reconstructable. No new paid provider, no VPN requirement, no automatic force-stop/large-scale notifications, no main merge. Server-side ACL always, not UI hint. Important note: source Drive For_Codex reportedly has `anyone:writer` permission; do not trust mutable task ZIP alone—verify SHA/manifest and report risk. Do not change permissions or erase access without owner-approved security plan.

For files with sensitive user data: no broad public download/telemetry; logs and Drive reports contain technical metadata/test fixtures only. Rating responses are subjective, never a clinical claim; no invisible background upload without separate consent.
