# Аудио, видео, изображения, ZIP-пакеты — полноценный транспорт

## 1. Два слоя обмена

**Control plane (GAS):** разрешения, метаданные, индексы, записи, manifests, создание resumable session, commit и аудит.

**Data plane (Google Drive):** фактические бинарные объекты. Не прогонять большой видеофайл целиком через `ContentService.createTextOutput`. Вместо этого выбрать для каждого transfer **действительно безопасный** путь:

A. **Direct Drive resumable**: клиент имеет собственный Google OAuth token с достаточными правами на КОНКРЕТНЫЙ опубликованный файл/область, Drive ACL сервера подтверждён, токен принадлежит пользователю; использовать resumable upload/download, 256-KiB-aligned chunks, восстановление range, SHA после скачивания. Не выдавать owner grant/client secret.

B. **Authenticated GAS chunk broker**: клиент не имеет Drive scope, общается только с GAS; серверный GAS авторизует запрос и выполняет bounded Range/PUT к Drive под законным owner execution identity через advanced Drive/UrlFetch; не отдавать Drive resumable session URL, owner access token или fileId. Хранить checkpoint и upload session приватно. Сильно ограниченный лимит на отдельный запрос компенсировать последовательными кусками, retry, resumable state и quota-aware backoff. Проверить, что выбранные native GAS APIs действительно поддерживают байты/Range, без догадок.

Внутри production можно поддерживать оба маршрута и выбирать по действующим OAuth/ACL и размеру. Для приватных медиа нет «Anyone with link» по умолчанию. Для специально опубликованных публичных файлов публичное чтение возможно по явно подтверждённому permission и отдельному ключу каталога, а не автоматическим расшариванием всех blob.

## 2. Форматы и полнота

Audio: mp3/m4a/aac/wav/ogg (поддержка raw bytes и MIME; декодирование в Flutter согласно доступным платформенным декодерам, без заявлений о всех кодеках без проверки). Video: mp4/h264/h265/webm/mov на уровне файлов/метаданных; приложение должно реально воспроизводить хотя бы поддерживаемые Android кодеки из выбранного набора, а не только хранить URL. Images: png/jpeg/webp. Archives: ZIP export/import, `manifest.json`, checksums, file list, sizes, encoding, source/appVersion, revision; цифровая подпись/манифест для неподменяемости при наличии ключевой инфраструктуры, иначе SHA плюс проверенный серверный источник.

Проверить 1) небольшой файл, 2) многомегабайтное аудио, 3) видео больше размера одного GAS запроса, 4) ZIP больше размера одного chunk, 5) прерванное соединение и докачку, 6) повторную загрузку без дублей, 7) точное совпадение SHA, 8) недоступный/удаленный/закрытый файл и отказ без утечки.

## 3. Пакеты

**Самостоятельный track и модуль не обязаны поставляться как большой ZIP:** клиент выбирает `track` → загружается одна exact аудиоревизия; выбирает `module` → download/install plan с точными ссылками и только недостающими треками; `template` → все недостающие транзитивные зависимости. ZIP нужен для офлайн-капсулы, экспортируемых комплектов и переносов. Каталог карточек с аннотациями, preview metadata и revision statuses управляет этими установками; см. `CONTENT_CATALOG_AND_STORAGE.md`. Предпрослушивание нескачанного audio не добавлять автоматически (K-016).


`PackageManifest`: packageId, type (session/template/module/audioCollection/otherSupported), title, description, authorId, visibility, media[], dependencies[], schemaVersion, createdAt/updatedAt, revisionId, SHA256 каждого blob и ZIP, packageContentHash, extension whitelist. ZIP не редактировать на месте: новый export → новая immutable revision. Сохранять старый пакет до отсутствия ссылок.

Автор: create/export bundle → save to Drive private → verify readback bytes/hash → optional public/allowed publish → add to catalog → viewer token/ACL check → download with resumable transfer. Клиент: list/search → choose → download → size/SHA/manifest/schema/zip-slip/zip-bomb validation → safe import with collision resolution and transactional local write → preview/play or install → offline history; повторное импортирование не создает идентичные assets.

Пакеты должны включать не только текстовую структуру, но и реально вложенные аудиотреки, если они по контракту входят в экспорт; `manifest` должен различать linked/private/non-exportable content и честно отказывать, а не выдавать ZIP без нужных звуков.

## 4. API+quota поведение

Apps Script ContentService выдаёт **только TextOutput**, а `doGet/doPost(e)` не документирует `headers` или полноценный `Range`/binary HTTP response. Вариант broker должен быть честно построен как bounded JSON/base64 chunks (с соответствующим overhead и verify), а direct Drive как Google OAuth+точечные ACL; ни `GAS HTTP 206`, ни `response.headers.Authorization`, ни нескончаемый приватный video stream не предполагаются без LIVE доказательств. Тестировать реальную выдачу на Android, а не только Node mock.


Google Apps Script 6 min per invocation, UrlFetch POST/response ≤50 MB per request по текущей документации, суточные лимиты; chunk size выбирается заведомо ниже реального лимита с запасом, server budget/timeout и retry-after. Внешний Drive API поддерживает resumable uploads, минимум выравнивания промежуточных чанков по 256 KiB. Предпочитать безлимитность по размеру КОНЕЧНОГО файла на уровне интерфейса с допустимыми реальными ограничениями хранилища/прав/квот, а не произвольное «видео максимум 5 МБ». Реальные ограничения фиксировать в capabilites, диагностику показывать человеку, не silently truncate.

Документация: https://developers.google.com/workspace/drive/api/guides/manage-uploads ; https://developers.google.com/apps-script/guides/services/quotas ; https://developers.google.com/apps-script/reference/content/content-service .

## Directory and online catalog distinction

Follow mandatory `CONTENT_CATALOG_AND_STORAGE.md`: physical Drive folders for immutable assets and manifests, separate catalog indexed cards with annotations, metadata-only revisions, `track`/`module`/`template`/`session`/`collection`/`package`/`diaryEntry` state and public projection; an audio file can be shared by multiple modules without duplicate bytes. Upload + hash readback + atomic publish and package manifest; interrupted upload remains unpublished. Use no fake unlimited binary streaming via GAS web app; measured/authorized chunk transport or proven OAuth Drive resumable route only.
