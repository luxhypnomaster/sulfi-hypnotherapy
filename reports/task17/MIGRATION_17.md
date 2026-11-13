# №17 — сохранность и обновление

Схема SQLite9, пути локального audio/diary/history media, template IDs и модели не мигрируются. STORAGE_SOURCE_BOUNDARIES_17.json подтверждает byte-identical data bootstrap/library/capsule/native storage guard/signing/MainActivity относительно PR47. Android Back handler не изменялся.

Новые состояния/intent/profile/identity hints используют существующий app_settings; таблицы не сбрасываются, нет GC/orphan cleanup, удаления, импорта поверх базы или автоматического восстановления пустой БД. Unsigned/unowned старые задачи не получают cloud owner автоматически. Старые APK и source SHA сохраняются.

Native gate PENDING: три независимых Android35 sandbox с baseline MASTER25, MASTER26, CLIENT25. Данные создаются UI:3 различных аудио (два одинаковых display title),2 модуля включая положительную паузу, программа, текущая конфигурация и история. Нормальное `adb install -r` в disposable emulator, затем сравнение IDs/полных строк и SHA медиа/integrity, cold restart. Ни uninstall, ни clear, ни downgrade не применяются. UI-before-Google drafts на старых immutable APK могут быть недоступны: такой пробел нельзя закрыть SQL-seeding. Новый offline MASTER draft после обновления проверяется отдельно и не выдаётся за upgrade старого Google draft.

Сертификат ожидается прежний SHA2560b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6; packages MASTER ru.sulfi.sulfi_hypnotherapy и CLIENT ru.sulfi.sulfi_hypnotherapy.clienttest. VersionCode27 >25/26. Выдача пары только после native safety и raw artifact readback; пока PENDING.

Rollback Android: исправленная сборка с БОЛЬШИМ versionCode и сохранённой схемой/подписью. Не предлагать downgrade/uninstall/clear. Git revert не является резервной копией персонального аудио. При installer conflict STOP и диагностика без удаления приложения.

Серверный rollback после отдельно разрешённого патча — восстановление прежней immutable deployment version6, без удаления Drive или private data. Пока сервер не менялся, rollback не выполнялся.
