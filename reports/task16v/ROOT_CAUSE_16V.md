# №16-В P0 — причина и границы доказательств

**STOP-SHIP. Инцидент владельца ещё не закрыт.** Статус: `MISSING_FROM_UI_AFTER_STANDARD_UPDATE; PHYSICAL_BYTES_UNKNOWN`.
Владелец подтвердил штатное обновление MASTER24→MASTER25 без удаления; повторного подтверждения не требуем. Исчезновение с UI одновременно собственных треков, модулей и черновиков — факт наблюдения владельца. Физическое стирание не установлено.

Новое подтверждение владельца по памяти: **пустые списки без ошибки загрузки**. Это снижает релевантность гипотезы явно показанного bootstrap/load-error, но не различает новую/пустую БД и фильтрацию. Повторного запуска телефона не просили.

Baseline: APK24 cbe05240d463b9dafbe9a12ee831c967bdbf6113; APK25 012f7f69b7ad99c0d44f2a442d9649aa1481117e. Изолированная hotfix-ветка от второго SHA; draft PR46. PR45 сохранён.

| Факт / механизм | Доказательство | Вывод / уверенность |
|---|---|---|
| Package/certificate не поменялись | APK24_APK25_READBACK_16V.json: независимые реальные apksigner verify/aapt; SHA соответствуют remote digest | PASS metadata; не доказывает состояние телефона |
| Android/build, storage repositories/models, access policy, pubspec.lock идентичны | STORAGE_SOURCE_COMPARISON.json с Git blob SHA | Изменение схемы/базовых путей в этом diff не найдено |
| DB version9, `getApplicationSupportDirectory()/library.sqlite`, `audio/` | app_database.dart; main.dart | Нет нового onUpgrade для24→25. Actual path владельца неизвестен |
| Полный инцидент tracks+modules+drafts | Только наблюдение владельца; физический sandbox недоступен | Root cause UNKNOWN; нельзя свести к одной авторизации |
| APK24 server-restored private diary draft с `_alchemistScope=google:<subject>` скрывается в25 | old AlchemistDiaryApi.readerScope; new DiaryController.load compares only account hash. Domain RED log: same verified MASTER sees [] despite existing row | CONFIRMED code-level read/filter defect, `ROWS_PRESENT_BUT_FILTERED` в controlled SQLite. НЕ доказан как причина всех пропавших материалов владельца |
| Утечка при снятии scope | Глобально снимать scope опасно | Minimal source alias only exact server-verified MASTER subject; other subject/CLIENT/guest denied |
| App bootstrap не ловит ошибку базы переходом к пустой БД | main.dart catch closes resources and shows failure; no delete/recreate fallback | Code PASS; нативные/физические crash состояния требуют отдельного доказательства |
| UI library/module queries | LibraryRepository.list без owner filter; ModuleCatalog.load без owner filter; library sections/category/search and module archived/origin/query separate | Scope change дневника не объясняет обе коллекции |
| Native прежний REL-03 | №16-Б injected SQLite fixture | Не является достаточным UI-created upgrade доказательством |

## Подтверждённый узкий fail → fix → pass

Контролируемый unit regression сохраняет старый формат private draft, два блока (text→audio), реальные тестовые media bytes; серверный ответ/идентичность — явная fixture, НЕ настоящий Google. APK25 load скрывает запись (RED). Минимальный alias-патч возвращает её тому же подтверждённому MASTER без UPDATE/INSERT diary row и без изменения media. Другой subject видит только собственную legacy запись, CLIENT/guest — ни одной; блоки и исходная строка byte/structurally equal (GREEN).

Патч не меняет readerScope, endpoint, роли, очередь, public feed, пути, схему, миграции или Google credential. Это не миграция и не восстановление удалённых данных.

## Что не установлено

`DB_FILE_MISSING`, `ROWS_ABSENT`, `PATH_CHANGED`, `SCHEMA_MIGRATION_ERROR`, `FILE_BYTES_MISSING_REFERENCES_PRESENT`, `UI_LOAD_EXCEPTION`, `ALTERNATIVE_ACCOUNT_SCOPE` на телефоне владельца — UNKNOWN. Ни одна гипотеза не объявляется диагнозом без копии/безопасной наблюдаемой информации. Итог native evidence и ограничения — UPGRADE_REPRO_16V.md.

## Существенное уточнение native dependency

`DEPENDENCY_SAFETY_16V.md`: реальный DEX24/25 идентичен и подтверждает default Android corruption handler на RW-open. Он может удалить повреждённый файл до Dart catch. Поэтому code-аудит отсутствия fallback в main.dart НЕ считается доказательством общей безопасности открытия повреждённой БД. Runtime fault probe выполняется только на helper-owned disposable DB, не над базой Sulfi и не у владельца. Наличие corruption на телефоне UNKNOWN; весь инцидент этим не объясняется без evidence. Эта неопределённость сохраняет STOP-SHIP.

Runtime подтверждение отдельного риска: Android35 run43259518712, controlled helper DB. Default RW изменил SHA повреждённого файла без исключения; read-only noop handler сохранил исходный SHA и вернул SQLiteDatabaseCorruptException. Полное before/after в DEPENDENCY_SAFETY_16V.md. **Инцидент владельца по-прежнему UNKNOWN**, поскольку наличие corruption до его upgrade не установлено.

Контролируемый native update run43265893487 сохранил3UI-created audio,2modules,1template,1history и их media SHA. Это не опровергает наблюдение владельца: его собственные объекты невидимы без ошибки, forensic bytes UNKNOWN. Его update действительно происходил; не маркируем его как «никогда не запускался». Machine-readable OWNER_OBSERVATION_16V.json отделён от formal owner recovery QA, которого ещё не было.

## Механизм, совместимый с «пусто без ошибки», но НЕ подтверждённый для владельца

При предпосылке реальной corruption native default RW-handler может заменить DB без исключения (helper-native доказательство). Далее:

1. app_database.onCreate создаёт новые пустые таблицы9 — обычный bootstrap может завершиться успешно без error screen.
2. LibraryService.initialize при пустых audio_assets/content_revisions/plans имеет пустой retained set; generated `audio/asset_*` считает сиротами и удаляет (read-only source audit, initialize lines≈100–175).
3. main собирает пустой author/public/private-cache set; DiaryMediaStore.collect(empty) может удалить не referenced diary media.
4. ModuleCatalog/LibraryRepository/DiaryAuthorRepository возвращают пустые списки; UI выглядит нормально, но пуст.

**Разделение доказательств:** native helper подтвердил только destructive/error-recovery поведение Android handler; пункты2–4 следуют из проверенного существующего кода при указанных пустых входах. Не вносили corruption в actual Sulfi DB, не вызывали этот путь на телефоне владельца. Наличие исходной corruption/срабатывание chain у владельца UNKNOWN. Это не окончательный owner root cause; версия не заменяет forensic bytes/log evidence и не даёт права на repair/GC/new APK.
