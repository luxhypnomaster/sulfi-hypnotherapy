# Изменения и сохранность

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Текущая контрольная точка: de27d86.

Runtime consent подтверждён фактическим JSON, а не только ответом владельца. [Deploy 42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006) SUCCESS: existing Script/version4/source766f178, private bootstrap41, replay и отрицательные проверки. [Readback42876284145](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42876284145) подтверждает DEPLOYED_STORAGE_VERIFIED. Независимый anonymous HTTP200 application/json health повторно проверен; raw health.liveVerified=false — константа, не доказательство сквозной готовности. Старый «Сульфи — дневник» не изменялся.

Последние APK22: sourcee4ed74b, CI42878716769 SUCCESS,419Flutter PASS,33new/24oldNode PASS. Они пока без endpoint; подключёнными APK их не называем. Текущий Node33 PASS. [Первый live E2E42877004822](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42877004822) FAILED: media.beginUpload превысил20sec timeout. Изолированный новый transport исправлен,3regressionPASS. [Повтор42878030592](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592) выполняется, результат не предполагается. Android OAuth Web client ID отсутствует; законная настройка описана в ANDROID_OAUTH_SETUP_RU.md. Физический Android NOT_RUN.


`server/alchemist/src`: Catalog, AtomicStore, Access, Bootstrap, GoogleJwt, GasFiles/GasFolders, GasTransfer/Transfer/MediaRuntime/Mime/Sha256, Manifest, Diary, Library, Operations, RateLimit, Router. `scripts/alchemist`: build, deploy/deploy-core/deploy-identity, check-build-config. Отдельные no-secret server checks, safe manual auth/deploy workflows. RSA vendor только переименовывается при сборке нового проекта; исходник старого сервера не меняется.

Flutter: services alchemist_api/identity_session/catalog/content_upload/media_transfer/install/diary_api, repository private cache; screens catalog/editor/store/sync, DiaryReader logout guard, DiaryVideo/MediaStore. Прежние library/modules/templates получают действия публикации. Точечный UTF8 HTTP fix, additive capsule MIME/video probe и GC references. Main art/RunScreen прежние, SQLite version9 без destructive migration; source files/IDs локальной библиотеки сохранены.

Новые regression suites task16 + server/alchemist/test исполняют реальный domain code, но контролируемый Drive не считается облаком. Две APK одного source из CI, стабильный ключ; невыполненные live/physical проверки перечислены отдельно. Checkpoint commits в PROGRESS.md и Git log; никакого reset/force-push опубликованной истории.
