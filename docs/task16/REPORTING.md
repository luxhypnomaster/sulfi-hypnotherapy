# Фактические доказательства вместо «почти готово»

В `For_Codex/Отчёты — Задание 16` записать:

- `RESULT.md`: `FULL_CODE_IMPLEMENTED`, `CLOUD_AUTH_BLOCKED`/`SERVER_LIVE`, `FULL_E2E`/`NOT_VERIFIED`, `APK_BUILT`, `ANDROID_NOT_RUN` — все как отдельные булевы факты с proof; новая GAS project name должна быть **«Сервер Проекта Алхимик»**.
- `PROGRESS.md`: checklist, stage commits, exact SHA, resume command (не повторять C0/C1 без причин), residual Code quota.
- `GITHUB_CI_CD.md`: фактический GitHub SHA, workflow/test run IDs, триггеры/permissions/environment и секреты только по ИМЕНАМ, флаги `GITHUB_CI_READY` / `GITHUB_CD_WORKFLOW_READY` / `GITHUB_SECRET_MISSING` и `CLASP_LOGIN_COMPLETED`, evidence CI; ни один токен не копировать в отчёт.
- `CLOUD_ACCESS.md`: реальные scopes/capabilities, что означает аккаунт toggle, исключить credentials, результаты Script API/Drive import, scriptId, readback SHA, real deploymentId/version/URL только если есть.
- `SERVER_CONTRACT.md`: все рабочие операции, JSON schemas, access model, Drive data layout, packages, catalogue card API, audio/video transfer, ETag, failures, quotas, chunk sizes, resume state.
- `PREFLIGHT.md`: независимый доработочный C0 аудит: согласованные пользовательские K/F, реальные ограничения GAS HTTP, auth path, folder inherited ACL, package dependencies, G3 migration и acceptance gates.
- `CATALOG_TESTS.md`: реальные item/card manifests (без чужих данных), annotation/edit, module→track dependency graph, selective installation, repeated uploads, private/pub, version update, errors и no overwrite personal copies.
- `DRIVE_TREE_AND_ACL.md`: root project metadata verification, idempotent folder tree/readback, object folders/type/ACL and inherited permissions, counts/dedup without listing sensitive private names in public report.
- `MEDIA_TESTS.md`: actual size+MIME+SHA сравнение PNG/многомегабайтного audio/видео > single GAS request/ZIP; resumed transfer; access denied; exact version readback; пометить Node mock vs live.
- `CHANGES.md`: Git diff/stat, файлы JS/GAS/Dart/Android/build, versioned migration, не удаленные старые данные.
- `SECURITY_AND_ROLLBACK.md`: server ACL/author grant negatives, privacy, rollback code + Drive data отдельно, backups, no leaks.
- `TESTS.md`: полный acceptance matrix PASS/PARTIAL/BLOCKED/NOT_RUN, CI, unit/integration/live labels, direct evidence; отдельно физическая Android приемка.
- `APK_INFO.md`: автор и клиент версия, packageId, hash, signing, Git source, CI artifacts, реальные endpoints/неподключённое состояние.
- `ISSUES_AND_NEXT.md`: исключительно незавершённое, exact blocker+первая минимальная точка преодоления (по возможности с телефона), рекомендации для будущего послесбросового backlog.

Готовность определяется не количеством файлов, а успешной живой цепочкой `master -> production GAS -> private Drive -> production GAS/authorized Drive -> client`, плюс установленными правами.

## Catalog and storage evidence

Report exact status of: `CATALOG_SCHEMA`, `AUTHOR_ANNOTATIONS`, `AUTHOR_PUBLISH_UI`, `CLIENT_CATALOG`, `CLIENT_INSTALL`, `DRIVE_TREE_BOOTSTRAP`, `DRIVE_TREE_READBACK`, `MODULE_DEPENDENCY_MANIFEST`, `BINARY_TRANSFER_LIMITS`, `AUTH_SAFE_PUBLIC_PROJECTION`. Show root/folder IDs only in secure owner report if readback was real and safe; no invented folders or paths. Provide screenshots/tests of a track with annotation, module including that track, publish→catalog list→client download, metadata-only edit without MP3 retransmission, and private diary absence from public catalog. If OAuth missing, clearly report `NOT_RUN` for Drive tree and real clients.
