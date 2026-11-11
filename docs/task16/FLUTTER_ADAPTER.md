# Две Android-редакции — полный рабочий клиент серверной экосистемы

Одна Flutter codebase. Исходная author APK — `ru.sulfi.sulfi_hypnotherapy`, сохранить signing, upgrade и все SQLite/файлы. Client APK — отдельный package `ru.sulfi.sulfi_hypnotherapy.clienttest`, режим fixed to client. Интегрировать, а не дублировать `DiaryContractProvider`, `DiaryController`, `LocalCatalogSource`, `ContentLink`, `ImportExport`, `RunScreen`, `Audio`, modules/templates/sessions.

## Нужные экраны и потоки

**Авторская редакция:** Google sign-in/session indicator (либо существующее безопасное auth), выбор privacy/публикации, создание и редакция diary media blocks включая видео, список синхронизации, прогресс media upload и ZIP export, управление опубликованными материалами, контентные ссылки на пакеты, публикация/отмена/quiet edit/reannounce/close. Загружать на Drive ZIP и звук через server endpoint, импортировать обратно. Сохранять офлайн черновик независимо от ошибок сервера.

**Редактор публикаций автора (обязателен):** из существующих `Библиотека/трек`, `Модули`, `Шаблоны` и `Сборки` — `Подготовить к публикации`, карточка с аннотацией/тегами/категориями/обложкой/видимостью/версией, проверка состава и preview карточки, upload progress, publish receipt. Отдельное управление `Каталог публикаций`: `Черновики/Опубликовано/Архив`, редактирование/снятие/обновление версии/повтор ошибки. Правки описания не пересылают аудиобайты; не создавать дубликат локального `Library` или `CapsuleService`. Дальнейшие поля и contract — `CONTENT_CATALOG_AND_STORAGE.md`.

**Клиентская редакция:** каталог опубликованных дневников/шаблонов/модулей/пакетов/аудио/видео, поиск/фильтры/прочтение/просмотр/прослушивание, скачивание ZIP/аудиобиблиотек, безопасный импорт в локальный каталог, отметка версий и прогресс загрузки, офлайн открытие и воспроизведение; private доступ с auth только когда контент требует его. Нет UI авторских операций и нет серверного права даже при модифицированном клиенте.

**Клиентская витрина:** отдельные карточки `track/module/template/collection/package` с title/shortAnnotation/cover/version/duration/size, exact manifest и status `не скачано/скачано/есть обновление`. Кнопки `Скачать/Установить/Обновить`; для модуля докачать только недостающие точные track versions, для шаблона все dependencies; пользовательские форки/копии сохранять. Каталог не должен требовать предпрослушивания до скачивания — K-016. Ссылка из дневника `ContentLink` ведёт на точную ревизию выбранного элемента.

**Media UX:** кнопки начать/пауза/продолжить/отмена, bytes sent/total, докачка после сетевой ошибки, preview images/video, корректные codec errors; для large media сохранять chunk checkpoints на диск, не держать весь фильм в памяти. Видеоплеер реальный, не одна картинка/ссылка. Манифест и SHA проверяются до «Готово» и установки пакета.

**Transport:** реальный `/exec` из конфигурации сборки или remote config с pin/allowlist, не фейковый URL; JSON envelopes и unknown action fail; GET public только на опубликованных данных, все мутирующие операции POST с подтвержденным identity. Redirect/HTML/OAuth error, wrong content-type, timeout, backoff+jitter, retry/idempotency, conflict visibility. Никогда не хранить owner OAuth refresh в APK и не полагаться на UI role switch.

**Data layer:** `FakeProvider` только для автономных unit/contract tests; в реально подключенной APK provider выбирает GAS. Состояние офлайн/синхронизации чёткое. Не маркировать публикацию успешной до удалённого commit+readback.

**Revisions:** решить G3 в отдельной схеме (см. DATA_AND_REVISIONS); full backup перед миграцией, never uninstall. Существующий пользовательский RunScreen и Play List не ломать.

**CI/artifacts:** два APK одной версии/source SHA, author package signing verified vs previous, client separate sandbox, actual endpoint embedded only if verified deployment. Дать скачивание обоих артефактов, версию, checksum и установочный порядок. Физический Android только владелец, результат не фальсифицировать.

## Publication UI and client catalog adapter

Mandatory from `CONTENT_CATALOG_AND_STORAGE.md`: reuse existing LocalCatalog/CapsuleService/AudioAsset/Module/Template/ContentLink, implement author action `Подготовить к публикации` with editable title/shortAnnotation/description/category/tags/visibility/releaseNotes/cover, draft/outbox/progress/retry/published UI and author `Каталог публикаций` statuses/search. Add client online catalog with card/annotation/detail/size/version/dependency/install/update/offline status, no accidental auto-download and no duplicate replacement of user-edited own copies. Exact dependencies preserved through install and offline updates. Publish ZIP is not equivalent to catalog publish; test against real server when available.
