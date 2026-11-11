# GitHub CI/CD

Дата:10.11.2026 UTC. Ветка feat/task16-alchemist-full-server. APK/sourcee4ed74b, service-test source6f1c8b9 (тот же lib/test код; версия21→22), GAS/version4/source766f178. Старый «Сульфи — дневник» не менялся. C0/PREFLIGHT сохранён, не повторялся.

[Real service E2E42878030592 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592): авторские Flutter-сервисы → существующий GAS → private Drive → отдельный клиентский SQLite/installer.6540746B загружено и6540746B скачано, WAV/AAC/PNG/MP4/ZIP и SHA проверены. Recovery42887239597, artifact13797585085; протокол LIVE_SERVICE_E2E.json и LIVE_TIMELINE.json. Это НЕ испытание двух установленных Android APK.

[Deploy42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006)/readback42876284145: anonymous JSON health, exact41 private folders/replay/live negatives PASS. [Обе APK22/CI42878716769 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878716769):419Flutter/33newNode/24oldNode/13schemas/formatter/analyzer/fixedCLIENT/package/signing PASS. Пока LOCAL_BUILD_ENDPOINT_NOT_CONFIGURED: владелец подтвердил, что Web OAuth client ещё не создан. Нужны официальные Web+две Android регистрации, см. ANDROID_OAUTH_SETUP_RU.md; clasp повторно авторизовывать не нужно. Физический Android NOT_RUN.


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

PR29/30 — main-reviewed immutable app snapshot для manual live service validation, SDK tag+exact hash/stable, analyzer/compile/dependency checks до identity. PR31 обновил snapshot на6f1c8b9 после реального20sec timeout. Новый Alchemist transport5min bounded response, старый diary без изменений. E2E42877004822 FAILED timeout; повтор42878030592 SUCCESS. PR32 позволяет безопасно читать только whitelisted evidence полей из exact main workflow artifacts, без Google secret.

Read-only public certificate run42875871201 SUCCESS; package/SHA-1 взяты из двух реально собранных APK21 diagnostics, не из keystore. Google Web client ID в repository vars отсутствует. Автоматизированный CI не подменяет официальный Console client registration.

## Завершение текущего сервисного прогона

Main-only PR30 исправил SDK tag/stable identity. PR31 закрепил reviewedsource6f1c8b9 с изолированным Alchemist timeout. PR32 добавил read-only recovery только whitelisted evidence. PR33 обновил метаданные runtime/private-bootstrap, без публикации. Все соответствующие checks PASS; main Flutter app source не заменялся.

Manual-main live42878030592 SUCCESS,51:42; recovery42887239597 PASS, artifact13797585085. Истинный token только RAM/0600temporary file, refresh grant не попадал child/fixture. Cleanup performed.193logical API/386HTTPlegs incl redirects; realbytes6540746eachway. Runtime/version4/source766f178; identical lib/test business code6f vs APK22/e4.

Manual app CI42878716769 SUCCESS:419Flutter/33newNode/24oldNode/13schemas/fixedCLIENT/analyzer/formatter/package+signing, author13794725587/client13792599633. Публичные SHA — APK_CI_EVIDENCE.json. Оба LOCAL_BUILD_ENDPOINT_NOT_CONFIGURED, owner confirmed missing Web OAuth client. Physical Android NOT_RUN.
