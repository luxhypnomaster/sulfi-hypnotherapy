# №24 — фактические проверки

Кодовый source **`d04170271e9e9f3d9d10d28fdb4a49cf0494a1e0`**, basePR55 **`85fa5321c043ef97b43cb30a88a0909e7edf66f2`**. Последующие коммиты только отчётность/доказательства. Codex Cloud Linux, Flutter3.47.9/Dart3.13.7, реальный Flutter Navigator/widgets и SQLite FFI на синтетических файлах. **Не Android, не настоящие Google-аккаунты, не production GAS.**

| Проверка | Фактический результат | Доказательство |
|---|---|---|
| ZIP6057B,7файлов,CRC и manifest6SHA+размеров | PASS, outerSHA `27f0ded55bf2aa000c254e46cf84810f9b575df2d161ed13f50385b832f87b75` наблюдён; отдельного внешнего pin владелец не давал | ARCHIVE_24.json; docs/task24 |
| Git/ancestry PR51/52/54/55 и source23 | PASS, draft/unmerged; сохранены результаты21–23 | DEPENDENCIES_24.md; GITHUB_BASELINE_24.json |
| `flutter pub get --offline` | PASS, pubspec/lock не менялись | logs/pub-get.log |
| Baseline K025/026/027/029/030/037 до product-правок | **7 PASS**, уже реализовано | logs/compatibility-before.log |
| Исходные navigation regressions | RED queue MASTER/CLIENT11routes, journal loop/root fallback, отсутствие post controls | logs/navigation-red.log |
| Фильтр журнала на прежнем committed prototypebadf314 | RED: ожидался post10, фактически post2 | logs/filter-red.log; отдельный detached synthetic worktree |
| Повторное открытие реальной неизменённой Home slide на прежнем prototype | RED: ожидалось2routes, фактически11 | logs/reader-dedup-red.log |
| Адресная итоговая навигация+совместимость | **17 PASS** | logs/targeted-final.log |
| `flutter analyze --no-pub` | **PASS, No issues found** | logs/analyze-final.log |
| `dart format --output=none --set-exit-if-changed ...` | PASS,0изменений | logs/format-final.log |
| Окончательный `flutter test --no-pub --reporter expanded` | **571 PASS / 2 SKIP / 0 FAIL**, ~7m28s | logs/flutter-full.log |
| Source/diff boundary | PASS,73предыдущих исходных файла byte-identical, только4незатронутых ими UI-пути | SOURCE_GATE_24.json; PROTECTED_24.json |
| Визуальные9:16 | 23реальных renders720×1280,6попиксельно одинаковых before/after для уже работающих экранов | SCREENSHOTS_24.json; SCREENS_24.md; EVIDENCE_24.zip |
| Новые Actions/Gradle/native/APK/AAB/emulator/телефоны | **NOT_RUN / DEFERRED_BY_OWNER** | GITHUB_DELIVERY_24.json; OWNER_QA_24.md |

SKIP — прежние opt-in TCP benchmark №18 и live-cloud №16 без live-конфигурации. Их не объявляли PASS, Google/production credentials не загружали и не повторяли большой live E2E. Локальные JS/HTTP контрактные fixtures в существующем Flutter-suite не являются live-сервером.

## Что проверено дополнительно к старым тестам

- Обе редакции:10callback badge до/после кадра, одна очередь, один Back, сохранённая USER_PAUSED row без изменения. Старый focused route из редактора/каталога распознаётся; повторное открытие после закрытия возможно. Несохранённый TextField в модальном потоке поверх очереди не исчезает от badge.
- Home-reader→journal не оставляет reader в Back-stack. Десять sibling transitions удерживают2routes и исходный journal filter. Отбор post-1 даёт последовательность1/10/11 через реальный ряд журнала. Самостоятельные страницы меняют страницу, сохраняя entryID и route.
- Root reader Back имеет fallback, root Home использует настоящий HomeScreen; preview/review не участвует в readonly dedup. Десять тапов исходной защищённой Home slide не создают10viewer; выбран именно её post3.
- Rapid taps coalesce. Чужая, expired и unpublished запись не выбирается. Краевые prev/next disabled, read state не отмечается от перехода.
- K025 с одинаковыми именами, двумя occurrences и личным fork: точныеIDs, стиль только A, revert, отсутствие изменения библиотечных source rows. Прежние controller/engine/DB не переписывались.
- K029 actualHome без RunScreen/repeat и без изменения истории. K030 общий щит/CLIENT без server grants. K037 настоящая локальная форма сохраняет local-device черновик без chooser. K026/027 — реальные paused player/timer/nested groups.

## Прозрачность повторов

Первый RED-файл дал6fail. Пять относятся к воспроизведённым отсутствующим/неверным маршрутам, шестой содержал неверное предположение теста о видимости заголовка на второй странице; исправлен на проверку `DiaryReader.entry.id`, сама прежняя пагинация не переписывалась. Отдельные неверные finders уточнялись до настоящих assertions (GestureDetector у Home, prefix у journal rows). Первоначальный RED не используется как доказательство шести разных product-багов.

Переход на журнал выявил реальное синхронное уведомление during-build; исправлено в reader, не в защищённом controller. После новых фильтра/дедупликации и style lint провели адресные проверки и **один окончательный полный прогон**. Два подготовительных прогона прерваны до заморозки: новый проверяемый filter gap и короткий преждевременный старт перед чистым анализатором. Причины/PID/логи сохранены, эти прогоны не считаются успешными. Нет бесцельных инфраструктурных повторов, native/CI затрат и выдуманных процентов квоты.
