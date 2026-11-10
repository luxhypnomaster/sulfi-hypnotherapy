# №16 — обязательный каталог публикаций и физическое хранилище Google Drive

Этот документ — **часть того же задания №16**, не новая задача/проект. Владелец специально потребовал полноценную выгрузку из мастер-приложения в каталог с аннотациями, которую клиентское приложение читает и устанавливает. Нельзя ограничиться `catalog.list` и кнопкой «выгрузить ZIP». Сверить с K-012, K-013, K-014, K-016 (выборочная установка без обязательного предпрослушивания до загрузки), K-018 и K-022, а также существующими `LocalCatalog`, `CapsuleService`, `AudioAsset`, `Module`, `Template`, `ContentLink`. Реализовать в составе текущей Flutter codebase и GAS backend, не создавать вторую параллельную библиотеку.

## 1. Разделить физические файлы и логический каталог

**Drive physical storage**: закрытые для посторонних folders/files, точные byte blobs, версии, ZIP, метаданные, backup. **Publication catalog**: типизированный реестр карточек (название, аннотация, категория, версия, доступность, зависимости, контрольные суммы), индекс и API для клиентов. Запись в папку ≠ публикация; публичность/видимость/авторизация определяется реестром и проверкой на сервере, а не фактом нахождения файла по Drive URL. Нельзя рассчитывать на поисковый индекс Google Drive как на API пользовательского каталога.

Реестр должен поддерживать самостоятельные виды: `track`, `module`, `template`, `session`, `collection`, `package`, `diaryEntry` (плюс optional `image`/`video` при нужной публикации). У каждого `catalogItemId`, `type`, `logicalContentId`, `immutableRevisionId`, `visibility` и `publicationState`; бинарные данные и карточки версионируются независимо. Один и тот же трек может быть самостоятельной карточкой, частью нескольких модулей и частью ZIP-сборки без обязательного повторного хранения аудиобайтов.

## 2. Физические папки: автоматический bootstrap в проекте владельца

Уже существующая папка Google Drive `Проект Алхимик`, ID `1b-FP_emjwE5LpTyx4TFzkbzlffEE7pLl`. При предыдущей проверке её Drive metadata показывала owner-only (`shared=false`, только permission owner); **проверить это повторно при реальном bootstrap**, включая inherited/limited-access permissions. **Не создавать файлы с персональными дневниками в папке, если её фактическая приватность не подтверждена.** Если ACL родителя изменился и ограничить наследование невозможно/небезопасно, fail-closed и предложить отдельный приватный root на My Drive с безопасным ярлыком в проекте; не утекать личным контентом ради соблюдения расположения.

Создать под существующим корнем ровно одну приватную папку: **`Хранилище Сервера Проекта Алхимик`**. Её внутренние именованные подпапки (человекочитаемые названия, устойчивые IDs; английские machine keys в коде):

```text
Проект Алхимик/
  Хранилище Сервера Проекта Алхимик/
    00_Система/
      config/  registry/  indexes/  grants/  audit/  backups/
    10_Дневник/
      entries/  images/  audio/  video/  revisions/
    20_Библиотека/
      audio_tracks/  modules/  templates/  sessions/  collections/
    30_Медиа/
      covers/  images/  audio_other/  video_other/  immutable_blobs/
    40_Пакеты/
      drafts/  published/  imports/  archived/
    50_Каталог/
      publications/  index_shards/  snapshots/  tombstones/
    90_Техническое/
      pending_uploads/  quarantine/  temp/  gc_candidates/
```

