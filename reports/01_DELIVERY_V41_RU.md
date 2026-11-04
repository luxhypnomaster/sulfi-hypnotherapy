# Отчёт ночной разработки «Сульфи» v4.1

## A. Репозиторий и среда

Исходное состояние cc2492b, feature/v4-modules-recorder-background. Рабочая ветка feature/v41-final-player: создана от develop 505a7f2, затем fast-forward до реализованной V4. main dcec7ed и develop не меняются. PR будет в develop; он включает ранее ещё не слитую V4 из PR №2. Версия 0.4.1+6, applicationId прежний ru.sulfi.sulfi_hypnotherapy.

Linux x64, Flutter 3.47.9 stable / Dart 3.13.7, JDK 21, Android SDK 35/36, build-tools 36, NDK 28.2; minSdk 24. Физического Android/эмулятора нет. Исходный архив получен по предоставленной ссылке Google Drive; оригинал и sharing не изменялись. Все BASELINE_V4 MD побайтно совпадают с ранее прочитанным V4. Утверждённый PNG проверен по SHA-256 3689f5fbed5e1f9a97fd8e85bcf5f7a4735d9268ec673c6a4ed1dad06e7478bc.

## B. Исходный и итоговый аудит

Исходная таблица: [00_AUDIT.md](00_AUDIT.md).

| Подсистема | До → после | Доказательства |
|---|---|---|
| Модели/миграции | DONE → DONE | Не пересоздавались. Старые SQLite v1/v2/v3 fixtures, media bytes, full snapshots и disabled regression tests |
| Конструктор/каталог | DONE/PARTIAL → сохранено | Независимые Phase/Module/Track instances, импорты и zero pre-delay. UI рекомендаций остаётся необязательным недоделанным участком |
| Библиотека/импорт | DONE → сохранено | Managed MP3/M4A/WAV, теги, ссылки на аудио; обновлён отображаемый номер версии |
| Диктофон | DONE → сохранено | Native record/AAC, temp/preview/save, permission/error-stop; реальный микрофон NOT TESTED |
| Фон/MediaSession | PARTIAL → расширено | Service-backed engine плюс системный seek. Native lock-screen/focus/headset NOT TESTED |
| Главная/история/контакты | DONE/PARTIAL → сохранено/расширено | Full-plan history и Telegram/email; журнал новых переходов и последнего прохождения элемента |
| Новый плеер | MISSING → реализован | RunScreen, PlayerArt, SessionTimeline, engine tests, widget tests, Flutter PNG |
| Дневник | BLOCKED/DEFERRED → не внедрён | В исходном коде дневника нет. UI/облако/миграции дневника не создавались |

## C. Реализованные изменения

- `models/session_timeline.dart`: нормализованный исполняемый timeline с ID каждого применения, соседние track/module/phase targets, dynamic forecast. Не парсит подписи, не группирует по AudioAsset ID, не смешивает повторы каталожного модуля.
- `services/session_engine.dart`: шесть реальных переходов, bounded seek, загрузка выбранного MP3 в паузе без play, защита двойных переходов и exit, passed/remaining/total/percent/liquid от одного расчёта. Завершённые и пропущенные occurrence IDs сохраняются. Возврат снимает отметки текущего повторного прохождения, исходные события остаются в журнале.
- `models/session_plan.dart`, `data/session_repository.dart`: additive JSON `completedStepIds`, старый формат читается с пустым значением. Списки completed/skipped read-only; checkpoints не переписывают frozenPlan/исходные метаданные/заметки. SQLite схема остаётся v3, files/IDs/пути не перемещаются.
- `services/session_transport.dart`, `session_audio_handler.dart`: seek к настоящему player и доступность системного seek только при текущем seekable audio; единый engine для экрана и MediaSession.
- `ui/run_screen.dart`: утверждённые колба/часы, фуксия «Время трансформации», дата/номер/тема из run, глобальные счётчики, один Play/Pause, seek и правильные интервальные состояния; закреплённые 3 пары переходов и один финальный action. На шкале все фазы/названия модулей, все треки только текущей фазы, авто-scroll и статусы с текстом/иконками. Нет Professional tap.
- `ui/player_art.dart`, `assets/player/approved.png`: золотые орнаменты и eye берутся через source rectangles/clipping из единственного утверждённого PNG; демонстрационные UI-надписи/нарисованные кнопки не используются. Жидкость и фон циферблата нарисованы динамически; поверх настоящие Flutter controls. Новые графические концепции не генерировались. При малом экране орнамент часов сокращается ради доступных контролов.
- `ui/history_screen.dart`: понятные названия seek/navigation/skip и оценка последнего запуска элемента, а не любого прежнего completion.
- Сохранены FreeWork «+5 минут» / «Завершить работу» через сведения ⓘ. Это контекстные команды из V4, не дополнительные постоянные кнопки основного экрана. Технические сведения о тестовой среде вынесены из пользовательского плеера в отчёт.
- Завершение: confirmation предлагает только доступный exit, interruption и cancel. Перед изменением основного дерева закрывается диалог целиком; это устраняет найденную в тесте ошибку Flutter semantics geometry при collapse/exit. Штатное завершение, досрочный выход и прерывание остаются разными статусами.

