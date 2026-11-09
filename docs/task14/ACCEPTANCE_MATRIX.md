# ЗАДАНИЕ №14 — МАТРИЦА ПРОВЕРОК

По каждой строке: `PASS / FAIL / NOT RUN / BLOCKED / VERIFIED EXISTING / PARTIAL`, краткое доказательство (тест/screenshot/файл:строка/commit/log), и ограничение (если есть). **Статус из source audit №7 не равен текущему PASS**. Для статуса VERIFIED EXISTING требуется проверка в фактическом HEAD.

| ID | Проверка | Требуемое свидетельство |
|---|---|---|
| BAS-01 | Фактический Git/branch/HEAD/PR №13 установлены, никакие принятые изменения не потеряны | git log/status/diff |
| BAS-02 | Existing features A–G перечислены с реальным кодом и тестами, нет слепого дубля | BASELINE_AUDIT |
| BAS-03 | Миграции, capsule schema, сохранение истории/личных файлов и запас отката описаны до правок | baseline + runbook |
| NAV-01 | «На главную страницу» видна на истории рядом с прежними действиями | Flutter final screenshot |
| NAV-02 | Тап домой сразу открывает Home, не историю и не active RunScreen | Widget navigation test |
| NAV-03 | Стрелка назад ведёт в список истории; Repeat и Edit работают как прежде | Regression tests |
| NAV-04 | Три крупные кнопки доступны на 320x600, 360x800, 412x915 и textScale 1/1.3/1.6 | Bounds/screenshots |
| NAV-05 | Возврат домой не создаёт/удаляет записи, не запускает аудио и не дублирует стек | Repo + navigation asserts |
| DIF-01 | Изменение вложенных шагов/порядка/аудио модуля вызывает фуксию и курсив в редакторе | Unit + screenshot |
| DIF-02 | Undo до исходного состава убирает подсветку, флаг «когда-то редактировался» не используется | Unit/widget |
| DIF-03 | Сравнение привязано к исходной библиотечной ревизии; неизвестный legacy source не подменяется | Unit revision test |
| DIF-04 | Изменение активной композиции шаблона подсвечивает имя на главном/стартовом экране | Widget test |
| DIF-05 | Совпадение с библиотечным шаблоном возвращает обычный стиль; runtime не считается изменением | Unit/widget |
| DIF-06 | RunScreen сохраняет семантические цвета из принятого №13 | Color/player regression |
| EXP-01 | Выборочный экспорт одного трека с bytes+metadata+digest, без лишних аудио | Fixture+manifest |
| EXP-02 | Экспорт модуля переносит steps/порядок/паузы и все реальные аудиозависимости | Roundtrip test |
| EXP-03 | Экспорт шаблона переносит фазы/модули/прямые треки/паузы/dependency closure | Fresh DB import |
| EXP-04 | Общий blob встречается в пакете один раз, ссылки сохраняются | Manifest/hash asserts |
| EXP-05 | Ошибки отсутствующего аудио, неверного hash/size, traversal, циклических зависимостей обнаруживаются до commit | Negative fixtures |
| EXP-06 | Выборочные действия экспорта доступны пользователю и не нарушают legacy full capsule | Widget + legacy test |
| EXP-07 | Повторный импорт того же пакета идемпотентен; конфликт ID не молча перезаписывает данные | Twice-import test |
| EXP-08 | Импорт пакета после crash/error не оставляет частично видимого установленного контента | Fault injection |
| VER-01 | Различаются logical content ID, immutable revision ID, occurrence/instance ID | Unit/schema |
| VER-02 | Новая официальная ревизия не удаляет старую; exact reference старой остаётся резолвим | Persistence test |
| VER-03 | Личная копия получает новый ID+parent revision, не изменяет библиотечный оригинал | Unit+DB |
| VER-04 | Legacy без provenance остаётся unknown, без выдуманного parent | Migration fixture |
| VER-05 | SHA-256 целостность не выдается за подпись или право доступа | Contract and UI |
| VER-06 | SessionRun/history snapshot не перенастраивается на latest после установки обновления | Persistence/history test |
| CAT-01 | Offline каталог имеет карточки track/module/template до установки с точной ревизией | UI/fixture |
| CAT-02 | Resolver находит транзитивные exact-version зависимости и обнаруживает missing/cycles/conflicts | Unit fixtures |
| CAT-03 | План установщика считает только недостающие blobs и объём до записи | Dry-run test |
| CAT-04 | Shared digest переиспользуется без дублирования байтов и без смешения author rights | FS/DB assert |
| CAT-05 | Установка staged/verified/committed с SHA,size,extension/path safety | Installer integration |
| CAT-06 | Cancel/retry/перезапуск/исчерпание места дают безопасную инсталляцию/откат | Fault tests |
| CAT-07 | Вторичная установка не дублирует данные и не ломает уже работающие | Idempotency test |
| CAT-08 | Установленный материал воспроизводится существующим preview/player, installer не создаёт третий плеер | Integration |
| CAT-09 | Демо-каталог отличён от живого онлайн каталога; никаких неподтверждённых серверных функций | UI evidence |
| LNK-01 | Diary ContentLink структурирован: type, logical ID, exact revision/digest, action | Model test |
| LNK-02 | Diary link installed→открыть, available→установить, unavailable→честная ошибка | Widget tests |
| LNK-03 | Старые diary entries открываются без миграционных потерь/обязательного нового поля | DB/serialization |
| LNK-04 | Никакого fake remote publish: live Apps Script не изменён/не развернут | Diff+contract |
| DAT-01 | Legacy populated DB обновляется без потери аудио, истории, diary, attachments, settings | Migration tests |
| DAT-02 | Старые capsule fixtures импортируются; новые выборочные пакеты импортируются в свежую базу | Roundtrip |
| DAT-03 | Выход из активной сессии/обновление каталога не меняют исполняемый snapshot и звуковой транспорт | Engine tests |
| DAT-04 | Full Flutter analyze/tests/CI, актуальный SHA, APK signing compatibility, no destructive cleanup | Logs+CI |
| DEL-01 | REPORT folder содержит RESULTS/BASELINE/CHANGES/TESTS/CONTRACT/MIGRATIONS/ISSUES/real screenshots | Drive links and file listing |

**Итого: 46 проверок** (`BAS 3; NAV 5; DIF 6; EXP 8; VER 6; CAT 9; LNK 4; DAT 4; DEL 1`). Если подсчет строк отличается от текста — реальный перечень ID выше является источником истины, проверить полноту автоматически. Ни один PASS не означает физический Android-тест, если он реально не проводился.