**Особенности:**
- Физический файл имеет один parent в Drive; если актив используется в разных разделах, повторно используем его `assetRevisionId` в реестре/манифестах (а не копируем байты во все папки). Отдельные `audio_tracks/` для библиотечных звуков и `10_Дневник/audio/` для аудиовложений должны быть видимы владельцу; техническое хранилище immutable blobs можно использовать для общих/дедуплицированных байтов с логическими связями.
- Все папки создаются через Drive API по `parents`, с registry pathKey→folderId; `bootstrap` create-if-missing, строго idempotent: сначала найти по известному ID+parent, при отсутствии найти по exact name+parent, при неоднозначности остановиться и сообщить, не создавать третий дубль. Проверить тип MIME, owner, ACL, доступность и readback. Никогда не делать `anyone:writer`. Сохранить root ID и tree schema version отдельно от редакций пользовательского контента. Повторные деплои не пересоздают папки.
- Разделить archive/backup от обычного удаления; не удалять используемые аудиобайты из-за снятия карточки с публикации. Схема резервирования, restore и dry-run миграций обязательна.
- `config`, identity/grants, черновики дневника, `pending_uploads`, originals не доступны через публичный API. Публичный индекс содержит только разрешённую проекцию и opaque IDs; никаких raw Drive folder/file IDs, приватных путей, grants, токенов.
- Не превращать каждый тег/категорию в папку. Категории и теги — поля индекса, некоторые медиа shared между типами. Для масштабирования индексировать карточки по типу/фрагментам/shards или явно обоснованному registry; не перезаписывать одним гигантским JSON весь каталог при каждой публикации.

## 3. Карточка каталога / аннотация

Обязательные **редактируемые автором** поля: `title` (заголовок), `shortAnnotation` (1–3 строки для карточки), `description` (расширенное описание, optional), `categoryIds[]`, `tags[]`, `language`, `authorDisplayName`/правообладатель, `coverAssetId` (optional), `visibility` (`private`, `public`, `restricted` с реально поддерживаемым ACL), `publicationState` (`draft`,`uploading`,`ready`,`published`,`withdrawn`,`archived`,`failed`), `releaseNotes` для обновления (optional). Поля для трека: подтверждённые `durationMs`, размер, MIME/format, optional `contentWarning`/`useContext`/краткая инструкция. Для гипнотических упражнений допускается понятная заметка по безопасности, но не требовать медицинских заявлений или ложных показаний. Технические автополя: `catalogItemId`, `assetRevisionId`, `manifestRevision`, `sha256`, `byteLength`, `schemaVersion`, `createdAt`, `publishedAt`, `updatedAt`, `dependencyRefs`, `minimumClientVersion`, `sortOrder`, status/capabilities. Не выдумывать duration, credits, лицензии.

**Модуль** содержит карточку + manifest с ordered `steps` (trackRef с **точными** logicalId/revisionId/sha256, pauses, timing/mode/settings) и полным transitive dependencies. **Шаблон** ссылается на модули/фазы/паузы и их версии. **Сборка** группирует несколько треков/модулей и optional ZIP. Обложка и аннотация не меняют checksum звука. Публикуемый состав фиксируется immutable revision; редактирование аннотации создаёт только metadata revision и новый индекс, не дублирует MP3. В карточке клиента явно показывается размер загрузки и уже установленные/отсутствующие зависимости; отсутствие optional preview-audio до скачивания — согласованная граница K-016.

## 4. Авторский экран «Каталог / Публикации» и жизненный цикл

Не заменять существующую библиотеку. В ней для выбранного трека, модуля, шаблона или сборки добавить действие **«Подготовить к публикации»** (или согласованное с текущим UI словосочетание), открывающее редактор карточки. Отдельный раздел мастер-приложения **«Каталог публикаций»** с вкладками «Черновики / Опубликовано / Архив» и поиском: видеть реальные статусы сервера, изменять аннотации, категории, обложку, видимость, порядок/версию, снять публикацию, выпустить новую редакцию, повторить сбойную загрузку, проверить зависимости. Редактирование/предпросмотр карточки само не публикует.

Пайплайн (автор полностью с телефона): `select local item` → `edit card/annotation` → `validate all dependencies and ownership` → `save local draft/outbox` → `upload only missing immutable blobs` → `readback size+SHA` → `upload manifest/metadata` → `server validate publication and grants` → `atomic switch published revision + catalog index` → `server receipt + client-visible readback` → `UI shows Published`. Прерыванию сети/ошибке соответствует retry; незавершённое не показывается клиенту. Повторная выгрузка идентичных данных не создаёт новый файл или карточку; обновлённое описание не перезаливает звук. Отмена публикации убирает из поисковой выдачи, но не уничтожает зависимости/локальные копии; архив можно восстановить. Публикация «private» не попадает в общедоступный каталог. Экспорт ZIP на Drive и **публикация карточки** — две разные операции с отдельными статусами и явным подтверждением доступности.

