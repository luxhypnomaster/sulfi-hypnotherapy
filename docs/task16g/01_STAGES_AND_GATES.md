# Порядок выполнения и контрольные точки

## G0 — компактное подтверждение базы и рисков (без разработки)
1. Git status/HEAD ancestry PR45/46/main; убедиться, что исправления transport/auth из №16-Б и scoped-alias из №16-В не потеряны. Проверить реальные схемы/взаимосвязи только файлов хранения, OAuth и каталога; составить **короткую** карту «существует / дефект / что не трогаем».
2. Baseline: GAS v6, 2 package names, same signing cert, текущая DB schema9, persist paths и поведение `sqlflite` corruption recovery; т.к. исходный код частично изменён, проверять diff против реальных commits.
3. Согласовать краткий план min-change без архитектурных переписываний и показать P0 риски. Не делать повторные исследовательские PR или exhaust all-tests здесь.

## G1 — P0 сохранность при обновлении / fail-safe storage
1. Исключить **молчаливую замену повреждённой библиотеки пустой**: обработка corruption native SQLite до открытия RW, надёжное определение неполной/пустой/повреждённой базы, non-destructive fail-closed без запуска orphan/diary/media collectors. Точное решение выбрать на уровне доказанного backend API; не подменять catch в Dart обещанием безопасности.
2. До cleanup нужна гарантия завершённого consistent DB bootstrap и read of required references; при ошибке ни `audio/asset_*`, ни diary_media/история, ни WAL/journal не удалять. Опасные orphan media оставить, пока не доказана неиспользуемость; отдельный сознательный GC позже.
3. Для изменений DB/layout только минимальная совместимая миграция с копией и rollback в disposable test; **лучше обойтись без миграции**. Не перезаписывать исходные файлы по ложному hash; клиентский и мастерский sandbox не смешивать.
4. Regression: missing/corrupt DB, invalid JSON, interrupted app/transaction, WAL/rollback journal, media refs, same title different IDs, унаследованные пользовательские данные. Проверить безопасное сообщение об ошибке, никаких forced reset и ложной пустой библиотеки.
5. Унаследовать точное scoped reader alias из PR46 для того же проверенного MASTER, без межаккаунтного раскрытия дневника. Не считать его объяснением пропажи модуля/треков.
**GATE G1:** тест подтверждает, что при опасном состоянии **оригинальные байты не меняются и cleanup не выполняется**, а успешный штатный upgrade сохраняет все ссылки. Иначе BLOCKED, не переходить к сборке на реальное устройство.

## G2 — P0 авторизация, транспорт и публикация (уже есть код)
1. Сверить существующие SDK singleflight restore/refresh, 401/403/network/DNS/abort, owner role, app queue и retry из PR45; доработать именно найденные дефекты, а не переписать Google слой. Проверить, что MASTER/CLIENT оба entrypoints показывают одно состояние identity; смена аккаунта не публикует чужую очередь; network loss не означает sign-out.
2. Фактическая цепочка: MASTER module+3 audio tracks → облачный catalog (authoritative server acknowledgement / commit, revision/hash) → template/program с этими modules+pauses → diary draft → publish/update ContentLink без повторной загрузки неизменных бинарных файлов → CLIENT browse + selective installation → offline run 3tracks. Проверить UX «Добавить в каталог» отдельно от «Подготовить к публикации», категории/обложку/описание, ошибки.
3. Сеть: пауза/возобновление, частичная отправка, repeated receipt, disconnect/DNS, Wi-Fi↔mobile, 401/403, slow response, duplicate retry, no duplicate blobs/IDs, verify vs committed state, сохранность локального оригинала. Реальный network-switch на owner device — поздняя физическая приёмка, не имитировать её PASS.
4. Если для live требуется GAS изменение — предоставить минимальный reviewed server candidate, точные совместимые endpoints, isolated tests и rollout/rollback proposal; **НЕ DEPLOY**. Результат до согласования имеет PARTIAL/BLOCKED live с конкретной инструкцией владельцу, а остальные независимые этапы продолжать, если безопасно.
**GATE G2:** contract tests + изолированная сеть/роль + контролируемые повторные отправки PASS. Не писать «живой мастер отправил» без реального owner/Google E2E.

## G3 — P1 переименование «Шаблоны» → «Программы»
1. В user-visible MASTER/CLIENT UI, названиях кнопок, списков, подсказок и error/status strings использовать корректно «Программа / Программы / Выбрать программу / Сохранить программу» по смыслу. Модули, фазы, треки, паузы сохраняют терминологию. Подчеркнуть связь c Курсом в документации, но новых course/screens/опросов НЕ делать.
2. Internal `template` entities, db tables, IDs, JSON, API route, contract, capsule older formats **сохранить** для обратной совместимости. Не создавать параллельную `program` сущность и не дублировать модуль/audio graph.
3. Search/audit string occurrences: различать labels от storage/wire keys/test fixtures; добавить тест, что legacy template/capsule/catalog program label отображается как программа и корректно round-trip без нового ID/без rewrite.
**GATE G3:** UI labels корректны, old data/exports/imports и ContentLink не сломаны.

## G4 — сборка и доказательства
1. Финальные `flutter analyze`, targeted + full suite **один раз после стабилизации**, Node/GAS contract/security tests, immutable signed package build exact source, Android native upgrade from APK25 with **UI-created** baseline (3 tracks, 2 modules, 1 template, 2 diary drafts where accessible, history, current session). OWNER device/test accounts не заменять synthetic fixtures.
2. Проверить before/after/cold restart: SQLite integrity, IDs, exact SHA media, module graph, drafts, history, offline sound. На эмуляторе authentication diary может потребовать реального Google; честно отметить NOT_RUN/BLOCKED. Smoke UI labels MASTER и CLIENT.
3. Если gated safety/required local tests PASS, подготовить **одну** пару APK кандидатов (предпочтительный следующий versionCode26, подтвердить свободен; same signing/package) в закрытом draft GitHub release, с размерами и SHA. **Никакого объявления принятого OWNER E2E.** Если G1 safety не доказан — APK НЕ распространять, дать конкретный blocker.
4. Отдельный `OWNER_PHONE_QA_16G.md` с 8–12 короткими действиями: контрольные объекты создаёт владелец в текущей MASTER25 на своё усмотрение; фиксирует до, устанавливает candidate поверх25 без uninstall/clear, проверяет всё, затем Auth→Catalog→Diary→CLIENT offline→network switch. Ни доступа Codex к личному телефону, ни персональных голосов в CI.
5. Отчёты `RESULT_16G.md`, `CHANGES_16G.md`, `TESTS_16G.md`, `ISSUES_16G.md`, `ACCEPTANCE_16G.csv`, `OWNER_PHONE_QA_16G.md`, `CODEX_EFFICIENCY_16G.md` (CI runs/retries/reason; нет токенов или owner quota) в старую папку №16. Без дублирования десятков почти равных evidence файлов.
