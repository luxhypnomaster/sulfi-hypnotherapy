# GitHub CI/CD

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Текущая контрольная точка: de27d86.

Runtime consent подтверждён фактическим JSON, а не только ответом владельца. [Deploy 42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006) SUCCESS: existing Script/version4/source766f178, private bootstrap41, replay и отрицательные проверки. [Readback42876284145](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42876284145) подтверждает DEPLOYED_STORAGE_VERIFIED. Независимый anonymous HTTP200 application/json health повторно проверен; raw health.liveVerified=false — константа, не доказательство сквозной готовности. Старый «Сульфи — дневник» не изменялся.

Последние APK22: sourcee4ed74b, CI42878716769 SUCCESS,419Flutter PASS,33new/24oldNode PASS. Они пока без endpoint; подключёнными APK их не называем. Текущий Node33 PASS. [Первый live E2E42877004822](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42877004822) FAILED: media.beginUpload превысил20sec timeout. Изолированный новый transport исправлен,3regressionPASS. [Повтор42878030592](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592) выполняется, результат не предполагается. Android OAuth Web client ID отсутствует; законная настройка описана в ANDROID_OAUTH_SETUP_RU.md. Физический Android NOT_RUN.


- AUTH main run42792367833: owner и read-only Script list подтверждены.
- AUTH scope run42799396321: script.projects=YES, script.deployments=YES, script.webapp.deploy=YES, drive.file=YES, drive=NO, CI Google ID token verified=YES. Это не подтверждение runtime Apps Script consent.
- PR18/19 — только безопасная ручная auth-проверка. PR20 — полный сервер/тесты/tooling, merge3dd6232c6721452bd638f609f7188e5957af32ad, Flutter source main не менялся. PR21 — обновление ID-токена через действующий OAuth grant.
- First deploy42818152910: CI_ID_TOKEN_UNAVAILABLE, ни CREATE_ONCE, ни нового проекта. Исправлена отдельная жизненная стадия ID-токена; проверяется подпись/aud/exact owner после refresh, без нового login.
- Исторический deploy (блокер уже устранён): [42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED, `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`.

Workflow `.github/workflows/alchemist-server-deploy.yml`: только workflow_dispatch, exact repo+refs/heads/main, contents:read, concurrency без отмены текущего deploy. В соответствии с последним указанием владельца GitHub Free использует repository secret, без environment secret. Pinned actions, clasp3.4.1 с --ignore-scripts устанавливается до secret. Тесты/build/readiness до загрузки OAuth. Credential0600 в RUNNER_TEMP, env удаляется; finally/always удаляет файл; в artifacts только IDs/hash/status. Нет PR/fork/pull_request_target с production secret. Обычные проверки сервера работают без OAuth.

GITHUB_CI_READY=YES; GITHUB_CD_WORKFLOW_READY=YES; CLASP_LOGIN_COMPLETED=YES; GITHUB_SECRET_MISSING=NO. Успех CI не равен SERVER_LIVE/FULL_E2E.

## Итоговые контрольные точки

PR22/25 — read-only recovery verified metadata; PR23 — exact pinned already-created Script; PR24 — строгие version IDs и точные resource/stage errors; PR26/27 — read-only actual runtime diagnostics, без bootstrap/загрузки. Все main изменения — через отдельные ограниченные PR; Flutter source main не заменён. Последний main диагностический merge c48d4881cd5f82e510d561694e5d6f12e5e47ae7. Последний реальный deployment source64893b3eecedec2fa00cbb34cf9e9da06cbc7def. App APK source953d5bc отдельный и явно указан; дальнейшие server/tool/test/docs changes в APK не выдаются за встроенные.

CI42819404870 SUCCESS:418Flutter,29Node на этом APK-source, old backend24, schemas, formatter/analyzer, fixedCLIENT, обе signed21APK. Более поздний сервер/target stage gate30Node PASS в CI42820365204 и deploy42820498828, локально30PASS. Полный локальный418 прогон сохранён до поздних backend/tool/test-only уточнений; LIVE-06 оставлен PARTIAL по требованию final-HEAD, не вымышленный PASS.

## Текущая проверка после owner consent

PR28 — реальная совместимость Advanced Drive, строгая проверка empty ACL. Deploy42872816006 SUCCESS/version4/source766f178, owner bootstrap41/replay/live negatives. Readback42876284145 подтвердил DEPLOYED_STORAGE_VERIFIED.

PR29/30 — main-reviewed immutable app snapshot для manual live service validation, SDK tag+exact hash/stable, analyzer/compile/dependency checks до identity. PR31 обновил snapshot на6f1c8b9 после реального20sec timeout. Новый Alchemist transport5min bounded response, старый diary без изменений. E2E42877004822 FAILED timeout; повтор42878030592 выполняется. PR32 позволяет безопасно читать только whitelisted evidence полей из exact main workflow artifacts, без Google secret.

Read-only public certificate run42875871201 SUCCESS; package/SHA-1 взяты из двух реально собранных APK21 diagnostics, не из keystore. Google Web client ID в repository vars отсутствует. Автоматизированный CI не подменяет официальный Console client registration.
