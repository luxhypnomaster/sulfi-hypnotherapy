# №16-В — read-only diff и стартап

Точный diff приложений24→25 сохранён `APK24_TO25_APP.diff`. Полное сравнение storage blob SHA — `STORAGE_SOURCE_COMPARISON.json`; `UNCHANGED_STORAGE_SOURCE.diff` пуст, поскольку выбранные storage/Android/model файлы не менялись. Remote sources/draft assets сохранены в `REMOTE_BASELINES_16V.json`.

## Хранилище, миграции, упаковка

- `android/app/build.gradle.kts`: MASTER `ru.sulfi.sulfi_hypnotherapy`, CLIENT отдельный `.clienttest`; SULFI_EDITION=client меняет package только клиентской companion APK. Android source blob одинаковый. Вариант поставки debug, не маскируется под release.
- Реальные MASTER24 0.4.16/code24 и MASTER25 0.4.17/code25 прочитаны aapt, сертификат проверен apksigner, одинаковый SHA256 0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6. SHA файлов независимо соответствует зафиксированным asset digest. Android permissions, namespace/manifest/provider authority не менялись.
- `lib/main.dart:72–80`: Support directory, `library.sqlite`; audio=root/audio; дневник=root/diary_media; история=root/history_media. Shared prefs Google SDK не являются основной базой личного контента. Cache=temp, отдельно от files. Нет новой .nomedia или изменения support/documents API. Реальное Android-расположение проверяется native inventory, путь телефона UNKNOWN.
- `lib/data/app_database.dart`: version9 в обеих APK; additive onUpgrade для схем1–8, нет drop/deleteDatabase, нет `onDowngrade` destructive branch. Ошибка открытия пробрасывается, не возвращает пустую memory DB.
- `lib/data/library_repository.dart`: все audio rows без Google фильтра; fromMap strict может бросить на некорректном enum/JSON. LibraryScreen показывает load error, не считает это пустой базой. ModuleCatalog strict decode также может бросить; bootstrap не создаёт replacement DB.
- `lib/data/module_catalog.dart:45`: все определения + ревизии; никаких owner account partitions. UI скрывает archived, фильтрует origin/search. Эти правила в24→25 не менялись.

## Все значимые записи/очистки при запуске

1. main `_initialize`: creates support directory, cleans cache workspaces only; opens SQLite (foreign_keys/secure_delete configure). Existing DB не удаляется при ошибке.
2. LibraryService.initialize: legacy absolute/content URI copied to private generated filename, saved only after verified copy/probe; original external source не удаляется. Unchanged24/25. Старый private generated orphan cleanup может удалить `asset_*`, не referenced текущими rows/revisions/plans; uncertain revisions preserve bytes. Это существующий потенциально опасный путь при неполном исходном metadata, не доказанная причина нового инцидента. Без forensic snapshot безопасность owner запуска новой APK не обещаем.
3. FilePicker.clearTemporaryFiles касается picker cache. Не делает local library reset.
4. DiaryController.load/read-state: читает persisted drafts только в author workspace. В новой API роли подтверждает сервер. Guest/CLIENT author workspace закрыт уже в APK24; cold offline restore не является новой schema migration.
5. main diary collection: собирает **все** author rows непосредственно из authorRepository (не только видимые d.drafts), public cache и все scoped private entry values. При invalid IDs/private-cache decode cleanup пропускается. В25 дополнительно retains catalog covers; это расширение retention, не очистка tracks/modules. DiaryMediaStore.collect реально удаляет не retained files; неопознанные или неверные ссылки на owner media без snapshot безопасными не объявляем.
6. HistoryAttachments.collect: исключение при corrupt/missing reference прерывает collection, main ловит. Никакой записи в audio/modules.
7. SessionController.initialize: interruptUnfinished отмечает прерванные runs; reload читает modules/assets/templates/history/current_draft. Это не read-only программа, хотя её код сравнивается read-only. Не запускали на owner phone.
8. Новый25 restoreSignIn: SDK lightweight auth после инициализации; RAM identity, policy server role, load. Ошибка сети не вызывает delete/reset. Новый owner-bound queue recover меняет только app_settings work phase running→paused; не удаляет audio/module/diary rows. Не отправляет legacy unbound tasks автоматически.
9. main catch: failure screen «Данные не сброшены», закрывает ресурсы; ни fresh SQLite fallback, ни скрытый import. Эта надпись не доказательство, что чужой процесс ранее не изменил файлы.

## Scope / UI

APK24 readerScope `google:<verified-sub>`, APK25 `account:sha256(alchemist:endpoint:sub)`. Авторские local drafts24 обычно unscoped; server-restored drafts/remote projections могут иметь old scope. Новый25 фильтр допускает null/current only. Это подтверждённая несовместимость чтения legacy draft; исправление — точный alias, только для verified same MASTER, без переименования/перезаписи private rows.

Нельзя переносить этот диагноз на tracks/modules: их repository list не привязан к readerScope. Проверены отдельные разделы library (general/suggestions/personal), OR categories, поиск; module origins/archived. Ни variant/signing mismatch, ни ошибка владельца не утверждаются.

## Реальный бинарный readback

`BINARY_METADATA_16V.json`: обе MASTER APK independently SHA/apksigner/aapt прочитаны; permissions identical, root SQLite name и тот же endpoint/Web Client ID присутствуют в kernel. Полный manifest dump сохранён. Наличие строк kernel — вспомогательное evidence build config, не runtime owner identity. В обеих APK `allowBackup=false`, `fullBackupContent=false` и data_extraction_rules исключают cloud/device transfer. Поэтому стандартный Google Android backup не обещается как источник recovery. Вариант debug допускает run-as на disposable CI, но способ доступа к единственному телефону без ПК не доказан.

## Проверка ниже Dart-уровня

Все native DEX24/25 побайтно равны (17 файлов). Реальная sqflite Database.open имеет default Android corruption handler на RW-open; readonly open использует noop. Подробнее DEPENDENCY_SAFETY_16V.md. Утверждение об отсутствии delete/recreate относится к собственному Dart/Android-коду проекта, не гарантирует поведения Android SQLite при corruption. Этот риск проверяется отдельно; owner физические файлы UNKNOWN. Pinned backend не менялся.

## Flutter engine / native assets

Реальные libflutter.so и libsqlite3.so во всех трёх ABI одинаковы (SHA readback). Три libdartjni.so имеют разные полные SHA, но каждый отличается ровно20 байтами внутри .note.gnu.build-id; все остальные байты одинаковы, включая .text/.rodata/.data/dynamic symbols. Не маскируем это как одинаковые полные JNI SHA: точные данные ENGINE_LIBRARY_COMPARISON_16V.json, DARTJNI_ELF_COMPARISON_16V.json, DARTJNI_BYTE_DIFF_16V.json. Таким образом engine/backend code replacement в этих native библиотеках не найден; это не proof owner runtime files.

Уточнение journal: учитывать также `library.sqlite-journal`, не только WAL/SHM. В native24 inventories действительно присутствовал нулевой rollback journal; pinned sqflite WAL_ENABLED_BY_DEFAULT=false и explicit WAL metadata в APK не добавлялась. Режим/sidecars телефона UNKNOWN. Диагностический tool копирует/хеширует и rollback journal; неполная копия без hot journal не годится для recovery.
