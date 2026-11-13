# №16-Г — результат и кандидаты 0.4.18+26

**Автономная часть завершена. Подписанные MASTER и CLIENT размещены в закрытом GitHub draft, независимо скачаны и проверены. Настоящие Google-входы и физическая приёмка двух телефонов ещё НЕ выполнены. Задание №16/16-А не закрывается по одним автоматическим тестам.**

Матрица содержит все 33 критерия: **22 PASS, 11 PARTIAL, 0 BLOCKED**. Доставка семи отчётов подтверждена обратным скачиванием, сравнением байтов/SHA и проверкой папки. Точные статусы — ACCEPTANCE_16G.csv, подтверждения доставки — DRIVE_READBACK_16G.json.

## Реализовано

- **Защита данных.** Поставлен узкий native callback sqflite_android 2.4.5 без silent reset/delete. До открытия исходной базы проверяется отдельная копия SQLite вместе с WAL/journal. Опасное или неполное состояние показывает безопасную ошибку. Автоматическая очистка неопределённых аудио, дневниковых и исторических файлов при запуске отключена. Схема SQLite 9, постоянные пути и IDs сохранены; разрушительной миграции нет.
- **Авторизация и каталог.** Сохранены исправления PR45 и доступ к legacy scope только того же проверенного MASTER из PR46. Существующие Google identity, очередь и повторы не переписаны. Расширена проверка цепочки: модуль с тремя треками → программа → публикация/обновление дневника с точным ContentLink → выборочная установка CLIENT. Неизменные медиа не загружаются повторно при текстовом обновлении.
- **«Программы».** В 18 файлах пользовательские «Шаблоны» заменены на «Программы». Внутренние template IDs, таблицы, API, формат капсул и старые названия, введённые пользователем, сохранены. Курсы, анкета и новый дизайн не добавлялись.

## Фактические проверки

| Проверка | Результат |
|---|---|
| Полная регрессия, verify job 43350711471 | 448 Flutter PASS, 0 FAIL, 1 opt-in live SKIP; 3 CLIENT PASS; 46 Alchemist и 24 legacy Node PASS. Analyze, форматирование и контракты PASS. Общий run позднее упал на установке SDK; verify job успешен. |
| Android native callback, 43347643988 | Healthy open, corrupt RW/RO, неизменность исходных байтов и sidecars: PASS, 148 секунд. |
| Android 35, 43403971950 | 13 PASS, 1 Google-diary NOT_RUN. Реальное обновление MASTER25→26, IDs, граф, медиа SHA, integrity, cold restart, UI и свежая CLIENT26: PASS. |
| Ошибки запуска настоящей APK26 | 3 PASS: повреждённый заголовок DB, отсутствующая DB с marker, отсутствующая DB с legacy media без marker. Без пустого reset и удаления исходников. |
| Выдача, 43406075443 | SUCCESS. Перенос уже проверенных APK из кэша в существующий private draft; без новой сборки, эмулятора и подписи. |
| Независимое скачивание | Обе APK полностью скачаны; размер, SHA, сертификат, package, версия 26, встроенные GAS6 endpoint/Web Client ID и native guard: PASS. |

В неизменённой APK25 через UI и системный выбор файлов созданы три трека с разными байтами, в том числе два с одинаковым названием; два модуля; пауза 5 секунд; программа с тремя треками; текущая композиция и одна история со статусом interrupted. Пауза настроена настоящим вертикальным жестом по маховику и подтверждена в SQLite. SQL seed и тестовая Google-личность не использовались.

После `adb install -r` APK26 и холодного перезапуска сохранены точные строки, IDs, состав и SHA медиа; integrity OK, schema 9. Треки и модули видны в интерфейсе. Наблюдался AudioTrack started для UID приложения; слышимость человеком этим не подтверждается. Авторизованных дневниковых черновиков в native наборе нет — это NOT_RUN, а не два якобы проверенных черновика. CLIENT26 проверена как свежая установка; обновление CLIENT25→26 ещё не испытано.

Native step 43403971950 успешен, но общий workflow упал позже: GitHub integration вернул 403 при создании draft. Через имеющуюся авторизацию создан один private draft; отдельный delivery run 43406075443 успешно перенёс неизменные файлы. Повторять Android-тест или пересобирать APK для этого не потребовалось. Все попытки сохранены в CODEX_EFFICIENCY_16G.md.

