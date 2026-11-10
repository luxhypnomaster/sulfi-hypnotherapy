# GitHub CI/CD

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


- AUTH main run42792367833: owner и read-only Script list подтверждены.
- AUTH scope run42799396321: script.projects=YES, script.deployments=YES, script.webapp.deploy=YES, drive.file=YES, drive=NO, CI Google ID token verified=YES. Это не подтверждение runtime Apps Script consent.
- PR18/19 — только безопасная ручная auth-проверка. PR20 — полный сервер/тесты/tooling, merge3dd6232c6721452bd638f609f7188e5957af32ad, Flutter source main не менялся. PR21 — обновление ID-токена через действующий OAuth grant.
- First deploy42818152910: CI_ID_TOKEN_UNAVAILABLE, ни CREATE_ONCE, ни нового проекта. Исправлена отдельная жизненная стадия ID-токена; проверяется подпись/aud/exact owner после refresh, без нового login.
- Актуальный deploy: [42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED, `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`.

Workflow `.github/workflows/alchemist-server-deploy.yml`: только workflow_dispatch, exact repo+refs/heads/main, contents:read, concurrency без отмены текущего deploy. В соответствии с последним указанием владельца GitHub Free использует repository secret, без environment secret. Pinned actions, clasp3.4.1 с --ignore-scripts устанавливается до secret. Тесты/build/readiness до загрузки OAuth. Credential0600 в RUNNER_TEMP, env удаляется; finally/always удаляет файл; в artifacts только IDs/hash/status. Нет PR/fork/pull_request_target с production secret. Обычные проверки сервера работают без OAuth.

GITHUB_CI_READY=YES; GITHUB_CD_WORKFLOW_READY=YES; CLASP_LOGIN_COMPLETED=YES; GITHUB_SECRET_MISSING=NO. Успех CI не равен SERVER_LIVE/FULL_E2E.

## Итоговые контрольные точки

PR22/25 — read-only recovery verified metadata; PR23 — exact pinned already-created Script; PR24 — строгие version IDs и точные resource/stage errors; PR26/27 — read-only actual runtime diagnostics, без bootstrap/загрузки. Все main изменения — через отдельные ограниченные PR; Flutter source main не заменён. Последний main диагностический merge c48d4881cd5f82e510d561694e5d6f12e5e47ae7. Последний реальный deployment source64893b3eecedec2fa00cbb34cf9e9da06cbc7def. App APK source953d5bc отдельный и явно указан; дальнейшие server/tool/test/docs changes в APK не выдаются за встроенные.

CI42819404870 SUCCESS:418Flutter,29Node на этом APK-source, old backend24, schemas, formatter/analyzer, fixedCLIENT, обе signed21APK. Более поздний сервер/target stage gate30Node PASS в CI42820365204 и deploy42820498828, локально30PASS. Полный локальный418 прогон сохранён до поздних backend/tool/test-only уточнений; LIVE-06 оставлен PARTIAL по требованию final-HEAD, не вымышленный PASS.
