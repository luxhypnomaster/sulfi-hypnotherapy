# Проверка реализации V4 — 0.4.0+5

Дата: 2026-11-03. Ветка `feature/v4-modules-recorder-background` от `develop` (`505a7f2`). `main` и `develop` не изменялись. V4 заменяет предыдущие функциональные спецификации. Это кандидат для тестирования, не принятый релиз.

## Обследование и границы

Исходная версия содержала SQLite v2, приватную аудиобиблиотеку, плоский план с группами, шаблоны/черновик/историю, часы и foreground-engine, который прерывался при сворачивании. Диктофона и media service не было. Сохранённая БД телефона в рабочую среду не передана; миграция проверяется на создаваемых тестами старых SQLite-базах с реальными файлами. Пользовательские записи не копировались в репозиторий.

Пакет требований сохранён в `docs/v4/`. Скриншоты прежнего пользовательского состояния `assets/current/` исключены из Git, чтобы не публиковать темы и историю. Художественные референсы — ориентиры композиции, не готовые интерактивные экраны. Декоративные слои не содержат обработчиков; реальные кнопки/текст/списки/часы реализованы виджетами. Поставленная строгая спираль отличается от художественной в референсе; нового логотипа не генерировали.

## Основные файлы и решения

| Файлы / классы | Изменение |
|---|---|
| `models/modular_plan.dart` | `PhaseType` (10 типов), `PhaseInstance`, `ModuleDefinition`, `PhaseChild` (экземпляр модуля или свободный элемент), детерминированный адаптер legacy |
| `models/session_plan.dart` | `SessionStep.enabled`, `SessionPlan.phases`, полный `allSteps` и исполняемый `steps`, независимые `CurrentSessionDraft`/`SessionTemplate`/`SessionRun`, источник audioMetadata, offset/skipped IDs, новые статусы |
| `data/app_database.dart`, `v4_migration.dart`, `module_catalog.dart` | SQLite v3, транзакционный архив v2 и каталог определений модулей |
| `services/session_controller.dart` | Сериализованное автосохранение, операции над деревом, глубокие копии экземпляров, полный снимок старта, проверка отсутствующих активных файлов |
| `services/recorder_service.dart`, `ui/recorder_screen.dart` | Нативный `record`/AAC, конечный автомат записи, temp → preview → явное сохранение, retry без ложного успеха |
| `services/session_audio_handler.dart`, `session_engine.dart`, Android manifest/MainActivity | `audio_service`, MediaSession, владелец engine вне экрана, тишина/работа удерживают активное media-состояние, focus/headset, checkpoint, полный выход и разные статусы |
| `ui/modular_structure_screen.dart`, `modules_screen.dart`, `module_assignment.dart` | Реальный конструктор фаз/модулей/треков, порядок, повторные вставки, локальная правка и восстановление каталожной версии, импорт/запись с модулем |
| `ui/home_screen.dart`, `history_screen.dart`, `pause_editor.dart`, `templates_screen.dart` | Главная и навигация V4, компактная история с полным планом, повтор без автозапуска, часы и расчёты |
| `ui/booking.dart`, Android resources | Подтверждённый Telegram, конфигурируемая почта, launcher «Сульфи» и supplied adaptive icons |
| `test/v4_models_recording_test.dart`, `v4_ui_test.dart`, `session_engine_test.dart` | Миграция, модульные копии, запись с injected backend, ошибки/повтор save, остановка нативного захвата при ошибке паузы, early Exit (включая ведущую тишину фазы), MediaHandler, 30 треков и рендеры |

Старый `ui/structure_screen.dart` сохранён для регрессионных тестов прежнего поведения; production-переходы открывают `ModularStructureScreen`. Тип `voiceRecording` в старых планах сохраняется, но запуск отклоняется с пояснением: запись речи внутри сеанса и голосовая тема отложены V4. Библиотечные категории сохранены для совместимости и не ограничивают новые фазы.

## Миграция и целостность

