# Контрольные точки выполнения одного полноценного №16

Не создавать отдельное диагностическое ТЗ, staging-проект или toy server. Начать всё в одной ветке, делать проверяемые коммиты, печатать PROGRESS.md.

**C0 — True baseline + specification audit:** фактический код task15, contracts, данные, signing, существующие `LocalCatalog`, `CapsuleService`, K-012/K-013/K-014/K-016/K-022, Google API limitations. Прочитать `CONTENT_CATALOG_AND_STORAGE.md` и `PREFLIGHT_AUDIT.md`; сохранить `PREFLIGHT.md` с архитектурными решениями/рисками до редактирования data models.

**C1 — Full server + catalog source:** все серверные модули, one-time Drive private data root/tree, folder registry/ACL, авторский CRUD карточек с аннотациями и версиями, catalogue shards, select-install planning, media/packages/journal, versioning, error envelopes, Node tests. Скрипт реально пригоден для GAS V8. Сохранить commit.

**C2 — Production deployment:** Основной путь — GitHub Actions protected workflow с `clasp` и Secret `CLASPRC_JSON`; прежде полного OAuth — `AUTH_PENDING`, подготовить CI/CD, а не повторять Codex API 401. При действующем законном OAuth: один новый project «Сервер Проекта Алхимик», source readback, private ACL, bootstrap named Drive tree, Script Properties, versioned `/exec`, live security tests. Проверить что папки не дублируются после replay. Если 401/403 — статус `CLOUD_AUTH_BLOCKED` и явная фактическая причина, НЕ возвращаться снова к началу разработки. Сохранить source/CLI deployment runbook без секретов.

**C3 — Full Flutter:** master & client working provider, auth, diary, **author catalogue card editor/annotations, client catalogue/install selected track/module/template with only missing dependencies**, media video/audio, packages, offline sync, safe migrations, CI artifacts. Если cloud недоступен, код готов к реальному endpoint, но не объявлять APK полноценно подключённой.

**C4 — Real E2E:** author annotated track→publish→client list→download/play and author module→client install only missing tracks, private Drive tree readback, plus после C2+C3 от живого авторского клиента до Drive и до клиентского APK — PNG/audio/video/ZIP, hashes, retry, versions, private permissions. На physical Android только owner. Не путать e2e emulator и live cloud.

**C5 — Delivery:** отчёт по всем критериям, bugs/rollback, source commit, live URLs если существуют, APK links, next resume exact. Если quota истекла — фиксировать checkpoint, не уменьшать scope и не выдавать partial за complete.

## Каталог и структура — gate перед deploy

Before production deployment: inspect existing Flutter source and handoff for duplicate components, record catalog schema/API/Drive folder-tree design, add tests of annotation+module manifest→client install flow and idempotent storage bootstrap, then actual Cloud readback if OAuth available. Never skip public/private separation or publish metadata for not-yet-uploaded blobs. On quota exhaustion document checkpoint separately `CATALOG_IMPL_STATUS`, `DRIVE_TREE_LIVE`, `MASTER_PUBLISH`, `CLIENT_INSTALL`, not generic PASS.