## APK для телефона

Открыть [закрытый draft GitHub](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/tag/untagged-6cd4718e5ea711c5c181) в браузере под аккаунтом с доступом к репозиторию → Assets. Нужны только APK; JSON-файлы — технические доказательства, устанавливать их не нужно.

- [MASTER — master26.apk](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-6cd4718e5ea711c5c181/master26.apk), 193 782 021 байт. SHA256: `0686e546e2d077768557b5c9f48c014d39e21567d798e403cb3040dd5fd3e05a`.
- [CLIENT — client26.apk](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-6cd4718e5ea711c5c181/client26.apk), 193 782 061 байт. SHA256: `0e9dee30d62b0a05097652d159ea0c035b4c1bad424e662516ede822dbe64a0c`.

Это подписанные debug QA builds 0.4.18+26 с прежней стабильной подписью. MASTER: `ru.sulfi.sulfi_hypnotherapy`; CLIENT: `ru.sulfi.sulfi_hypnotherapy.clienttest`. Сертификат SHA256: `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`.

На Google Drive APK не загружались. Draft приватный: сторонний тестировщик без доступа к репозиторию его не скачает; владелец может передать скачанную APK через Quick Share. Скачивание через авторизованный GitHub API реально проверено; сессия браузера телефона владельца не имитировалась.

## Точные исходники

| Назначение | Commit |
|---|---|
| APK25 baseline | `012f7f69b7ad99c0d44f2a442d9649aa1481117e` |
| База ветки, PR46 | `b0cb53f374e651be70df98e479be9605280177b3` |
| Полностью проверенный runtime/test source | `11909895da4f2967b77f12a8b8da98ff50b370d5` |
| Единственный выданный APK producer | `9b94f24f3e5302c20a96dce5a2e7bdc074c21a1c` |
| Native QA driver | `c3b8f06b5fc600e5ab20af5424ae66d4702b9c86` |
| Delivery-only workflow | `721722fb18ed6aec9b188af78b92e1fb60c00a44` |

Семь runtime/test/server Git trees APK producer совпадают с полностью проверенным source1190989. Три внутренние build-попытки дали одинаковые SHA; это одна выданная пара. Последующие checkpoints меняют отчёты/CI/документацию.

[Draft PR47](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/47): `fix/task16g-stabilize-programs` → `hotfix/task16v-p0-data-preservation`. [Full verify](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43350711471) · [Native QA](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43403971950) · [Delivery SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43406075443).

## Остаток и первый шаг владельца

AUTH-01–03 и PUB-01–06 требуют настоящих Google MASTER/CLIENT, живого Drive, публикации/установки и сетевых переходов. DAT-07 остаётся PARTIAL: preflight/WAL/hot-journal и native fault проверки пройдены по компонентам, но полного аппаратного fault matrix нет. REL-02 — физическое обновление MASTER, обновление CLIENT25 и слышимость офлайн. Автоматические fixtures эти пункты не заменяют.

Точный протокол из 10 шагов — OWNER_PHONE_QA_16G.md. Первый шаг: на своё усмотрение создать заменимый контрольный набор в текущей MASTER25 и зафиксировать его состав. Затем по отдельному решению владельца установить MASTER26 поверх25 без удаления/очистки и сравнить объекты после запуска и перезапуска. При конфликте подписи — остановиться, приложение не удалять. Далее: Google MASTER → каталог модуля с тремя треками и программы → ссылка из дневника → другой Google CLIENT → выборочная установка → авиарежим и слышимость. ПК, пароли и токены не нужны.

Ранее потерянные тестовые объекты не восстанавливались по новому решению №16-Г. Исторический root cause телефона остаётся UNKNOWN. Main, PR45/46, APK24/25, GAS6, старый дневник, signing, Google ACL и данные владельца сохранены; BOUNDARIES_FINAL_16G.json содержит readback. Merge, production deploy, публичного release и №17 нет. Сохранение неопределённых файлов может увеличивать занятое место; отдельный доказанный GC отложен.

## Отчёты

Семь требуемых файлов №16-Г сохранены в [существующей папке отчётов №16](https://drive.google.com/drive/folders/1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z). Старые отчёты не перезаписываются. Доставка всех семи с проверкой байтов, SHA и parent подтверждена DRIVE_READBACK_16G.json. Точные receipts и скриншоты находятся также в `reports/task16g` в PR47.
