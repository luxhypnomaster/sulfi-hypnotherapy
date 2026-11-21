# Разрешения, запреты и независимое продолжение

## Разрешено без промежуточных запросов
- Read-only Git/Drive source audit; new feature branch, commits, draft PR, safe unit/integration tests, proposed versioned adapters, isolated fixtures, report updates, local server tests.
- Flutter UI changes within already approved MASTER HOME and diary banner boundaries; local read-state migration in non-destructive form; safe queued sync via existing worker.
- Mock/staging deployment only in a fully isolated owned environment with explicit existing safe credentials and zero unexpected cost. If unavailable, skip live and continue local tests.

## Запрещено без отдельного разрешения владельца
- Production Google Apps Script deploy/change of ACL/OAuth/Drive real private files, Supabase/TatNet provisioning or paid service, main merge, force push, public release, replacement signing/APK identity.
- Deletion/cleanup/mass rewrite of user diaries, WAV/audio, SQLite, queue checkpoints, account records, published versions, server ID mapping, receipts, license balances.
- Treating edited local `edition=MASTER` or email as security authority, copying tokens/service credentials to logs, commits or APK.

## Safe fallback ladder
1. Missing current source -> use verified repo and explicitly report missing external Doc; no invented business rules.
2. Missing provider/permissions -> test provider-neutral contract and isolated adaptor, no live deploy.
3. CI billing or runner blocked -> local tests/compile and prepared CI plan; no paid settings change.
4. Native emulator absent -> Flutter/controller and static tests, real phone QA marked NOT_RUN.
5. Auth19 no Supabase staging -> preserve default OFF, do not use as production dependency.
6. Unapproved detailed UI -> implement agreed states with existing widgets, stub separately, log exact decisions, continue tests and safe parts.

Hard-blocked action is logged in ISSUES and does not block remaining tracks. If one workstream is logically dependent on blocked work, add a mockable adapter and continue the independent units, without pretending end-to-end succeeded.
