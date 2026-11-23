# Передача результата и этапов №25

Завести отдельную папку `Проект Алхимик/For_Codex/Отчёты — Задание 25`. Передать туда и в Git PR:
1. `RESULT_25.md`: source SHA, scope, statuses INTEGRATION_READY, NATIVE_CANDIDATE_MASTER/CLIENT, SERVER_PROD_READY false unless independently proven, OWNER_DEVICE NOT_RUN, verified factual outcome.
2. `CHANGES_25.md` с source-impact table, before/after regression, conflicts/rebase notes.
3. `TESTS_25.md`: commands, run IDs, Flutter/Node/Python/native counts and explicit NOT_RUN, 2 SKIP separated.
4. `ISSUES_25.md`: all P0/P1/P2, gates, owner decisions required, next steps, no false resolution.
5. `ACCEPTANCE_25.csv` — every one of 55 criteria individually with exact statuses and evidence link.
6. `APK_INFO_25.json`+`APK_READBACK_25.json` only if real APK bytes exist; for BLOCKED write `APK_BLOCKER_25.md`, do not fabricate files or names. For successful pair preserve immutable download links+SHAs, exact signatures/version and time.
7. `NATIVE_UPGRADE_25.md`: detailed disposal fixture prepare/install -r results per edition/OS; no device owner data.
8. `SOURCE_GATE_25.json`, `DEPENDENCY_GRAPH_25.md`, audit errors, logs+manifest SHA in `EVIDENCE_25.zip` (sanitized, no binaries/secrets/data). Rendered screenshots 9:16 optional if actually captured.
9. `OWNER_QA_25.md`: plain actionable, no install recommendation until signed/version/P0 pass; no uninstall/clear app.
10. `DELIVERY_25.md`: actual Google Drive IDs/size/download-SHA readback, Git draft PR URL, source SHA, pipeline source states; record if drive upload inaccessible.

**Critical:** do not deploy/sign/upload a phantom pair to satisfy task. If blockers persist, deliver truthful PARTIAL and preserve source and logs. No merge. On successful source-and-native candidate, separately request owner phone acceptance of updated MASTER+CLIENT without touching installed data before safety instructions are issued.
