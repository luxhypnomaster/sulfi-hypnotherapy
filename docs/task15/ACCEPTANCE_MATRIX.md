# TASK15 — МАТРИЦА ПРИЁМКИ

Всего **86 атомарных критериев**. Codex обязан дать для каждого PASS/PARTIAL/FAIL/BLOCKED/NOT_RUN и ссылку на конкретный тест или иной evidence. PASS из №14 не переносится автоматически на новые факты пользователя.

| ID | Требование | Проверка / доказательство |
|---|---|---|
| BAS-01 | Исходный Git SHA/branch/PR14/PR15 и dirty status проверены, база не переписана | git log/status + BASELINE_15 |
| BAS-02 | Текущие сервисы импорт/реестр/дневник/client edition найдены до правок | path+method audit |
| BAS-03 | Утверждённый RunScreen/PlayerArt/assets №13 сохранены | git diff restricted paths |
| BAS-04 | Состав актуального №14 сверяется с RESULT/TESTS без фальшивого DONE | BASELINE + 5 PARTIAL IDs |
| BAS-05 | Приватные данные, секреты, packageId/signing авторского APK защищены | git diff/CI/apksigner |
| UI-01 | A/B вставлены из одного library definition, изменён порядок только A → только A отмечен | widget + unit distinct occurrence IDs |
| UI-02 | Третий C из того же источника после правки A остаётся обычным | widget regression A B C |
| UI-03 | Undo A до исходного состава убирает метку только A | widget + semantic test |
| UI-04 | Навигация/сохранение/повторный вход не приводит к общему detached флагу | persistence test |
| UI-05 | Жёлтая метка (Изменено) отделена от имени и не хранится в name | UI TextSpan + model serialization |
| UI-06 | Название изменённого модуля фуксия+курсив, нейтральных обычное | render + style assert |
| UI-07 | Название шаблона на Home использует тот же отдельный жёлтый marker | home widget test |
| UI-08 | Unknown legacy source не получает ложный статус | semantic fixture |
| UI-09 | RunScreen по цветам и поведению не изменён | git diff + protected tests |
| UI-10 | Щит присутствует на Home safe top-right, открывает исходный sheet | UI screenshot + tap test |
| UI-11 | Щит в библиотеке не удалён и оба имеют общий selected role | widget two-entry test |
| UI-12 | На 320/360/412 и textScale 1/1.3/1.6 нет наложения shield/statusbar | responsive UI tests |
| UI-13 | Выбранный режим сохраняется/синхронен при возврате из библиотеки | state/navigation test |
| EXP-01 | Выборочный export называется Sulfi_exp_title_DD.MM.YY.zip без слова backup | fake file-picker assertion |
| EXP-02 | Русское имя транслитерируется, не переводится; originalTitle UTF-8 сохранено | transliteration fixture |
| EXP-03 | Filename безопасен на Android/Windows/ZIP, обработаны пустое/длинное/traversal имя | fuzz filename tests |
| EXP-04 | Дата локальная, UTC timestamp в manifest | timezone fixture |
| EXP-05 | Одинаковые имена не перезаписывают без предупреждения/суффикса | fake SAF duplicate test |
| EXP-06 | Full backup отдельный scope и Sulfi_backup_DD.MM.YY.zip | backup UI/export test |
| EXP-07 | Экспорт модуля включает audio, порядок, паузы, hashes/deps без приватной истории | ZIP fixture 3 audio+pause |
| EXP-08 | В UI виден импорт ZIP и действие ведёт в существующий LocalCatalog | UI route test |
| EXP-09 | Fresh DB roundtrip install→library/preview, повтор без дубликатов | integration roundtrip |
| EXP-10 | Conflict version/corrupt ZIP/insufficient space дают безопасный отказ | negative tests |
| EXP-11 | Системное Android Extract не выдается за импорт в приложение | copy/UX contract |
| REV-01 | Legacy schema9 populated migration сохраняет raw rows и media hashes | temporary populated DB snapshots |
| REV-02 | Старая аудиоревизия v1 и новая v2 сосуществуют с разными bytes | audio revision integration |
| REV-03 | Old history/run исполняет v1 после установки v2 | history playback fixture |
| REV-04 | Preview/library/resolver понимают exact audio refs, unknown legacy не ложно latest | readers tests |
| REV-05 | Два logical ID с одним SHA не удаляют совместные bytes при удалении одного | ref ownership/GC test |
| REV-06 | Metadata-only import и cross-ID dedup корректно оценивают новые bytes | dry-run tests |
| REV-07 | Staging/reserve отдельно от missing bytes | storage preflight tests |
| REV-08 | Cancel/commit failure не оставляет частично видимые content rows | fault injection |
| REV-09 | Crash/restart отдельно процесса не оставляет скрытого corruption | subprocess kill/reopen test |
| REV-10 | Legacy capsules 6/7/8/9 и same-package idempotence не ломаются | legacy fixture tests |
| REV-11 | Нет DROP пользовательских таблиц/удаления личных записей | migration diff + hashes |
| REV-12 | При блокере опасная миграция не применена, отчёт PARTIAL+stop reason | MIGRATION_BLOCKER if needed |
| DAY-01 | Существующие text/image/audio блоки с исходным порядком сохранены | existing diary fixtures |
| DAY-02 | 6 категорий с точными agreed names, безопасен unknown categoryId | model/filter tests |
| DAY-03 | Read не ставится открытием записи | reader widget test |
| DAY-04 | Последняя страница текста/графики ставит соответствующий partial completion | page test |
| DAY-05 | Аудио нужно действительно дослушать, seek-to-end alone не equals completed | audio player callback test |
| DAY-06 | Mixed запись read только после текста+аудио | mixed test |
| DAY-07 | Read state индивидуален readerId и cycle, не лежит в общей публикации | two reader fixtures |
| DAY-08 | Priority обычная vs высокая ротация, новая актуальная первая | scheduler deterministic test |
| DAY-09 | После прочтения запись уходит из Home rotation но остаётся в архиве | widget state test |
| DAY-10 | При отсутствии непрочитанных остаётся существующая заставка | home screen test |
| DAY-11 | Тихая правка без нового activationCycleId не сбрасывает read | metadata edit test |
| DAY-12 | Явная реанонсация меняет cycle и возвращает unread | reannounce test |
| DAY-13 | Manual close и timed expiry правильно скрывают активное но хранят архив | expiry tests fake clock |
| DAY-14 | Combined close выбирает более раннее событие | combined mode tests |
| DAY-15 | Offline timezone/UTC handling и перезапуск не реанонсируют ошибочно | clock persistence tests |
| DAY-16 | Author может добавить exact ContentLink в локальный черновик | ContentLink picker widget |
| DAY-17 | Старый reader ContentLink №14 умеет open/install/error по exact key | existing + new integration |
| DAY-18 | Unknown root/legacy diary fields сохранены | JSON roundtrip |
| DAY-19 | Manifest diff metadata-only mediaUpload=0; замена одного image upload=1 | fake upload recorder tests |
| DAY-20 | Author preview в дневнике без side effects, home preview только с real widget | preview test or blocker K008 |
| DAY-21 | Авторские операции не отправляются в live Apps Script | network spy / git diff |
| CLI-01 | Существующий SULFI_EDITION=client использован, не отдельный переписанный проект | build config and diff |
| CLI-02 | Client build не включает доступные авторские publish/edit routes | compile/test role guards |
| CLI-03 | Home shield в авторской edition не является серверным авторизационным токеном | UI and security note |
| CLI-04 | Author packageId/signature preserved, client artifact различим | apk diagnostics |
| CLI-05 | Client no embedded author secret/Google key | APK/source secret scan |
| CLI-06 | 2 independent temporary stores: author→fake provider→reader | end-to-end mock test |
| CLI-07 | ContentLink из provider устанавливает exact package и открывает existing player | e2e fake |
| CLI-08 | Read state только у client, не меняет author published manifest | two-profile e2e |
| CLI-09 | Reannounce/expiry появляется на client при обновлении fake feed | two-profile e2e |
| CLI-10 | No unauthorized author mutation from client mode via provider contract | permission-denied test |
| SRV-01 | Предоставлены API schema и contracts content/diary/blob/read/auth | SERVER_HANDOFF files |
| SRV-02 | Конкурентная publish попытка обнаруживает revision conflict | conformance test |
| SRV-03 | Повтор request с idempotency key не делает двойной publish/upload | conformance test |
| SRV-04 | Метаданные без новых бинарных байтов не вызывают upload | fake provider recorder |
| SRV-05 | Ссылка на media не раскрывает приватный Drive URL | schema/auth test |
| SRV-06 | Old/unknown optional fields сохраняются по политике совместимости | JSON schema conformance |
| SRV-07 | No live server/deploy/OAuth/Google ACL changes | git and service audit |
| SRV-08 | Есть чеклист двух телефонов с ручным тестом через реальный сервер | DEVICE_PAIR_RUNBOOK |
| DEL-01 | PROGRESS.md checkpoint на каждом выполненном Gate и корректная команда Resume | reports check |
| DEL-02 | Все acceptance IDs ровно по разу со статусом и evidence | matrix completeness script |
| DEL-03 | Targeted tests после Gate, full regression на финальном SHA | logs/full suite |
| DEL-04 | CI авторский APK и клиентский APK раздельно либо причина BLOCKED | CI artifact URLs and sha |
| DEL-05 | Физический Android и live server не названы PASS без проверки | RESULT accuracy |
| DEL-06 | P0 blockers/partial и SERVER_READY статус честно отражены | ISSUES_NEXT and SERVER_HANDOFF |
