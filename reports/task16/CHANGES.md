# Изменения и сохранность

Дата:10.11.2026 UTC. Ветка feat/task16-alchemist-full-server. APK/sourcee4ed74b, service-test source6f1c8b9 (тот же lib/test код; версия21→22), GAS/version4/source766f178. Старый «Сульфи — дневник» не менялся. C0/PREFLIGHT сохранён, не повторялся.

[Real service E2E42878030592 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592): авторские Flutter-сервисы → существующий GAS → private Drive → отдельный клиентский SQLite/installer.6540746B загружено и6540746B скачано, WAV/AAC/PNG/MP4/ZIP и SHA проверены. Recovery42887239597, artifact13797585085; протокол LIVE_SERVICE_E2E.json и LIVE_TIMELINE.json. Это НЕ испытание двух установленных Android APK.

[Deploy42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006)/readback42876284145: anonymous JSON health, exact41 private folders/replay/live negatives PASS. [Обе APK22/CI42878716769 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878716769):419Flutter/33newNode/24oldNode/13schemas/formatter/analyzer/fixedCLIENT/package/signing PASS. Пока LOCAL_BUILD_ENDPOINT_NOT_CONFIGURED: владелец подтвердил, что Web OAuth client ещё не создан. Нужны официальные Web+две Android регистрации, см. ANDROID_OAUTH_SETUP_RU.md; clasp повторно авторизовывать не нужно. Физический Android NOT_RUN.


`server/alchemist/src`: Catalog, AtomicStore, Access, Bootstrap, GoogleJwt, GasFiles/GasFolders, GasTransfer/Transfer/MediaRuntime/Mime/Sha256, Manifest, Diary, Library, Operations, RateLimit, Router. `scripts/alchemist`: build, deploy/deploy-core/deploy-identity, check-build-config. Отдельные no-secret server checks, safe manual auth/deploy workflows. RSA vendor только переименовывается при сборке нового проекта; исходник старого сервера не меняется.

Flutter: services alchemist_api/identity_session/catalog/content_upload/media_transfer/install/diary_api, repository private cache; screens catalog/editor/store/sync, DiaryReader logout guard, DiaryVideo/MediaStore. Прежние library/modules/templates получают действия публикации. Точечный UTF8 HTTP fix, additive capsule MIME/video probe и GC references. Main art/RunScreen прежние, SQLite version9 без destructive migration; source files/IDs локальной библиотеки сохранены.

Новые regression suites task16 + server/alchemist/test исполняют реальный domain code, но контролируемый Drive не считается облаком. Две APK одного source из CI, стабильный ключ; невыполненные live/physical проверки перечислены отдельно. Checkpoint commits в PROGRESS.md и Git log; никакого reset/force-push опубликованной истории.
