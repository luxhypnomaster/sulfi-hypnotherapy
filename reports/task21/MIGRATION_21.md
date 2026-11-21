# MIGRATION / ROLLBACK №21

**Production migration NOT_RUN и не разрешена.** Схема пользовательской SQLite9, applicationIds, versionCode28, signing и local media paths не менялись. Никакие личные БД/телефоны не открывались.

Добавочные app_settings записи:
- `catalog20:<digest(owner,scope)>:prepared:<snapshotHash>` и `:current` — прежняя схема №20; prepare отдельно, текущая ссылка меняется одной SQLite transaction после verify.
- `vitrine21_current:<digest(owner,packageScope)>` — отдельный проверенный config head/snapshot.
- `vitrine20:<digest(readerScope)>` — существующий saved namespace сохранён; только добавочные appliedRevision/appliedHead/receipt/pendingExpectedRevision. Испытание старого local saved9→новый settings store PASS. Без автоматического default/reset.
- Existing `alchemist_download` kind `catalogSnapshot20` и existing queue18; no worker/database recreation. USER_PAUSED не возобновляется автоматически.

Disposable retention regression: seed15 создаёт3личных аудиофайла и прежние library/modules/templates/history/diary rows. До/после metadata sync, corrupt response, actual503/403 все non-app_settings таблицы сравниваются canonical целиком, каждый media SHA тот же, PRAGMA integrity_check=ok. Old outbox/queue tests остаются в общей suite. Это Linux SQLite FFI, **не native update APK28→новая версия**.

Исторический PR46/16-В риск видимости данных не объявляется окончательно объяснённым. Сохранён существующий no-delete bootstrap, SQLite/WAL/transaction scheduler protection, отсутствует GC/reset/migration. Старое восстановление не выполняется; исходные отчёты №16–20 и APK28 сохранены. Новый native upgrade safety gate BLOCKED_ENV.

Безопасный кодовый откат до production: оставить compile flag OFF/legacy API, отклонить draft PR. Экспериментальные namespace можно оставить в БД; удалять пользовательские записи не требуется. Если когда-либо будет согласован бинарный выпуск, исправления выпускаются новым увеличенным versionCode и прежним сертификатом после upgrade gate; uninstall/clear/downgrade не предлагаются.

Серверного rollback в этом этапе нет: live GAS6 не изменён. Для будущего provider binding нужны exact diff/readback, atomicity/ACL proof, staged verification, согласованная source+deployment rollback процедура и отдельное разрешение владельца.
