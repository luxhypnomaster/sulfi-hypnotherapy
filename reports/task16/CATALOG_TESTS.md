# Каталог — что реально проверено

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


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

LIVE annotated track→module→Drive→Android client: BLOCKED: GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML.