### Политика переходов и времени

Next/previous track выбирает ближайшее аудиоприменение по исполненному порядку. Промежуточные интервалы явно попадают в skipped IDs/журнал; подсказка кнопки сообщает об интервалах. Module target — первое исполняемое содержимое соседнего непустого экземпляра. Свободный элемент не получает искусственный module ID. Phase target — первая позиция соседней активной непустой фазы. Целевой pre-delay исполняется; нулевой delay сразу переводит в содержимое, включая предзагрузку на паузе. Explicit exit сохраняет V4-политику немедленного выхода без первой задержки.

Прошло — активное время engine без пользовательской паузы; осталось — текущая часть + последующие delay/content в выбранном маршруте; всего = прошло + осталось. Seek не приписывает пропущенное к фактически прошедшему времени. Возврат создаёт повторное прохождение в том же run и может увеличить раствор. Продление относится к текущему прохождению, frozenPlan неизменён. Неопределённая работа даёт ≈; zero-duration завершение даёт 100% без NaN. При stopped/error UI не объявляет успешное завершение.

## D. Реальные проверки

Точные логи в `/workspace/scratch/v41-{pub,analyze,tests,render-last}.log`; итоговые CI и APK прикрепляются в PR и сообщении владельцу после сборки.

| Проверка | Результат / границы |
|---|---|
| Исходные pub get / analyze / tests | PASS; 100 baseline тестов |
| pub get --enforce-lockfile | PASS |
| dart format --output=none --set-exit-if-changed lib test | PASS, 48 файлов без изменений после format |
| flutter analyze --fatal-infos | PASS: No issues found |
| flutter test --reporter expanded | PASS: 119 тестов; 100 прежних и 19 новых случаев, включая условный render gate |
| Отдельный Flutter render | Реальные PNG, не фотография референса |
| flutter build apk --debug | Выполняется GitHub Actions; ссылка/результат в PR после завершения |
| Миграция / сохранность | Автотесты SQL fixtures + byte comparisons; БД телефона недоступна |
| Физический Android | NOT TESTED: микрофон, реальный decoder/player, lock screen, уведомления, звонки, headset/Bluetooth, battery restrictions, установка обновления |

Capture/transport в тестах внедряются: это проверка состояний, сохранения, файлового lifecycle и связи контролов с движком, не слышимого нативного звука. Baseline F01–F15 не удалены: [V4 матрица](../docs/v41/BASELINE_V4/05_ACCEPTANCE_TESTS_RU.md), [предыдущие результаты](../docs/VERIFICATION_V4.md).

### P01–P35

