# Safe boundaries and zero-regression principles

1. Do not touch live GAS6, authentication secrets, OAuth/Google sign-in, ACL, identity mapping, main branch, app signing or user SQLite data without separate explicit consent.
2. Continue work in a new branch stacked from PR51. No PR merge, branch rebase onto main, or overwriting prior commits. Document exact ancestor chain and diff.
3. Existing clients must keep working with previous API. New endpoint capability negotiation cannot force automatic migration and cannot block user sessions or downloads.
4. `HEAD` must only point to immutable verified snapshots. Failed prepare/permission/retry must leave old HEAD untouched. Server must prove write receipt, not equate HTTP response or local cached save to publication.
5. Account B cannot see private overlays, read state, entitlement or local cache of A. CLIENT cannot write protected admin config. Never trust edition/client flags, user-supplied role or email alone.
6. Existing official installed programs and personal audio remain unchanged and user-created revisions must not be reset. Do not call clear/uninstall/force update as testing shortcuts.
7. Reuse existing queue18; no second durable scheduler, no connection-based repeated login chooser or runaway polling. Repeated requests coalesce safely.
8. Node/injected tests ≠ live GAS E2E. Flutter bundle ≠ Android APK. Android debug ≠ upgrade-safe signed APK. PR created ≠ CI success. CI 0 steps ≠ PASS. Owner phone QA remains NOT_RUN until physically performed.
9. No model-driven provider selection or mandatory VPN: Supabase Cloud production rejected by owner; TatNet only an unapproved candidate. Reject unverified claims about backup/restore, exports or database quota API.
10. No personal medical/therapy records, secrets, tokens or real user data in screenshots/PR/issues/report ZIPs. Use synthetic accounts, redacted fixtures, private server side ACL checks.
11. Task is authorized to implement and test code in a draft PR, *not* to deploy or commit any live server change. Security STOP gates override speed/available model usage.
12. The existing `For_Codex` folder may be `anyone:writer`; verify hash and note risk. Do not change sharing without owner's explicit separate permission.
