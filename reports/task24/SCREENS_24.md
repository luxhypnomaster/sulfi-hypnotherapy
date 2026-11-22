# №24 — визуальные доказательства

Реальные Flutter widget renders на синтетических данных, **не Android screenshots**. Viewport360×640 logical, PNG720×1280: 9:16. Roboto/MaterialIcons загружены из установленного Flutter SDK. Изображения скопированы без редактирования; архив доказательств содержит набор before/after, SCREENSHOTS_24.json — размеры, SHA и pixel comparison. Изменений исходных графических assets/скина нет.

Ключевые изображения доступны также в Git:

- [Читатель до](https://github.com/luxhypnomaster/sulfi-hypnotherapy/blob/feat/task24-local-ux-navigation/reports/task24/screens/before/task24-reader9x16.png) / [после](https://github.com/luxhypnomaster/sulfi-hypnotherapy/blob/feat/task24-local-ux-navigation/reports/task24/screens/after/task24-reader9x16.png): прежний планшет, шапка и пагинация; отдельно добавлены одобренные кнопки публикаций. Страницы сохраняют собственные подписи/номер.
- [Только изменённый экземпляр A](https://github.com/luxhypnomaster/sulfi-hypnotherapy/blob/feat/task24-local-ux-navigation/reports/task24/screens/after/task24-only-occurrence-A.png): фуксиевый курсив и отдельное жёлтое «(Изменено)», неизменённые B и личный fork обычные. После revert метки нет.
- [Таймер/иерархия](https://github.com/luxhypnomaster/sulfi-hypnotherapy/blob/feat/task24-local-ux-navigation/reports/task24/screens/after/task24-timer-hierarchy.png): прежний ярко-жёлтый elapsed/total в сводке, фаза→модуль→трек/пауза, прямой трек остаётся прямым. Плеер не перекрашивался по K025.
- [Очередь](https://github.com/luxhypnomaster/sulfi-hypnotherapy/blob/feat/task24-local-ux-navigation/reports/task24/screens/after/task24-queue-client.png): общий экран и глобальный жёлтый badge, настоящие кнопки и сохранённая синтетическая USER_PAUSED задача. Ноль попыток здесь намеренно: тест не отправляет файлы.

В полном архиве также: Home/общий щит обоих изданий, история с Home action, офлайн-редактор, reverted module, separate pages/posts. Превью и renderer не заменяют физическую приёмку. Первый холодный MASTER queue capture с ещё не декодированным bitmap исключён, а не представлен как подтверждение оформления; shared CLIENT render декодирован, навигационные тесты отдельно проходят в обоих изданиях.

Важные before/after для уже работающих экранов сравниваются без подмены ожидаемых макетов; часы/дата могут меняться. В читателе изменяется высота текстового viewport из-за отдельного ряда переходов между публикациями, поэтому пагинация честно пересчитывается по прежнему layout engine. Ни один body-фрагмент не превращён в готовую картинку/декоративную кнопку.