- SQLite v3 добавляет `module_definitions` и `legacy_v2_documents`; аудиотаблица и пути файлов прежние. Исходные JSON черновика, шаблонов и запусков архивируются в той же транзакции перед конвертацией.
- Последовательность не сортируется по названию/категории. Разнесённые повторения старой группы становятся отдельными фазами по непрерывным участкам. Старые ID треков и паузы сохраняются; ID новых фаз детерминированы. Результат повторной миграции одинаков.
- `allSteps` хранит выключенное и неисполненное; `steps` исполняет только включённое. Защита удаления файлов учитывает выключенные элементы и каталог. Архивация модуля не удаляет его копии и media.
- Каталог, экземпляр, шаблон и история не разделяют изменяемые списки. Полный снимок содержит исходные метаданные аудио, пользовательские названия, структуру и тему. Пропуски выхода фиксируются отдельно.
- Новый запуск хранит UTC и исходный offset; для старых timezone неизвестен. Строго распознаваемая старая дата из имени сохраняется как местная без выдуманного offset.
- Нет чтения/сброса базы телефона. Тест миграции сравнивает старые JSON, ID, порядок и байты локальных тестовых файлов, повторно открывает базу. Реальная установка обновления NOT TESTED; см. `UPGRADING.md`.

## Автоматические проверки

Среда: Linux x64, Flutter 3.47.9 stable / Dart 3.13.7, JDK 21, Android SDK 35/36. Подключённого Android/emulator нет (`flutter devices`: только Linux). Локальные логи находятся вне Git в `/workspace/scratch/v4-*.log`.

| Проверка | Результат |
|---|---|
| `flutter pub get --enforce-lockfile` | PASS |
| `dart format --output=none --set-exit-if-changed lib test` | PASS |
| `flutter analyze --fatal-infos` | PASS, No issues found |
| `flutter test --reporter expanded` | PASS, 99 тестовых случаев (включая условные тесты рендеров) |
| Отдельный запуск V4 рендеров с dart-define | PASS, 4 PNG |
| Локальный `flutter build apk --debug` | FAIL, загрузка Gradle plugin, см. ниже |
| APK через GitHub Actions | Итог и ссылка на артефакт фиксируются в PR и сообщении владельцу после CI |
| Физическое устройство | NOT TESTED |

Тесты диктофона используют внедрённый `CaptureBackend` и decoder, записывают настоящие тестовые файлы, но не подтверждают нативный микрофон/кодек и слышимость. Engine-тесты используют управляемое время и транспорт; handler-тест доказывает связь системных команд с engine, а не работу Android OS. Не считать количество тестов количеством принятых пунктов V4.

Локальная `flutter build apk --debug` была запущена: FAIL при загрузке `org.gradle.kotlin.kotlin-dsl:6.4.2` из Gradle Plugin Repository, до компиляции приложения. Итоговый Android build проверяется также в GitHub Actions.

## Матрица приёмки

PASS означает проверку указанным методом в Linux-среде; не распространяется на нативный звук/Android. NOT TESTED у полного сценария может иметь успешно проверенную программную часть. Физические проверки перечислены в `ANDROID_TEST_PLAN.md`. После проверки телефона таблицу нужно обновить по результатам.