## 5. Клиентский каталог и локальная библиотека

Раздел **«Каталог»** в клиентском приложении (или логично встроенный экран в существующую «Библиотеку») с карточками треков/модулей/шаблонов/сборок: название, аннотация, категория, длительность при наличии, размер, обложка, версия, статус «не скачано/скачано/есть обновление», фильтры и поиск, пагинация и pull-to-refresh. Карточка → подробности + точный состав/зависимости + **«Скачать / Установить / Обновить»**. Из публикации дневника можно открыть exact ContentLink на карточку. Медиабайты скачиваются из авторизованного data plane, SHA проверяется, ссылки проверяются по exact revision, используем действующий `LocalCatalog` и безопасный installer.

Скачивание трека должно устанавливать один трек; скачивание модуля — его manifest и только недостающие необходимые треки/ресурсы; шаблон — транзитивные зависимости; ZIP collection — пакет с проверенным manifest. В уже скачанной локальной версии работать офлайн; пользовательская собственная копия/переименованные/редактированные материалы не заменяются обновлением авторского оригинала. Отзыв публичной публикации скрывает предложение новых скачиваний, но не удаляет локальные пользовательские данные. Статус client library защищён от смешивания author/private identities.

## 6. Контракт API каталога

Дополнительно к `catalog.list/search/get`, реализовать `catalog.createDraft`, `catalog.patchDraft`, `catalog.attachAsset`, `catalog.validateDependencies`, `catalog.publish`, `catalog.updateMetadata`, `catalog.withdraw`, `catalog.archive`, `catalog.restore`, `catalog.getRevision`, `catalog.diff`, `catalog.getInstallPlan`, `catalog.checkUpdates`; permissions owner/author на mutations, public/restricted projection на read. Reusable methods: `track.publish/track.get`, `module.publish/module.getManifest`, `template.publish`, `collection.publish` могут быть алиасами только при единой семантике. У карточки есть `etag` + idempotencyKey, у feed версионированный cursor/nextPage и tombstones. Экспорт пакета: `package.prepareFromSelection`, `package.verifyManifest`, `package.publish` + readback.

Нужны тесты на пять независимых типов публикации (трек, модуль, шаблон, сборка, дневник), точные привязки track→module→template, карточки с аннотациями, metadata-only правку, невалидную зависимость, privately drafted not listed, public readers see only published, reader cannot publish, recovery после interrupted upload, rollback на stale ETag, no duplicates after retry, removal and reannounce, update/install only missing, same asset shared by multiple modules и сохранение client custom copies. В отчёте показать реальные серверные записи каталога и соответствующие файлы в нужных папках Drive (с доказательством readback, без экспорта private data).

## 7. Реалистичная транспортная граница (обязательная проверка ДО риска потери данных)

`doGet/doPost` Apps Script документируют `e.parameter`/`e.postData.contents`, но НЕ гарантируют доступ к произвольным HTTP Authorization/Range headers. `ContentService` возвращает `TextOutput`/JSON, а не полноценный MP3/MP4 binary HTTP response с собственными status/header/Range. Поэтому **НЕ закладывать** `request.headers.Authorization` на стороне GAS как обязательный механизм; токен клиента/подписанное приложение удостоверять в допустимом HTTPS POST JSON envelope и проверить `aud/iss/exp/sub` на сервере, либо использовать реально поддерживаемый identity механизм (не класть bearer в URL/logs). Для download through GAS требуются строго ограниченные chunk JSON/base64 с проверкой ACL на каждый chunk, без обещания бесконечного видео streaming или 206 Range от ContentService. Прямой Drive route использовать только с документально и LIVE проверенным user OAuth + ACL; иные способы выдачи приватного video data plane требуют отдельного авторизованного backend и не должны маскироваться как уже работающие.

Документы Google: https://developers.google.com/apps-script/guides/web ; https://developers.google.com/apps-script/reference/content/content-service ; https://developers.google.com/workspace/drive/api/guides/manage-uploads ; https://developers.google.com/workspace/drive/api/guides/manage-sharing ; https://developers.google.com/workspace/drive/api/guides/folder .
