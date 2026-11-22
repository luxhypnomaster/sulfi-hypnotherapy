# Запреты и безопасная публикация

- Изменения к production GAS6, legacy «Сульфи — дневник», Apps Script deployment, cloud Drive ACL/ScriptProperties, OAuth redirect, real owner signing/private data, database wipe, branch main force/merge, repository visibility/billing, stores/release/public announcement — вне полномочий №25.
- Public source: audit changed files/secrets leaks in git diff and generated artifact/log, no private keys, recovery codes, tokens, service account JSON, user IDs/email/media. Сложные historical secret leak проблемы требуют отдельного ревью, не объявлять полную историю проверенной без evidence.
- CI secrets never passed to untrusted code on PR/fork/unsafe workflow trigger; use immutable pinned trusted source with documented owner approval; ensure token minimal `contents: read` when possible. No `@codex` GitHub-issue integration change.
- Avoid fake evidence: `PASS_LOCAL`, `PASS_NATIVE`, `PASS_OWNER_PHONE`, `BLOCKED_LIVE`, `DEFERRED_OWNER` separately. `SULFI_PROJECT22` and other experimental flags default OFF, no silent migration/sync. Test Google user identities synthetic is not real auth.
- Before any native build: check official Android requirements current targetSdk, foreground service notification/audio, OS update backup behavior; doc https://developer.android.com/google/play/requirements/target-sdk . No store submission here.
- At most two identical failing CI attempts only with new changed hypothesis; existing billing 0steps repeated without changed state is waste. Record 5h/week usage values only if owner reported; no guessed %s.
