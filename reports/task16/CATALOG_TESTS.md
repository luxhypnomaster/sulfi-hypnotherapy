# Каталог — что реально проверено

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Текущая контрольная точка: de27d86.

Runtime consent подтверждён фактическим JSON, а не только ответом владельца. [Deploy 42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006) SUCCESS: existing Script/version4/source766f178, private bootstrap41, replay и отрицательные проверки. [Readback42876284145](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42876284145) подтверждает DEPLOYED_STORAGE_VERIFIED. Независимый anonymous HTTP200 application/json health повторно проверен; raw health.liveVerified=false — константа, не доказательство сквозной готовности. Старый «Сульфи — дневник» не изменялся.

Последние APK22: sourcee4ed74b, CI42878716769 SUCCESS,419Flutter PASS,33new/24oldNode PASS. Они пока без endpoint; подключёнными APK их не называем. Текущий Node33 PASS. [Первый live E2E42877004822](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42877004822) FAILED: media.beginUpload превысил20sec timeout. Изолированный новый transport исправлен,3regressionPASS. [Повтор42878030592](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592) выполняется, результат не предполагается. Android OAuth Web client ID отсутствует; законная настройка описана в ANDROID_OAUTH_SETUP_RU.md. Физический Android NOT_RUN.


`test/task16_catalog_integration_test.dart`: настоящий Dart+SQLite master service → HTTP localhost → production JS Catalog/AtomicStore/MediaRuntime → отдельная клиентская SQLite. Google Drive заменён контролируемым byte-adapter, не LIVE.

1. Трек: editable shortAnnotation → publish → reader metadata → exact install; SHA/asset refs и полная композиция проверяются.
2. Модуль:3трека/2паузы; после первого трека клиент скачивает только недостающее, повторные bytes не грузятся. Manifest и паузы сохраняются.
3. Потерян ответ publish: сохранён request/ETag, restart/replay получает старый receipt без дубля.
4. Аннотация меняется metadata-only: SHA/assetRevisionId звука не меняются, не передаются повторно. Второй авторский локальный store получает карточку и редактирует метаданные без исходных media files.
5. Collection, selective ZIP, current configuration/session и template проходят тот же uploader/resolver/installer; личные заметки и history в публикацию не попадают.
6. Withdraw закрывает новые bytes, установленная офлайн-копия остаётся.
7. Diary ContentLink разрешает точную ревизию модуля и устанавливает его прежним LocalCatalog. Неверная ревизия/digest и G3 конфликт отклоняются.

`server/alchemist/test/runtime.test.mjs`: private/public/restricted, source-owner grants, чужой private material нельзя перепубликовать публично только потому, что он доступен автору по read grant; отзыв исходного владельца закрывает чужие новые downloads. Regression10,000chunk receipts проверяет bounded ACL/card IO и cover grants. Feed/resolve/checkUpdates возвращают полный immutable manifest после reopen.

`task16_catalog_ui_test.dart`: сохранение аннотации офлайн при200%/360×640 с клавиатурой; module composition; fixed client без авторского редактора. PNG в комплекте — настоящие Flutter render на синтетических данных, не телефон и не успешная облачная публикация.

Live runtime/bootstrap PASS. Actual annotated track/module service loop42878030592 выполняется после исправления20sec timeout; Android SDK/physical client отдельно NOT_RUN. Публичный catalog.list независимо вернул200JSON, затем1опубликованную карточку; этого недостаточно для объявления полной установки.
