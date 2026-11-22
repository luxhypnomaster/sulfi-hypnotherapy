# Артефакты и критерии сдачи

Required deliverables:
1. Draft PR on branch `feat/task22-*`, stacked on *verified* latest №21, or independent branch if №21 still running. No silently changing parent PR.
2. Short `RESULT_22.md`: PASS/PARTIAL/BLOCKED/NOT_RUN by LOCAL/STAGING/NATIVE/LIVE/OWNER plus next steps, exact source SHA and PR ancestry.
3. `ACCEPTANCE_22.md` with all T22-001..T22-045 statuses and reproducible logs for any PASS.
4. `SERVER_BASELINE_22.md` current deployed GAS6 and version, exact diff, repo/storage verification, backup/restore receipts (without credentials), rollback and migration proof.
5. `RATINGS_22.md` direct/context schema, consent, idempotency, aggregation/hash revision and tests; no invented formulas.
6. `COVERAGE_22.md` requirement IDs vs code files/PR/tests; identify genuinely unimplemented, implemented-only-local, and live-ready.
7. `OWNER_QA_22.md` two-account Android/real server checklist; build deliverables only if safe signing and retention verified.
8. `ISSUES_22.md` with concise blocker, what tried (max 2 distinct attempts), and independent tracks continued.
9. Final artifacts in `For_Codex/Отчёты — Задание 22`, with separate evidence ZIP and hashes; no private source or APK if folder broadly writable, unless protected channel.

Don't declare complete just because Flutter tests pass: physical Android, live production, CI (if runner started), owner review are separate. No fake green metrics. The 7-section UI requires server data, not placeholders. When out of budget, prioritize P0/P1 and leave structured checkpoint for next cycle.
- T22-053..058: three ratings, versioned replaceable policy/config, admin draft/preview/atomic activation/rollback (independent PASS/PARTIAL/BLOCKED evidence); no unapproved production coefficients.
