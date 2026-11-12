# №16-В P0 checkpoint 1
Source APK25: 012f7f69b7ad99c0d44f2a442d9649aa1481117e. Separate hotfix branch only.
STOP-SHIP: no APK26, no owner-device actions, no GAS/main/ACL/signing changes.
Owner: standard update without uninstall, own tracks/modules/diary absent from UI; physical bytes UNKNOWN.
ZIP fully read, manifest eight files verified; SHA in BASELINE_FREEZE_16V.json.
G0 read-only audit in progress. Native harness creates materials using immutable APK24 UI, never injects SQLite. Reads copies of DB+WAL+SHM for integrity/IDs/SHA.
Real Google-account steps remain BLOCKED without a human account; never fabricate identities.

Checkpoint 2: legacy diary scope visibility regression is reproduced by a failing domain test (existing row google:owner-a, verified same MASTER, APK25 filter returns none). Minimal read-only scope alias patch in source, no database/media mutation or migration. Same-subject verified MASTER only; guest/CLIENT/other subject denied. Unit fixture is NOT a native UI test. Actual owner cause for simultaneous missing tracks/modules remains UNKNOWN; no APK26 build permitted.
Native UI workflow: https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43254064338 in progress. New draft PR46, PR45 unchanged.
Read-only COPY diagnostic tool: 6 regressions PASS incl WAL, missing/corrupt DB without fallback, unchanged original bytes, malformed payload, unsafe path.

Native run1 43254064338 completed but harness tap failed (`Element['bounds']` vs `.get('bounds')`) before any creation. Run1 upgrade/cold-restart assertions incorrectly accepted an empty baseline. These are INVALID evidence, NOT preservation PASS. Harness corrected to require successful populated UI-created baseline before any upgrade PASS. No app data or owner device was affected. Original run1 JSON preserved as evidence of the test defect. Re-running immutable APK24→25 with corrected driver.

Run2 43255433079: full CI434/Node/security PASS, but native materials creation BLOCKED (DocumentsUI initially Recent empty; pushed AAC files not selectable, editor never opens; emulator later offline). No populated before/after pair or update proof. No SQL injection used. Corrected harness to wait for real picker, scan each harmless PCM WAV file, wait for editor; screenshot failure cannot abort evidence reporting; chunked SHA-verified log evidence avoids artifact quota. Non-PASS native cases now make the native gate nonzero, rather than equating harness completion with acceptance. Original shared checks workflow retained, P0 manual inputs/jobs appended.
