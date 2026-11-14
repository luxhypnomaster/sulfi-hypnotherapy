# №17 — сохранность и обновление

Приложения `fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568`, `0.4.19+27`. SQLite schema9, audio/media paths, template IDs, bootstrap/library/capsule, signing и native storage guard неизменны относительно фактического source APK26 и PR47: STORAGE_SOURCE_BOUNDARIES_17.json. Android Back handler не переписывался.

Новые intent/profile/logout/identity hints используют существующий app_settings. DDL/GC/reset/orphan cleanup/import поверх живой БД не добавлены. Owner hint не credential и не разрешение публиковать. Старые задачи не перепривязываются к чужому owner. Имеющиеся файлы/IDs сохраняются.

## Native доказательства

| Lane | CI outcome | Фактические cases |
|---|---|---|
| MASTER25→27 | failure | JSON receipt ещё не прочитан обратно; запуск не равен PASS. |
| MASTER26→27 | in_progress | JSON receipt ещё не прочитан обратно; запуск не равен PASS. |
| CLIENT25→27 | in_progress | JSON receipt ещё не прочитан обратно; запуск не равен PASS. |

Только UI-created disposable fixture data; копии SQLite/WAL/SHM читаются для полного сравнения строк, integrity и SHA медиа. Ни uninstall, ни clear, ни downgrade не применяются. Отсутствующие legacy Google drafts честно NOT_RUN: их нельзя создать без реального аккаунта или заменить SQL fixture. Новый offline draft после upgrade проверяется отдельно.

## APK и подпись

APK27 НЕ выданы. Собранные бинарники остаются в приватном карантине до полного native gate и независимой проверки скачанных файлов.

Ожидаемые package: MASTER `ru.sulfi.sulfi_hypnotherapy`, CLIENT `ru.sulfi.sulfi_hypnotherapy.clienttest`. VersionCode27 больше25/26. Прежний cert SHA256 `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`. CI проверяет aapt/apksigner, compiled endpoint/WebClientID и DEX storage guard. Raw release readback требуется дополнительно; наличие cache не считается доставкой.

## Откат и ограничения

Android rollback — отдельная исправленная сборка с БОЛЬШИМ versionCode, прежней подписью/схемой. Не устанавливать старый APK поверх нового, не удалять приложение/данные. При installer conflict STOP с сообщением ошибки. Git/APK не являются резервной копией персонального аудио. Физическое обновление владельца до27 — NOT_RUN.

Существующий GAS не менялся. Предложенный отдельно согласуемый серверный rollback ограничен возвратом того же deployment к immutable version6; ни Drive данные, ни OAuth/ACL не откатываются/удаляются. SERVER_CHANGE_REQUEST_17.md содержит конкретный diff/readback/STOP conditions.
