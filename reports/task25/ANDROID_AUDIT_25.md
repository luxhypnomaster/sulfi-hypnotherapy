# Android — read-only проверка №25

Toolchain/pins: `scripts/task23/native_source_pins.json`; все 31 исходный native/config pins неизменны (точное число см. SOURCE_GATE). Installed Flutter3.47.9 задаёт compile/target36, min24 — в Gradle. API36 подтверждён официальной страницей Android Developers на22.11.2026; источник и SHA в SDK_REVIEW. Это не проверка compiled APK/готовности к магазину.

MASTER ID `ru.sulfi.sulfi_hypnotherapy`, CLIENT ID `ru.sulfi.sulfi_hypnotherapy.clienttest`. Auth19/transferprobe — отдельные экспериментальные suffix, не кандидаты обновления. Pubspec0.4.20+28 не повышался без сборки. Предыдущий сертификат0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6 — историческое свидетельство, не новый signer readback.

Manifest: RECORD_AUDIO/POST_NOTIFICATIONS, mediaPlayback+dataSync foreground-service permissions и services сохранены. JobService защищён BIND_JOB_SERVICE, FileProvider и transfer controls не exported. MediaBrowser/MediaButton exported согласно существующей audio_service интеграции; семантика/права не изменялись. Бэкап выключен; extraction rules исключают все домены и cloud, и device-transfer. Ограничения Android сохраняются, гарантии вечной фоновой работы не заявляются.

`StorageSafety.java` скомпилирован javac17 target против Android36 SDK — PASS_TYPE_COMPILE. Callback по-прежнему бросает SULFI_STORAGE_CORRUPT_NO_RESET и не вызывает штатный удаляющий corruption handler. Это проверка типов, не запуск Android SQLite callback. Единственное предупреждение javac: system modules path not set for -source17 при JDK21.

Отдельный Kotlin/JVM прогон не состоялся: самостоятельного kotlinc нет, bundled SDK compiler сначала не нашёл IntelliJ dependency; с полным SDK classpath не нашёл Jansi. Две разные диагностические гипотезы, дальше установок/повторов нет. Фактические Gradle/Kotlin2.4 native tests и OS scheduler — BLOCKED_ENV, не PASS.

Эмулятора и /dev/kvm нет, локальный signer не предоставлен, cloud secret bindings пусты. Не запускались flutter build apk, Gradle, AAB, emulator или install. Default debug key не генерировался. Исходники main/GAS/OAuth/signing и устройства владельца не изменены.
