# Источники, точные baseline и неизменяемые границы

Ветвь исправлений №16-Б: `fix/task16b-auth-transfer-publication`; draft PR45: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45 . Зафиксированный исходник APK25 `012f7f69b7ad99c0d44f2a442d9649aa1481117e`. MASTER APK24 `0.4.16+24` source `cbe05240d463b9dafbe9a12ee831c967bdbf6113`; MASTER APK25 `0.4.17+25`, package `ru.sulfi.sulfi_hypnotherapy`, same release certificate (reported SHA256 `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`). Клиентский package отдельный, `ru.sulfi.sulfi_hypnotherapy.clienttest`. Версии и сертификаты самостоятельно проверить по реальным APK, а не считать документацию доказательством.

Отчёты №16-Б: https://drive.google.com/drive/folders/1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z ; `RESULT_16B.md`, `ROOT_CAUSE_16B.md`, `CHANGES_16B.md`, `TESTS_16B.md`, `BASELINE_AUDIT_16B.md`, `EMULATOR_16B.md`, `APK_INFO_16B.md`, `PHONE_QA_16B.md`, `ACCEPTANCE_16B.csv`, `EVIDENCE_16B.zip`.

До этого Codex сообщил emulator update24→25 PASS для audio/history/template/diary/SQLite integrity, но fixture **синтетическая**. Real MASTER owner QA опровергает релевантность этого PASS. Прежний запуск эмулятора `43165399224`; corrected probe `43196379265` имел самостоятельный navigation BLOCKED. Обязательно рассмотреть, почему тест не поймал реальный сценарий, и создать доказательно новый gate.

Реальное наблюдение владельца: именно **штатное обновление**, не чистая установка. Его не переспрашивать. Нет доступа к физической базе/ADB. Статус данных: `MISSING_FROM_UI_AFTER_STANDARD_UPDATE; PHYSICAL_BYTES_UNKNOWN`. Не удалять доверенные старые тесты, но не принимать их как evidence живого восстановления.

Не создавать свежий сервер и не обновлять GAS ради этого дефекта. Замена алгоритмов авторизации/reader scope, чтение БД и миграции могут быть релевантны, но причина неизвестна. Обновления из исследовательских PR42/43/44 не объединять без отдельной проверки. Если источник проблемы в ветвлении от не того commit, восстановить цепочку изменений и delta 24→25 независимо от заявленного PR.
