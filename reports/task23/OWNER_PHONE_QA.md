# №23 — будущая native/Android-приёмка

**Всё в этом документе DEFERRED_BY_OWNER. Сейчас ничего устанавливать и проверять на телефоне не нужно. Новых APK нет.** Инструмент `release_plan.py` только печатает план и отказывается от `--execute`.

## Условия перед отдельным разрешённым выпуском

1. Согласовать source SHA после review цепочки PR52/54/№23. Чистая ветка, сохранённые tests/diff/manifest; не объявлять unmerged draft main.
2. Зафиксировать Flutter3.47.9/framework `c197ca5199e9ee5661e865596c9c07294dfab51c`, Dart3.13.7, engine `89c39edfdfae2949f6806e4a315c0c08522238b7`, Temurin21.0.13+9, Gradle9.3.1, AGP9.1.0, Kotlin2.4.0, SDK36/NDK28.2.13676358/build-tools36.0.0. Java/Kotlin target17, minSdk24. Эти значения прочитаны из исходников/установленных metadata, **не проверены нативной сборкой №23**.
3. `python3 scripts/task23/release_plan.py --source <точный40hex> --version-code <выше максимума установленного> --highest-installed-code <факт>` проверяет pinned sources и печатает команды будущей задачи. Значение29 — пример плана после исторической28, **не занятый versionCode и не готовая сборка**.
4. Подготовить **прежний** защищённый signing key установленной тестовой пары. Не создавать default debug key и не включать секреты в команды/логи. Исторический публичный certificate SHA256: `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6` (`reports/task18/DELIVERY_READBACK_18.json`, не новая проверка байтов APK).
5. После отдельного разрешения выполнить напечатанные `flutter build apk --debug --no-pub --build-number=...` для MASTER и CLIENT по очереди с сохранением каждой APK до второй сборки. Прямой Gradle эквивалент использует `android/gradlew :app:assembleDebug` и параметры, генерируемые pinned Flutter; не гадать вручную Flutter target/dart-defines/version. WrapperURL/AGP/Kotlin pinned в `native_source_pins.json`. В №23 обе команды **не исполнялись**.
6. Независимо скачать полученные APK в другую среду, проверить bytes/SHA, `apksigner verify --print-certs`, `aapt dump badging`, разрешения, отсутствие auth19/transferprobe suffix. Неподписанный Flutter ARM bundle не проходит этот gate и не называется APK. Никакой публичной раздачи без отдельного разрешения.

Стабильные applicationId: MASTER `ru.sulfi.sulfi_hypnotherapy`; CLIENT `ru.sulfi.sulfi_hypnotherapy.clienttest`. Pubspec остаётся `0.4.20+28`, код/подпись здесь не менялись. Release signing в source не настроен; нельзя подменять его случайным ключом. При сборке debug требуется обязательная независимая сверка прежнего сертификата, даже если Gradle успешно завершился.

## Будущий synthetic native upgrade gate

На отдельном изолированном тестовом Android, **не телефоне владельца**, установить историческую допустимую старую версию с прежней подписью, через её настоящий UI создать 3 аудио, модуль, программу, текущую конфигурацию, историю, офлайн-черновик с медиа, экспортную капсулу. Зафиксировать только обезличенные IDs/hash/counts и read-only snapshot; не копировать личные материалы.

Выполнить обычное обновление `install -r` только возрастающей versionCode. Не применять uninstall, clear-storage, downgrade, импорт «для восстановления» и ручное редактирование live DB. Сравнить граф, frozen payload, файлы/хеши, SQLite/WAL/journal, настройки/очередь, локальные материалы без Google, после истечения auth, холодного старта, перезагрузки и смены A→B. При коррупции на **копии** убедиться в fail-closed без пустой замены. Native guard должен сохранить все исходники; произвольный fault fixture не доказывает причину старого owner-инцидента.

## Будущий read-only adb протокол

Только после отдельного разрешения устройства: прочитать `adb shell dumpsys package <applicationId>` для обоих пакетов (installed versionCode/package), путь данных/доступность `run-as` без его изменения, и список/статы файлов в debug sandbox без чтения токенов/личных payload в публичные отчёты. `run-as` может отсутствовать на release: это ограничение, не повод для root/очистки. Проверку SQLite выполнять на согласованной неизменяемой производной, не открывать live оригинал RW. Публичные отчёты содержат только counts/hashes/результаты.

После native PASS — физическая приёмка двух реальных Google-пользователей/телефонов отдельным этапом. Synthetic identities/контролируемый HTTP response не заменяют Google OAuth. Без этого статусы OWNER/LIVE не становятся PASS. Первый шаг владельца **сейчас — review отчётов/draft PR; установка не требуется**.