| ID | Результат | Доказательство / ограничение |
|---|---|---|
| P01 | PASS | Flutter render + PlayerArt/RunScreen; только утверждённые исходные орнаменты, динамические controls. |
| P02 | PASS | Widget: фуксиевый текст, тема из модели; нейтральный fallback в RunScreen. |
| P03 | PASS | RunScreen использует run.startedAt и оригинальный offset, baseline local_dates tests; даты рендера тестовые реальные модели. |
| P04 | PASS | Engine test inverse liquid: initial 1, complete 0; реальные рендеры. |
| P05 | PASS | Engine test .25/.75 → .75/.25, PNG player-25/player-75. |
| P06 | PASS | Engine pause/seek tests: время/forecast не растут в паузе; жидкость — тот же forecast. |
| P07 | PASS | Engine backward navigation test: реальный остаток растёт, actual elapsed не меняется. |
| P08 | PASS | Forecast test включает pre-delay, audio, silence, work; единый источник для всех показателей. |
| P09 | PASS | RunScreen scale начинается сразу после header; подтверждается Flutter PNG. |
| P10 | PASS | Widget test active phases/module names; SingleChildScrollView с полным деревом заголовков. |
| P11 | PASS | Widget current phase only, 2 модуля раскрываются одновременно. |
| P12 | PASS | Widget phase transition, прежние tracks исчезают, новые появляются без дублей. |
| P13 | PASS | Widget 24+2 tracks: только шкала скроллится, фиксированные контекст/навигация/stop. |
| P14 | PASS | Widget auto-scroll к активному Exit и неизменные позиции остальных контролов. |
| P15 | PASS | Row Semantics содержит текст статуса; иконки и цвет; completed IDs не выводятся из индекса. |
| P16 | PASS | Widget tap по module row не меняет index; скрытых Professional callbacks нет. |
| P17 | PASS | Widget slider gesture + actual test transport, native backend wired; реальный звук отдельно NOT TESTED. |
| P18 | PASS | Widget один watch-play-pause, один finish; интервалы отображают правильный тип, без второго player. |
| P19 | PASS | Engine clamps seek, paused остаётся paused; non-audio canSeek false. |
| P20 | PASS | Widget 6 keys / 3 пары в правильном порядке, touch height 48. |
| P21 | PASS | Engine navigation между module/phase границами с повтором одного файла и direct interval. |
| P22 | PASS | Engine repeated ModuleDefinition → разные instances; targets по instance IDs, disabled/empty исключаются. |
| P23 | PASS | Engine phase navigation skips disabled, edge targets null; disabled widget button. |
| P24 | PASS | Future.wait double navigation + paused load/seek: plays не растут, один run. |
| P25 | PASS | Реальный SQLite events/frozen fingerprint/run ID tests; navigation/skip/source/destination в журнале. |
| P26 | PASS | Engine seek/extend/back/first delay forecast tests; UI 3 counters из одного объекта. |
| P27 | PASS | Unknown FreeWork → null forecast/≈; zero-duration → valid 100%, нет деления на ноль. |
| P28 | PASS | Widget один лаймовый finish, завершённый экран без live Play. |
| P29 | PASS | Widget Exit/cancel/stop и no-Exit вариант, engine проверяет доступность файла. |
| P30 | PASS | Engine + widget: completed / completedEarlyWithExit / interrupted, разные events. |
| P31 | NOT TESTED | Service-backed архитектура сохранена; блокировка/фон на физическом Android недоступны. |
| P32 | NOT TESTED | Linux widget 320×600/1.6 и 800×360 PASS; Android system bars/notch/TalkBack/gesture regions ещё не проверены. |
| P33 | PASS | Production UI из SessionRun/frozenPlan, нет импортированных demo templates/track names. PNG используется только для орнамента. |
| P34 | NOT TESTED | Порядок/время проверены injected transport; настоящие MP3 + lock screen/intervals на телефоне не проверены. |
| P35 | PASS | Completed IDs сохраняются в SQLite и сбрасываются для replay; прошлые actual events остаются, snapshot полный. |


## E. Артефакты, сохранность и следующие задачи

Рендеры в `docs/screenshots/v41/`: player-zero, player-paused, player-25, player-75, player-completed, player-interrupted. Это Flutter/Skia Linux 412×915, синтетические данные и тестовый font, не фото телефона. Исходный утверждённый PNG — не результат рендера.

Новый APK/commit/CI и его скачивание публикуются в PR после фактической сборки. Доступна предыдущая V4 сборка, но её нельзя выдавать за v4.1. Локальный диск ограничен (~1.1 GB свободно после тестов); прежняя локальная native build уже упиралась в Gradle downloads/transforms. Финальный native build выполняется на GitHub runner.

Личные записи, аудио, шаблоны и история не копировались из телефона и не удалялись. Обновление реальной установки и совместимость подписи NOT TESTED. Постоянный ключ подписи отсутствует: нельзя удалять старую установку ради обхода конфликта debug-подписи без отдельной резервной копии. Git/APK не являются копией личных записей.

Остаётся физическая приёмка по Android plan, сравнение оформления владельцем, необязательный UI рекомендаций модулей, постоянная подпись и резервирование. Дневник и его облако намеренно отложены. Текущий экран адаптирует орнаменты/второстепенные надписи под размер и шрифт; попиксельное совпадение иллюстрации со всеми размерами не заявляется. В narrow/landscape остаются те же команды, сокращённые подписи имеют полные tooltip/semantic labels.

На очень низком portrait при большом шрифте постоянная карточка контекста переносится в ⓘ; это позволяет сохранить 48dp кнопки и 44dp seek без прокрутки всего экрана. Корпус часов сокращается, их реальные controls остаются. В landscape те же функциональные части стоят в соседних колонках.
