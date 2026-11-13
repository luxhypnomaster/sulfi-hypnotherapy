# №16-Г — изменения

База b0cb53f (PR46), production25 source012f7f69 и исправления PR45 сохранены. Отдельная ветка fix/task16g-stabilize-programs, draftPR47; main/PR45/46 не merged.

## G1

- `third_party/sqflite_android` — pinned upstream2.4.5 с исходной MIT license; список исходных SHA в SQFLITE_UPSTREAM_16G.json. Единственный изменённый upstream Java файл Database.java: оба open делегируют StorageSafety.open. Новый callback бросает SQLiteDatabaseCorruptException и не вызывает DefaultDatabaseErrorHandler, delete/recreate или recovery retry. Никакой новой SQLite engine/schema/API версии.
- `lib/data/storage_preflight.dart` + app_database.dart: существующая DB+WAL/SHM/journal копируется в отдельную временную директорию; проверка неизменности источника, RO integrity/version/required tables/JSON на derivative до RW. Missing DB при media/sidecars/ready-marker, нулевой/corrupt/неполный файл fail-closed. Удаляется только derivative. Hot rollback journal не восстанавливается поверх оригинала.
- main.dart: без startup diary/history media collectors; ready-marker создаётся только после успешного bootstrap, нет schema migration. LibraryService.initialize сохраняет неопределённые orphan/partial bytes; явные пользовательские delete/reset/discard остаются. Cache capsule workspace очищается только после безопасного DB open. UI ошибки не предлагает reset/uninstall.
- Verified same-MASTER legacy scope alias из PR46 не расширен на других accounts/CLIENT/guest. Старые тестовые данные владельца не восстанавливаются.

## G2

Existing GoogleDiaryIdentity/DiaryController, AlchemistApi, transfer queue/catalog/install не переписаны. Проверены existing singleflight restore/refresh,401/403/DNS/abort и owner-bound retry. Расширен production Dart→JS controlled E2E: module3tracks+pauses → program/template → diary publication+text update → exact ContentLink → CLIENT dependency install, без повторной загрузки committed media. Эти fixtures НЕ настоящие Google users/Drive.

## G3

18user-facing label/error/category files: «Программа/Программы» с правильными склонениями в MASTER/CLIENT, Home, конструкторе, истории, библиотеке/каталоге, капсуле, дневнике. Пользовательские старые имена не переименовываются. Внутренние ContentType.template, session_templates, baseTemplate*, route/type/template JSON/ContentLink и capsule schema/ID не изменены. Legacy roundtrip+MASTER/CLIENT widgets проверяют это. Курс/анкета/редизайн не добавлены; K-034/K-036 остаются future backlog.

## G4

Version0.4.18+26 для ограниченного кандидата; свободен среди existing releases. Условный manual workflow из trusted16Gbranch: full checks → прежний signing key → certificate/package/SHA → actual UI25→26/cold/CLIENT smoke → только затем private draft assets. При опасном/непроверенном native gate файлы не выдаются. Не используется CLASPRC_JSON, нет GAS deploy/OAuth settings/Drive ACL mutations. Допустимость выдачи фиксируется в RESULT_16G по фактическому CI.

Подписанные внутренние сборки трёх CI-попыток дали идентичные SHA пары. Для native QA повторно используется только неизменный producer9b94f24 из приватного CI-кэша: без Flutter/Gradle rebuild и без доступа к signing secrets. Отдельный свежий native runner устранил измеренное ограничение свободного места. Драйвер требует реальные UI-объекты и SQL readback производной копии; нажатия Save защищены от перекрывающей экранной клавиатуры. Финальные ссылки допустимы только после всех gates.