| ID V4 | Результат | Метод / ограничение |
|---|---|---|
| A01 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| A02 | NOT TESTED | Формула и отдельные счётчики реализованы; точный UI-сценарий 2+2 отдельно не выполнен. |
| A03 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| A04 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| A05 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| A06 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| A07 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| A08 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| A09 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| A10 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| A11 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| A12 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| B01 | NOT TESTED | Файловые тесты PASS; реальный Android picker/MP3 decoder не запускался. |
| B02 | NOT TESTED | Проверки импорта/ошибок с injected decoder PASS; нативные M4A/WAV и слышимое воспроизведение не проверены. |
| B03 | NOT TESTED | Три варианта реализованы в форме; полный UI-сценарий с Android picker не выполнен. |
| B04 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| B05 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| B06 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| B07 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| B08 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| B09 | PASS | library_service_test / session_storage_test: приватные файлы и ссылки, injected decoder |
| B10 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| C01 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| C02 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| C03 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| C04 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| C05 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| C06 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| C07 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| C08 | NOT TESTED | Поставленная спираль используется; художественное соответствие требует оценки владельца. |
| C09 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| C10 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| C11 | NOT TESTED | Manifest/adaptive resources реализованы; маски реального launcher не проверены. |
| C12 | NOT TESTED | Widget-проверки узкого экрана и увеличенного текста PASS; Android system bars/TalkBack не проверены. |
| D01 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| D02 | PASS | workspace_screen_test / session_storage_test: часы, паузы, соседние аудио |
| D03 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| D04 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| D05 | PASS | workspace_screen_test / session_storage_test: часы, паузы, соседние аудио |
| D06 | PASS | workspace_screen_test / session_storage_test: часы, паузы, соседние аудио |
| D07 | PASS | workspace_screen_test / session_storage_test: часы, паузы, соседние аудио |
| D08 | PASS | workspace_screen_test / session_storage_test: часы, паузы, соседние аудио |
| E01 | PASS | UI + recorder-service tests с injected capture/decoder, без проверки слышимого звука |
| E02 | NOT TESTED | Спираль и перо использованы в оформлении; соответствие утверждённому художественному референсу отдельно не принято. |
| E03 | NOT TESTED | Native record backend подключён; реальная запись центральной кнопкой на телефоне не проверена. |
| E04 | PASS | UI + recorder-service tests с injected capture/decoder, без проверки слышимого звука |
| E05 | NOT TESTED | Отказ/повтор permission в сервисных тестах PASS; настоящий системный диалог не проверен. |
| E06 | NOT TESTED | Таймер/состояния pause/resume в injected-тесте PASS; нативные 10+10pause+10 секунд и слышимые 20 секунд не проверены. |
| E07 | PASS | UI + recorder-service tests с injected capture/decoder, без проверки слышимого звука |
| E08 | NOT TESTED | Preview и seek подключены к настоящему player; слышимый звук не проверен. |
| E09 | PASS | UI + recorder-service tests с injected capture/decoder, без проверки слышимого звука |
| E10 | PASS | UI + recorder-service tests с injected capture/decoder, без проверки слышимого звука |
| E11 | PASS | UI + recorder-service tests с injected capture/decoder, без проверки слышимого звука |
| E12 | PASS | UI + recorder-service tests с injected capture/decoder, без проверки слышимого звука |
| E13 | PASS | UI + recorder-service tests с injected capture/decoder, без проверки слышимого звука |
| E14 | NOT TESTED | Busy/failed-save/retry/lifecycle в тестах PASS; нативная нехватка места/codec/focus не проверены. |
| F01 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| F02 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| F03 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| F04 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| F05 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| F06 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| F07 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| F08 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| F09 | PASS | session_engine_test: часы/транспорт внедрены, реальные SQLite checkpoint/events |
| F10 | NOT TESTED | MediaSession/foreground service реализованы; физического Android нет. |
| F11 | NOT TESTED | Handler управляет 120-секундной тишиной в тесте; screen-off/service/wake lock на телефоне не проверены. |
| F12 | NOT TESTED | Engine отделён от экранов; native background execution не проверено. |
| F13 | NOT TESTED | Focus/noisy listeners реализованы; звонок, Bluetooth и реальный динамик не проверены. |
| F14 | NOT TESTED | Восстановление checkpoint после повторного открытия БД PASS; настоящий force-stop процесса не проверен. |
| F15 | NOT TESTED | Нет подключённого физического Android. |
| G01 | PASS | library_service_test / session_storage_test: приватные файлы и ссылки, injected decoder |
| G02 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| G03 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| G04 | NOT TESTED | Компактный Flutter-рендер сохранён; все варианты дат/тем на физическом экране отдельно не приняты. |
| G05 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| G06 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| G07 | PASS | local_dates unit tests; неизвестный legacy timezone явно отмечен |
| G08 | NOT TESTED | Подтверждён URL владельца, externalApplication подключён; внешнее открытие на телефоне не проверено. |
| G09 | NOT TESTED | mailto/copy fallback реализованы; email отсутствует, приложение почты не проверено. |
| G10 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| G11 | PASS | UI-код и Flutter widget-тесты; физический Android отдельно |
| G12 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |
| G13 | PASS | v4_models_recording_test: независимые копии, сериализация, SQL round trip |

## Артефакты и оставшиеся ограничения

- Flutter-рендеры после изменений: `docs/screenshots/v4/{main,structure,recorder,history}.png` (412×915, тестовые данные; не фото Android).
- Требуют физической проверки нативный диктофон, permission/codec/storage failures, звуковой preview, screen off/foreground service/уведомления, 2+ минуты тишины и 5–15 минут работы, звонки, Bluetooth, battery policy, TalkBack, launcher masks и установка поверх старой версии.
- Telegram владельца `https://t.me/LuchikLuxxx` подтверждён. Email не предоставлен; отсутствие обработано, выдуманных контактов нет.
- Stable signing key и шифрованный экспорт данных ещё не настроены. Удаление старой установки ради нового debug APK недопустимо без отдельной резервной копии: данные могут быть потеряны. ApplicationId не изменён.
- Модели поддерживают tags/recommendedPhaseIds каталожных модулей, но отдельного UI редактирования рекомендаций пока нет. Любой модуль доступен любой фазе.
- Авторские MP3, дефолтные терапевтические шаблоны, запись речи внутри сеанса, облако и платежи не добавлялись.
