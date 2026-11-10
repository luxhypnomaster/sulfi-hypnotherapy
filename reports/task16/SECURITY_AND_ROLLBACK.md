# Безопасность, данные и восстановление

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


Новые grants — только от verified Google owner; роль UI и caller role не принимаются за право. JWT RSA/cert/issuer/audience/iat/exp/nbf/email_verified/sub, refresh unknown-kid throttled. Immutable owner, grant revoke immediate; old receipt replay не оживляет отозванный grant. User labels/path/DriveID/session/secret не входят в клиентскую проекцию и audit.

Личные reader cache/read-state разделены по verified sub. Смена аккаунта invalidates pending HTTP/cache writes/login. При выходе already-open restricted reader скрывает запись, preview останавливается; строки SQLite остаются. GC видит ссылки всех private scopes, поэтому не стирает вложения вышедшего аккаунта. Stale outbox snapshot не затирает newer local edit; сохраняется conflict.

G3: changed bytes под прежним ID не подменяют original audio старой истории; конфликтная операция fail-closed. Исторически уже потерянные байты из воздуха не восстанавливаются. Полная side-by-side SQLite/audio migration НЕ заявлена выполненной. Backup/capsule/dry-run/rollback/reconcile/fault/SIGKILL tests сохранены. Не удалять приложение ради установки обновления.

Cloud: immutable shards+receipt до atomic head, crash оставляет старую согласованную голову. Все прежние snapshots сохраняются; media GC намеренно не удаляет bytes. Schema mismatch не переписывает данные. Rollback GAS deployment/version меняет code, не Drive data; сначала сохранить current source/deployment ID/registry/head и owner-only копию snapshots. Не откатывать store на несовместимый schema1. Разрушающий restore только отдельной подтверждённой процедурой, не deploy.

Проверка secret safety: .clasprc только transient0600 в isolated runner, не Git/APK/Drive reports/artifacts; always cleanup. Artifact hashes содержат SHA исходника, не сам InitialConfig/owner identity. For_Codex shared writer сохранён по указанию владельца; closed runtime storage проверяется отдельно и не наследует этот ACL. Старый diary Script ID явно запрещён в deploy-core.

Реальные cloud security probes: NOT_RUN / GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML; unit security не выдаётся за live.
