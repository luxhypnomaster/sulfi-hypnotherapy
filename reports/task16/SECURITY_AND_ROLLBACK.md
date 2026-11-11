# Безопасность, данные и восстановление

Дата:10.11.2026 UTC. Ветка feat/task16-alchemist-full-server. APK/sourcee4ed74b, service-test source6f1c8b9 (тот же lib/test код; версия21→22), GAS/version4/source766f178. Старый «Сульфи — дневник» не менялся. C0/PREFLIGHT сохранён, не повторялся.

[Real service E2E42878030592 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592): авторские Flutter-сервисы → существующий GAS → private Drive → отдельный клиентский SQLite/installer.6540746B загружено и6540746B скачано, WAV/AAC/PNG/MP4/ZIP и SHA проверены. Recovery42887239597, artifact13797585085; протокол LIVE_SERVICE_E2E.json и LIVE_TIMELINE.json. Это НЕ испытание двух установленных Android APK.

[Deploy42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006)/readback42876284145: anonymous JSON health, exact41 private folders/replay/live negatives PASS. [Обе APK22/CI42878716769 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878716769):419Flutter/33newNode/24oldNode/13schemas/formatter/analyzer/fixedCLIENT/package/signing PASS. Пока LOCAL_BUILD_ENDPOINT_NOT_CONFIGURED: владелец подтвердил, что Web OAuth client ещё не создан. Нужны официальные Web+две Android регистрации, см. ANDROID_OAUTH_SETUP_RU.md; clasp повторно авторизовывать не нужно. Физический Android NOT_RUN.


Новые grants — только от verified Google owner; роль UI и caller role не принимаются за право. JWT RSA/cert/issuer/audience/iat/exp/nbf/email_verified/sub, refresh unknown-kid throttled. Immutable owner, grant revoke immediate; old receipt replay не оживляет отозванный grant. User labels/path/DriveID/session/secret не входят в клиентскую проекцию и audit.

Личные reader cache/read-state разделены по verified sub. Смена аккаунта invalidates pending HTTP/cache writes/login. При выходе already-open restricted reader скрывает запись, preview останавливается; строки SQLite остаются. GC видит ссылки всех private scopes, поэтому не стирает вложения вышедшего аккаунта. Stale outbox snapshot не затирает newer local edit; сохраняется conflict.

G3: changed bytes под прежним ID не подменяют original audio старой истории; конфликтная операция fail-closed. Исторически уже потерянные байты из воздуха не восстанавливаются. Полная side-by-side SQLite/audio migration НЕ заявлена выполненной. Backup/capsule/dry-run/rollback/reconcile/fault/SIGKILL tests сохранены. Не удалять приложение ради установки обновления.

Cloud: immutable shards+receipt до atomic head, crash оставляет старую согласованную голову. Все прежние snapshots сохраняются; media GC намеренно не удаляет bytes. Schema mismatch не переписывает данные. Rollback GAS deployment/version меняет code, не Drive data; сначала сохранить current source/deployment ID/registry/head и owner-only копию snapshots. Не откатывать store на несовместимый schema1. Разрушающий restore только отдельной подтверждённой процедурой, не deploy.

Проверка secret safety: .clasprc только transient0600 в isolated runner, не Git/APK/Drive reports/artifacts; always cleanup. Artifact hashes содержат SHA исходника, не сам InitialConfig/owner identity. For_Codex shared writer сохранён по указанию владельца; closed runtime storage проверяется отдельно и не наследует этот ACL. Старый diary Script ID явно запрещён в deploy-core.

Реальные cloud security probes: NOT_RUN / GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML; unit security не выдаётся за live.
