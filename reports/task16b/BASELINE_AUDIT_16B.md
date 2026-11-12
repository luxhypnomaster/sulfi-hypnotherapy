# №16-Б — G0, аудит до изменения приложения

2026-11-12. Исходный Task16 HEAD c895291e618cc481d82cc0dcc5a90cfd73ed53f8, app/APK24 cbe05240d463b9dafbe9a12ee831c967bdbf6113. Новый worktree fix/task16b-auth-transfer-publication от c895291; PR42/43/44 не объединены. Основной checkout research/task16-autonomous@1dc652a и его результаты сохранены. SQLite9, capsule8, version0.4.16+24, оба прежних package/certificate. ZIP16Б2086883bytes/SHA8058c42b0f34ecd696013e345ca15d94f20b549ab3d72349f5550b1c32245391,22manifest members +manifest,80unique CSV criteria проверены.10owner screenshots просмотрены в RAM, исходные личные файлы не изымались и screenshots в Git не копируются.

## Первичные доказательства владельца

Дополнение16Б/evidence01/02 и оперативный паспорт19/20 подтверждают первоначальные MASTER/CLIENT Google-входы и server publish/deny check на двух телефонах. Это OWNER-REPORTED initial auth PASS, не новая проверка Codex и не полный Elman E2E. Последующие AUTHENTICATION_FAILED, DNS errno7, connection abort,100% безcommit подтверждены как наблюдения, root cause радио/DNS/GAS пока неизвестен. Критическая межтелефонная публикация/импорт не пройдена. Старые24 NOT_RUN не переписываются задним числом.

| Узел | Существующий код | Аудит |
|---|---|---|
| Google SDK | services/diary_identity.dart GoogleDiaryIdentity | EXISTING; signIn всегда signOut+authenticate, lightweight restore/refresh нет: DEFECT |
| Два входа UI | DiaryController.signInAuthor; SessionController.signInAlchemistReader | EXISTING: для нового GAS оба сходятся в DiaryController; не утверждаем две реально активные identity. Legacy AlchemistIdentitySession не основной provider нового API |
| Server identity | AlchemistDiaryApi.authenticateReader/verifiedIdentityToken/author/feed | EXISTING signed whoami; stale _token передаётся feed после exp, refresh отсутствует: DEFECT |
| HTTP/RPC | AlchemistHttp.request; AlchemistApi.call/_once | EXISTING15/20sconnect,5minheaders,30sbody; retrySocket/Timeout429/503, HttpExceptionabort не retry; unsafe POST retry не отсекается, errors.toString выводит URI: DEFECT |
| Uploader | AlchemistMediaTransfer.upload; registerAlchemistContent | EXISTING authoritative begin offset/commit SHA+logical/revision; requestId persist; progress одного файла смешан сverify; owner binding отсутствует в upload checkpoints: DEFECT |
| Catalog | AlchemistCatalog.prepare/publish/_recover | EXISTING idempotent pending mutations/readback; prepare всегда новыйID, repeated tap даётduplicate draft: DEFECT |
| Queue | app_settings alchemist_card/upload/diary_queue; AlchemistSyncScreen | EXISTING одна очередь; editor-mounted lifetime, управление отдельных raw rows: DEFECT/GAP globalrunner |
| Cover | CatalogCardEditor.cover; DiaryMediaStore.import | EXISTING SHA/type/mediaimport; upload доpersist, preview отсутствует: DEFECT |
| ContentLink | AlchemistDiaryApi._document + catalog.resolveReference + installer | EXISTING exact resolver; повторное использование content graph проверять тестом; независимого catalog/announce UX пока нет: GAP |
| Role/security | GoogleJwt.js,Access.js,Router.js,AccessPolicy | EXISTING RS256/issuer/exactWebaud/exp/sub/verifiedemail/serverroles; всеclaimsinvalid generic401 мешают диагнозу; code-only candidate допустим, livechange запрещён |
| G3 revisions | library_repository.save guard +retained snapshots | EXISTING fail-closed; не сниматьguard/не применятьresearchPR43 |
| Signed delivery | checks.yml; pinned main qa-pair workflow24 | EXISTING persistent signing; artifactquota исчерпана, новые APK черезprivate draft как24; signing/main не менять |

## Rollback / safeguards

App24 и draftassets736432720/736433144 сохраняются, certificate SHA2560b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6. НовыеAPK с большим versionCode, тем же ключом/package. Не обещать downgrade поверхnew; recovery — corrective higher version +localcapsule, безuninstall. История/аудио/модули/дневник не меняют схему. Очередь расширяется optional fields, old draft/failed остаются; legacyowner-bound operations нельзя автоматически продолжать другим аккаунтом. НикакойGC/rename/copy/delete cloudobjects. GAS6/source1a0cf8e5a60144075eec793767953586bfa319a2/единственныйScript/deployment сохраняются. Candidate backend source+tests тольковGit, deploy отдельное разрешение наточныйSHA, сохранённыйdeployment/version6 rollback черезtrusted manualCD. APK signing secrets тольковtrusted buildjob, clasp не нужен длясборки.

## Измерения / блокеры

Read-only authorization-status workflow main запрошен43156961962; он не создаётпубликаций/bootstrap. Benchmarks в sandbox должны измерять actual requests/attempts/phase/elapsed+distribution; Wi-Fi/mobile/DNS/TLS на телефоне бездоступа владельца NOT_RUN. Не выводить полныеe.toString/URL/email/sub/token; trace толькоoperation/requestId/phase/status/code/count/ms. Live write/deploy и физическая приёмка BLOCKED доотдельных действий владельца, независимыйкод/CI продолжаются.
