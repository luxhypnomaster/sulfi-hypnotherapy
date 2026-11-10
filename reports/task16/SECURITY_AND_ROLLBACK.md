# Безопасность, данные и восстановление

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Текущая контрольная точка: de27d86.

Runtime consent подтверждён фактическим JSON, а не только ответом владельца. [Deploy 42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006) SUCCESS: existing Script/version4/source766f178, private bootstrap41, replay и отрицательные проверки. [Readback42876284145](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42876284145) подтверждает DEPLOYED_STORAGE_VERIFIED. Независимый anonymous HTTP200 application/json health повторно проверен; raw health.liveVerified=false — константа, не доказательство сквозной готовности. Старый «Сульфи — дневник» не изменялся.

Последние APK21: source953d5bc, CI42819404870 SUCCESS, 418Flutter PASS. Они пока без endpoint; подключёнными APK их не называем. Текущий Node33 PASS. [Первый live E2E42877004822](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42877004822) FAILED: media.beginUpload превысил20sec timeout. Изолированный новый transport исправлен,3regressionPASS. [Повтор42878030592](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592) выполняется, результат не предполагается. Android OAuth Web client ID отсутствует; законная настройка описана в ANDROID_OAUTH_SETUP_RU.md. Физический Android NOT_RUN.


Новые grants — только от verified Google owner; роль UI и caller role не принимаются за право. JWT RSA/cert/issuer/audience/iat/exp/nbf/email_verified/sub, refresh unknown-kid throttled. Immutable owner, grant revoke immediate; old receipt replay не оживляет отозванный grant. User labels/path/DriveID/session/secret не входят в клиентскую проекцию и audit.

Личные reader cache/read-state разделены по verified sub. Смена аккаунта invalidates pending HTTP/cache writes/login. При выходе already-open restricted reader скрывает запись, preview останавливается; строки SQLite остаются. GC видит ссылки всех private scopes, поэтому не стирает вложения вышедшего аккаунта. Stale outbox snapshot не затирает newer local edit; сохраняется conflict.

G3: changed bytes под прежним ID не подменяют original audio старой истории; конфликтная операция fail-closed. Исторически уже потерянные байты из воздуха не восстанавливаются. Полная side-by-side SQLite/audio migration НЕ заявлена выполненной. Backup/capsule/dry-run/rollback/reconcile/fault/SIGKILL tests сохранены. Не удалять приложение ради установки обновления.

Cloud: immutable shards+receipt до atomic head, crash оставляет старую согласованную голову. Все прежние snapshots сохраняются; media GC намеренно не удаляет bytes. Schema mismatch не переписывает данные. Rollback GAS deployment/version меняет code, не Drive data; сначала сохранить current source/deployment ID/registry/head и owner-only копию snapshots. Не откатывать store на несовместимый schema1. Разрушающий restore только отдельной подтверждённой процедурой, не deploy.

Проверка secret safety: .clasprc только transient0600 в isolated runner, не Git/APK/Drive reports/artifacts; always cleanup. Artifact hashes содержат SHA исходника, не сам InitialConfig/owner identity. For_Codex shared writer сохранён по указанию владельца; closed runtime storage проверяется отдельно и не наследует этот ACL. Старый diary Script ID явно запрещён в deploy-core.

Реальные cloud security probes: NOT_RUN / GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML; unit security не выдаётся за live.
