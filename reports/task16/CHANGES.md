# Изменения и сохранность

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


`server/alchemist/src`: Catalog, AtomicStore, Access, Bootstrap, GoogleJwt, GasFiles/GasFolders, GasTransfer/Transfer/MediaRuntime/Mime/Sha256, Manifest, Diary, Library, Operations, RateLimit, Router. `scripts/alchemist`: build, deploy/deploy-core/deploy-identity, check-build-config. Отдельные no-secret server checks, safe manual auth/deploy workflows. RSA vendor только переименовывается при сборке нового проекта; исходник старого сервера не меняется.

Flutter: services alchemist_api/identity_session/catalog/content_upload/media_transfer/install/diary_api, repository private cache; screens catalog/editor/store/sync, DiaryReader logout guard, DiaryVideo/MediaStore. Прежние library/modules/templates получают действия публикации. Точечный UTF8 HTTP fix, additive capsule MIME/video probe и GC references. Main art/RunScreen прежние, SQLite version9 без destructive migration; source files/IDs локальной библиотеки сохранены.

Новые regression suites task16 + server/alchemist/test исполняют реальный domain code, но контролируемый Drive не считается облаком. Две APK одного source из CI, стабильный ключ; невыполненные live/physical проверки перечислены отдельно. Checkpoint commits в PROGRESS.md и Git log; никакого reset/force-push опубликованной истории.
