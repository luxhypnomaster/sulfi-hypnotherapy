# Задание №17 — native-проверка пройдена, пара APK27 готова к приёмке

Исходник приложений: `fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568`, версия **0.4.19+27**. Ветка `fix/task17-stable-auth-queue`, draft PR48; PR47 и PR48 не объединены в main. Последующие изменения касаются диагностики, тестового стенда и отчётов: исходники `lib`, `android`, `third_party`, `test`, `server`, `pubspec.yaml` и `pubspec.lock` сохранены относительно проверенного приложения.

## Что завершено

**MASTER26→27: 13 native PASS**, один сценарий со старым Google-черновиком — NOT_RUN. Полный запуск [43614090740](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43614090740) завершился SUCCESS; driver `45aca0ce0a0eda8e7a554a6308ac5df002e94557`, API34, Android Emulator37.2.12 build16428233.

В установленном APK26 через настоящий Android UI созданы три WAV, два модуля (включая положительную паузу), программа, текущая конфигурация и история. Затем выполнено обычное `adb install -r` APK27. Проверены точные строки и ID SQLite, SHA256 медиа, integrity_check, видимость материалов, состояние native AudioTrack и холодный перезапуск. Новый локальный MASTER-черновик создан через UI после обновления; его точный текст и сохранение после перезапуска также проверены. SQL использовался только для чтения. Uninstall, clear, downgrade, внедрения базы и тестовых Google-личностей не было. Телефон владельца не затронут.

Сохранены независимые доказательства MASTER25→27: run43583577375/job132413251139, 13 PASS; CLIENT25→27: run43548636228/job132310281448, 12 PASS. Все три проверки используют те же байты APK27. Сохранность старых Google-черновиков требует настоящего аккаунта и не объявляется пройденной. Native AudioTrack не заменяет человеческую проверку слышимости.

## Почему прекращал работать эмулятор

В run43610436406 монитор зафиксировал завершение настоящего QEMU PID3080 сигналом **SIGSEGV (-11)** до установки APK27 и до cleanup. Сигналов остановки обёртке не поступало; счётчики cgroup oom/oom_kill оставались нулевыми. Это подтверждённый host crash на Emulator37.2.13, а не выявленный дефект миграции APK27. Точная аварийная функция и первопричина внутри QEMU без stack trace неизвестны.

Проверенный обход: закреплена предыдущая официальная Stable37.2.12, архив проверяется до запуска по опубликованному SHA256 `b08fc43d8608d2955f607f1b287beb525041e730086bdca3af152accac3af9c1`. Это замена тестового SDK на одноразовом CI runner, не откат приложения. Версия проверяется headless-командой; без ready-маркера native-тест не стартует. Дополнительно исправлены подтверждённые ошибки тестового драйвера: поиск дневника больше не принимается за редактор, а transient-пустое accessibility-дерево обрабатывается ограниченным ожиданием **точного** значения. Критерии не ослаблены. Не утверждается, что upstream QEMU исправлен полностью.

## Проверенные APK

[MASTER27](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-c7073f0a5871b5fb707c/master27.apk) · [CLIENT27](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-c7073f0a5871b5fb707c/client27.apk) · [Закрытая страница пары](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/tag/untagged-c7073f0a5871b5fb707c).

Delivery CI [43615276560](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43615276560) — SUCCESS. Он проверил три конкретных native-доказательства и тождество исходников, затем выдал прежние проверенные байты без rebuild и повторной подписи. После загрузки оба файла независимо скачаны обратно через GitHub API: **387644474 байта**. Выполнены реальные `apksigner`, `aapt`, SHA256, проверка встроенных endpoint/Web Client ID и DEX storage guard. Полные хеши, размеры, сертификат и asset IDs — `APK_PAIR_17.json`.

Прежний сертификат SHA256: `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`. MASTER package `ru.sulfi.sulfi_hypnotherapy`; CLIENT package `ru.sulfi.sulfi_hypnotherapy.clienttest`. GitHub draft остаётся закрытым; публичного релиза нет. Нужен вход владельца GitHub в браузере. Скачивание через API проверено, скачивание браузером телефона — NOT_RUN. APK на Google Диск не загружались.

## Что остаётся

Задание №17 **не закрыто**. Реальные MASTER/CLIENT Google-входы, 15/30/60 минут, два телефона, публикация трёх авторских треков и программы, ContentLink, выборочная установка CLIENT и слышимое офлайн-воспроизведение — **OWNER NOT_RUN**. Полная матрица сохраняет 67 исходных критериев и отдельные CODE/CONTROLLED/LIVE/OWNER.

Production GAS6, OAuth, ACL, signing, старый дневник и пользовательские данные не менялись. Main сохранён на `b88637a105b2182c7b836311ebb3de7ad037b08f`: только ранее отдельно разрешённые три файла inspect. Серверный Diary-патч не применён; короткий текст без blocks по-прежнему отклоняется GAS6. Production apply и rollback не разрешены.

Следующий безопасный шаг: владелец скачивает MASTER27 и выполняет обычное обновление поверх MASTER26, затем проверяет прежние материалы **до Google-входа**. При конфликте установки или неожиданно пустом списке — STOP без удаления/очистки. Затем CLIENT27 на втором телефоне и протокол `PHONE_QA_17.md`. CLIENT можно передать через Quick Share без раскрытия репозитория и токенов.

Отчёты: https://drive.google.com/drive/folders/1fXpE8oU3HSE1g89jQppUxFPBgJLh7LqI .
