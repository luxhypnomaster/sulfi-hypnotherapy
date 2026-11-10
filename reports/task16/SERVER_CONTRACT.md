# Реализованный контракт

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


GET: только health/capabilities/serverVersion. POST application/json: `{version:1,operation,parameters,credential?}`; TextOutput JSON `{ok,status,result|error,requestId,serverTime}`. GAS HTTP200 с логическим status200/401/403/404/409/410/412/422/429/503, без вымышленных e.headers/binary206. Credential только в теле исходного POST. Redirect разрешён только HTTPS script.googleusercontent.com GET, без повторной пересылки credential.

Операции: catalog createDraft/patchDraft/updateMetadata/publish/withdraw/archive/restore/get/getRevision/list/search/diff/checkUpdates/attachAsset/validateDependencies/getInstallPlan/resolveReference/changes; content.registerManifest; entry createDraft/patchDraft/publish/unpublish/archive/deleteSoft/restore/reannounce/close/visibility/updateMetadata/get, feed.list, media.linkToEntry; media beginUpload/uploadChunk/commitUpload/abortUpload/downloadChunk/getDescriptor/beginDownload/finalizeDownload/metadata; audio/image/video.list; auth.whoami и owner grants list/set/revoke; snapshot.get, sync.pull/push, conflict.resolve, events.list, outbox.status, audit.list, download.receipt, package.importRecord и version/package aliases. Точный dispatch: Router.js/Operations.js.

CatalogCard отдельно от bytes: заголовок/аннотация/описание/язык/автор/категории/теги/видимость/обложка/releaseNotes;7типов. Private working record отделён от published snapshot. ReaderView даже для владельца выдаёт утверждённую редакцию. Локальная правка сама не публикует. ETag412, payload-bound requestId409, immutable exact logicalId/revisionId/SHA, DAG/cycle/version guards. Публичная карточка не отдаёт Drive IDs/paths/grants/credentials.

Хранилище: bootstrap schema1/41папка, первый metadata store schema2, immutable namespace shards и атомарная смена protected head. Неизвестная схема503 без удаления/перезаписи. card indexes ограничивают страницу100кандидатами, выдача до50 и1.3MB; continuation возможен даже при пустой странице фильтра. Chunk/receipt writes не меняют catalog revision. Direct asset-grants namespace исключает сканирование transfer ledger при выдаче каждого фрагмента.

Медиа: Drive resumable PUT + authenticated Range внутри GAS, наружу JSON/base64 до256KiB decoded. Checkpoint/session TTL7дней, SHA incremental с сохранением состояния; по одному bounded verify шагу, реальный MIME header; session URL/owner token/fileId никогда не уходят читателю. Lost final PUT reconciles preallocated Drive ID. Dedup same-owner bytes, alias exact logical revision. Повтор download проверяет ACL/TTL/закрытие; withdraw не удаляет shared bytes. Ограничения Google:6min/invocation, quotas/Drive free space/network; throughput многогигабайтных файлов не измерен. Нет обещания безлимитного video-stream.

Личный reader state отдельный по verified sub; conditional sync/ETag и receipt. Аудит redacted, последние500событий. Входящие запросы и verified actors ограничены бюджетом. APK Google token только RAM, logout инвалидирует ожидающий login/кэш/открытый приватный reader; DB сохраняется.
