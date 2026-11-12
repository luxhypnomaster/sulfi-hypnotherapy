# №16-Б — фактический Android emulator QA

APK source012f7f69b7ad99c0d44f2a442d9649aa1481117e. [Native run43165399224](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43165399224). Реальный Android35 x86_64 emulator с KVM, две настоящие подписанные APK; только синтетические локальные данные,без Google-аккаунтов.

| Сценарий | Результат |
|---|---|
| Установка/запуск исходной MASTER24 | PASS |
| Валидная синтетическая SQLite/audio fixture | PASS |
| Установка MASTER25 поверх24,без uninstall | PASS: audio/history/template/diary draft сохранены,SQLite integrity ok |
| Нативный preview из библиотеки | BLOCKED:NATIVE_PLAYBACK_NOT_OBSERVED |
| Сессия и звук при выключении экрана | BLOCKED:SESSION_PLAYBACK_NOT_OBSERVED |
| Отдельный CLIENT25 package/sandbox | PASS,своя пустая библиотека и SQLite9 |
| Гость после restart | PASS;authenticated logout NOT_RUN без Google |
| Реальный UI export капсулы→CLIENT import | PASS,точные аудиобайты и шаблон импортированы |

Итого6 PASS/2 BLOCKED. Общий workflow success означает успешные критические install/update/data/isolation gates; это НЕ означает PASS каждой звуковой проверки. Слышимость звука человеком не проверялась.

Для различения ограничения измерения/среды и регрессии запущен отдельный read-only probe43194766281: сравнение исходной APK24 и APK25 на одном эмуляторе с10 последовательными замерами,UI и app logcat. Приложения/подпись при этой диагностике не изменяются;новые runner scripts допускаются только при byte-identical app source tree относительно012f. Данные probe добавляются отдельно;до получения доказательств звук не объявляется подтверждённым.

Исходные результаты — EMULATOR_16B.json и logs/EMULATOR_EVIDENCE_16B.txt. Native screenshot screens/task16b-native-emulator.png показывает реальный экран локальной капсулы,а не физический телефон владельца. Личные файлы/Google identities не использовались. Реальный MASTER→Google/Drive→CLIENT→offline3tracks остаётся owner acceptance.

## Уточнение: corrected probe43196379265

[Сравнительный запуск](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43196379265),runner source daa8716,неизменные APK24/25. Для обеих версий подтверждены library AudioTrack,session AudioTrack и активное воспроизведение при выключенном экране. В details обоих session cases `observed:true,screenOffObserved:true`; слышимость человеком NOT_RUN.

Итого в этом probe7 PASS/1 BLOCKED. Остался `candidate25_install:APPLICATION_UI_NOT_READY_AFTER_BOOTSTRAP`: APK установилась,но после предшествующего сеанса автоматизация не поймала ожидаемую главную страницу. Этот конкретный navigation gate не объявляем PASS. Следующие candidate25 seed/library/session действительно прошли;исходный smoke отдельно уже подтвердил install/update/data preservation.

Первоначальные звуковые BLOCKED разрешены отдельными доказательствами: первый snapshot оказался раньше cold decoder start,а история тестовой фикстуры требовала согласованного app_counters.session. COUNTER_FIXTURE_16B.log воспроизводит и устраняет это только в synthetic preconditions. Плеер,APK,сервер и реальная база владельца не изменялись. Исходные6/8 и последующие результаты сохранены,а не переписаны общим зелёным статусом. Полный реальный Elman3tracks Google/Drive/двухтелефонный путь остаётся owner QA.
