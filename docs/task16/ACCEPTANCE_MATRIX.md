# №16 — Матрица приёмки полного production-server, каталога и Drive-хранилища

Пункты — ЦЕЛИ для Codex, не утверждения об исполнении. PASS только с фактическим доказательством. Node tests и скриншоты ≠ LIVE; реальная Android приёмка владельцем — отдельно. Отсутствие законного OAuth — BLOCKED, не fake PASS.

| ID | Критерий |
|---|---|
| BASE-01 | Точный task15 SHA/descendant и содержимое отчетов №15 проверены |
| BASE-02 | Ветка feat/task16-alchemist-full-server, source snapshot и чистый rollback |
| BASE-03 | Точный GAS проект только «Сервер Проекта Алхимик», старый не изменен |
| BASE-04 | Единый серверный исходник GAS V8, две APK, no parallel incompatible app layers |
| BASE-05 | Сохранность master app signing/packageId/SQLite и клиентского sandbox |
| BASE-06 | Нет отдельных staging/PoC GAS проектов или скрытых fake endpoints |
| PREF-01 | Codex выполнил source preflight task15 HEAD+K/F decisions, зафиксировал факты и blocker в PREFLIGHT.md до миграций |
| PREF-02 | Состав №16/проект/архив и точное число критериев сверены с package manifest; no stale staging |
| PREF-03 | Apps Script request e.headers, custom Range/206 и binary Response не используются без фактической поддержки Google API |
| PREF-04 | Cloud Shell consent не выдаётся за завершённый clasp login / GitHub Secret; status AUTH_PENDING доказан |
| PREF-05 | GitHub test-only workflow не использует production Secret на PR/fork, manual deployment workflow защищён |
| PREF-06 | Root Google Drive ACL и inheritance повторно проверены до записи приватных diary/media |
| PREF-07 | G3 audio exact revisions/backup/dry-run миграции спроектированы и проверены до live publication |
| PREF-08 | Все критичные неизвестные имеют gate, phone-only owner action и BLOCKED/NOT_RUN вместо вымышленного PASS |
| AUTH-01 | Включённый dashboard toggle не выдаётся за OAuth токен |
| AUTH-02 | Проверены реальные scopes для Script projects+deployment/Drive scripts import |
| AUTH-03 | Настоящий scriptId проекта создан или явно CLOUD_AUTH_BLOCKED |
| AUTH-04 | Полный script source+manifest загружен и сравнен readback SHA |
| AUTH-05 | Создан versioned deployment с реальным /exec или точным BLOCKED |
| AUTH-06 | Web app owner execution и runtime OAuth consent реально проверены |
| AUTH-07 | Owner/admin определены по верифицированному Google sub и allowlist |
| AUTH-08 | Wrong token/aud/exp/issuer/sub, role spoofing отклонены |
| AUTH-09 | Client APK не может делать author mutation |
| AUTH-10 | Публичное GET ограничено explicit published objects |
| AUTH-11 | Private author draft и персональный reader data не утекли |
| AUTH-12 | Ни project, ни private Drive root не расшарены anyone-writer |
| AUTH-13 | Секреты/refresh tokens не попали в Git/APK/ZIP/логи |
| AUTH-14 | ACL проверяется заново на выдачу пакета и каждого media chunk |
| AUTH-15 | Anonymous request к приватному blob/ZIP/entry отклонен |
| AUTH-16 | Revocation/permissions/owner ACL тестированы |
| GH-01 | GitHub origin/repo и реальная базовая ветка verified, не угадывать runner/состояние Secrets |
| GH-02 | CI workflow GAS backend Node tests и schema checks выполняется без OAuth и без secret exposure |
| GH-03 | Manual production deploy GitHub Actions workflow с protected environment и concurrency |
| GH-04 | PR/fork actions никогда не получают production CLASPRC_JSON/избыточный token |
| GH-05 | `CLASPRC_JSON` используется только как secret завершённой OAuth авторизации; raw callback/code не сохраняются |
| GH-06 | Без GitHub Secret workflow выдаёт GITHUB_SECRET_MISSING и не создаёт GAS проект |
| GH-07 | Create-once scriptId сохраняется/верифицируется, retries не плодят одноимённые проекты |
| GH-08 | Full clasp push и source readback verified; старый project неизменен |
| GH-09 | Versioned deployment обновляет известный deploymentId и не плодит публичные deployments |
| GH-10 | CI run и live deploy имеют разные evidences, no fake LIVE при AUTH_PENDING |
| GH-11 | Секретные credential-файлы не попадают в commits, APK, logs, CI artifacts, отчёты |
| GH-12 | Владельцу можно продолжать с телефона; не требуется ПК или ручной редактор Apps Script |
| DRV-01 | Bootstrap creates exact one private `Хранилище Сервера Проекта Алхимик` under existing Alchemist project root |
| DRV-02 | Root ACL/owner and inherited access assessed BEFORE saving private diary |
| DRV-03 | Folders 00 System, 10 Diary, 20 Library, 30 Media, 40 Packages, 50 Catalog, 90 Technical all created with prescribed children |
| DRV-04 | Tree registry pathKey→folderId persisted with schema version |
| DRV-05 | Repeated bootstrap reuses same folders, does not create duplicates or relabel old user folders |
| DRV-06 | Folder creation/readback proves MIME, parent, owner, ACL; ambiguous duplicates fail closed |
| DRV-07 | Private configuration/grants/quarantine/diary inaccessible to public catalog APIs |
| DRV-08 | No anyone:writer permission and no raw Drive IDs in client projection |
| DRV-09 | Shared audio referenced from two modules without deleting used bytes after withdraw |
| DRV-10 | Live Drive folder-tree creation and readback only PASS if OAuth actually worked |
| CORE-01 | Real GAS V8 doGet/doPost+JSON envelope, no fake arbitrary HTTP status |
| CORE-02 | Health/capabilities/version без секретов доступны в живом deploy |
| CORE-03 | Feed/catalog list/get/search/filter/cursor и schema validation |
| CORE-04 | Diary drafts create/patch и отдельная private public projection |
| CORE-05 | Entry publish/edit/close/unpublish/reannounce/expiry live |
| CORE-06 | Diary text/category/order/image/audio/video/ContentLink fields |
| CORE-07 | Metadata-only edit повторно не передает media |
| CORE-08 | Media diff одной картинки передает только измененную картинку |
| CORE-09 | Manifest immutable snapshot до verified media не активируется |
| CORE-10 | Idempotency replay payload same returns old receipt, altered rejected |
| CORE-11 | Optimistic conflict etag/match checked, old revision preserved |
| CORE-12 | Server restart/partial failure не оставляет ссылку на битое медиа |
| CORE-13 | Audit and access denials без content/secrets |
| CORE-14 | Soft-delete and restore policies реализованы |
| CORE-15 | Public/index/preview and private/owner partition separate |
| CAT-01 | Catalog metadata is independent from Drive folder/file placement and private original stays private |
| CAT-02 | Album/track card shortAnnotation editable on author and persisted with correct ID |
| CAT-03 | Module card shortAnnotation editable on author and persisted |
| CAT-04 | Card supports title, optional description, category, tags, language, author, cover, version, visibility and release notes |
| CAT-05 | Track metadata contains real duration/bytes/MIME/SHA, never fabricated |
| CAT-06 | Module manifest orders track exact immutable revisions, pauses and dependencies |
| CAT-07 | Template manifest includes exact module dependencies and transitive install plan |
| CAT-08 | Author publication editor reuses existing library, not parallel duplicate media store |
| CAT-09 | Author publications page has draft/published/archive, status, search, withdraw and retry |
| CAT-10 | Draft and uploading content never appears in public client catalog |
| CAT-11 | Publish pipeline hashes, validates all dependencies and atomically switches catalog revision |
| CAT-12 | Retry is idempotent, no duplicate item/audio blobs after interrupted upload |
| CAT-13 | Metadata-only annotation edit leaves old audio bytes SHA and assetRevisionId unchanged |
| CAT-14 | Catalog supports track/module/template/session/collection/package/diaryEntry distinct types |
| CAT-15 | Search/list paginated index with category/tag filtering, status and restricted projection |
| CAT-16 | Client catalog shows annotations, download size, version, update and offline availability |
| CAT-17 | Client installation downloads only missing exact dependencies for module/template |
| CAT-18 | Client verifies download SHA and refuses mismatched/invalid package |
| CAT-19 | Client custom copy preserved during original update/withdrawal |
| CAT-20 | Private diary and unapproved entries never leak into public catalog or endpoint |
| CAT-21 | ContentLink from diary resolves exact catalog revision and matching dependency |
| CAT-22 | Publish/withdraw/reannounce with ETag conflict and tombstones preserves consistency |
| MEDIA-01 | Полный photo upload/download и SHA readback |
| MEDIA-02 | Полный многомегабайтный audio upload/download+playback |
| MEDIA-03 | Полный video upload/download Android playback (supported codec) |
| MEDIA-04 | Большой video/ZIP больше одного GAS request доставляется по частям |
| MEDIA-05 | Resumable upload interrupted/restart/resume и SHA check |
| MEDIA-06 | Resumable download resumed byte-ranges и SHA check |
| MEDIA-07 | Приватный data plane не отдает owner Google OAuth token/session URL |
| MEDIA-08 | Direct Google Drive route применен только с реальным user OAuth+ACL |
| MEDIA-09 | GAS secured chunk broker проверен для пользователей без Drive scopes |
| MEDIA-10 | Duplicate bytes/revision dedup с учетом ACL |
| MEDIA-11 | Большие файлы не грузятся целиком в память Flutter |
| MEDIA-12 | Ошибка квоты/лимита видна и не возвращает success |
| MEDIA-13 | MIME and declared size, extension, schema validated |
| MEDIA-14 | Video/audio недоступные Android-кодеки показывают ошибку |
| MEDIA-15 | Cache media повторно использует exact digest, не «latest» |
| PACK-01 | Пакеты сеансов/шаблонов/модулей/аудиосборников реально создаются |
| PACK-02 | ZIP включает declared audio/video assets либо отказывает с причиной |
| PACK-03 | ZIP сохраняется в Google Drive и readback SHA подтвержден |
| PACK-04 | Пакет versioned immutable, index/search/visibility доступен |
| PACK-05 | Пакет скачивается клиентом с живого сервера/Drive, не mock |
| PACK-06 | ZIP scanner: slip/bomb/manifest corruption detected |
| PACK-07 | Existing LocalCatalog installer installs verified ZIP |
| PACK-08 | Повторное скачивание/импорт не создает дубли |
| PACK-09 | ContentLink exact package revision работает из Diary |
| PACK-10 | Отозванные/private пакеты не выдаются читателям без ACL |
| PACK-11 | Export/import backup and rollback of user data validated |
| DATA-01 | Audio logicalId/revisionId/sha256 supports exact v1/v2 byte coexistence |
| DATA-02 | Old history/session reference resolves original audio bytes |
| DATA-03 | G3 migration backups/dry-run/rollback tests completed or FAIL-CLOSED noted |
| DATA-04 | Blob shared ownership/ref graph + no premature GC |
| DATA-05 | Activation cycles quiet edit/reannounce/close work exactly |
| DATA-06 | Per-reader read state remains isolated local/private |
| DATA-07 | Offline outbox queues retries without duplicate publish |
| DATA-08 | Independent two-device sync conflict recovery |
| DATA-09 | Restoring old code does not overwrite new data silently |
| DATA-10 | Soft deletion cleanup respects retention and references |
| APP-01 | Master author app REAL provider points at verified production /exec |
| APP-02 | Client app REAL provider points at same backend and own packageId |
| APP-03 | Author UI publishes diary with text/image/audio/video |
| APP-04 | Author UI uploads ZIP/audio collections and sees true progress |
| APP-05 | Client UI can find/download/apply packages from Google Drive |
| APP-06 | Client UI reads/journal/plays audio and video, offline |
| APP-07 | Google OAuth client login/secure token handling functions |
| APP-08 | No network credentials hardcoded in APK; no role-only grants |
| APP-09 | False online success prohibited, retry/error/outbox visible |
| APP-10 | Two APK artifacts produced from same source SHA, compatible signing |
| APP-11 | Client cannot access author editing and server rejects bypass |
| APP-12 | No destructive reinstall/clear of author data |
| LIVE-01 | Real cloud full chain master->GAS->Drive->client evidenced |
| LIVE-02 | Wrong auth and private access live negative cases evidenced |
| LIVE-03 | Real image, audio, video, ZIP byte hashes match |
| LIVE-04 | Interrupted live transfer/resume and conflict tested |
| LIVE-05 | Node unit tests cover failure injection and schema |
| LIVE-06 | Flutter tests, migrations and CI pass at final HEAD |
| LIVE-07 | All acceptance criteria uniquely reported PASS/PARTIAL/BLOCKED/NOT_RUN |
| LIVE-08 | Server scriptId/version/deployment URL only if independently proven |
| LIVE-09 | Real phone Android owner QA NOT_RUN until actually done |
| LIVE-10 | Report and resume point saved without secret leakage |

**Всего критериев: 147 (107 базовых + 32 каталога/Drive + 8 предпусковых).**
