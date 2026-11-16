# №19 — миграция и rollback G0–G1

Реальной миграции нет. Исходник APK28de408f1 и baselinebranch363a024 сохранены, PR49не объединён. Новые .auth19 packages не могут штатно заменить ru.sulfi.sulfi_hypnotherapy или .clienttest; у них другой applicationId/UID/noBackup vault. Действующие SQLite schema9/audio/drafts/queue/media/checkpoints/token hints не изменяются. pubspec/lockfile и версия28 сохранены, стабильные signing secrets не использованы.

Default: SULFI_AUTH19_STAGING отсутствует/false, Android auth19 source sets не включены; обычный main.dart не импортирует прототип. При true Gradle требует lib/main_auth19.dart, запрещено смешение с .transferprobe. Это отдельная диагностическая оболочка, не редизайн продукта.

Откат прототипа: оставить flagOFF и исходную APK28 на телефоне, либо revert только новых task19 commits в feature branch. Ни downgrade, ни clear/uninstall/перенос данных владельца не требуется и не выполняется. Не публиковать prototype package как обновление MASTER28. Не удалять auth19 vault автоматически ради устранения ошибки; при storage fault сохранить файл и диагностику.

По стадиям: G0audit→G1isolated auth live/owner proof→отдельное approvalG2 identity/RLS→G3 verified bridge+dryrun+rollback→только потом решение о подключении к существующим queue. Никакого автоматического cutover, bulk linking поemail, новой файловой инфраструктуры, Storage, real billing или production deploy.

Для будущего production APK обязательны новый versionCode, прежние applicationId+certificate, native upgrade safety, проверка оригиналов/истории/очереди, все owner acceptance gates. №18 partial не переименовывается в закрытый PASS. Owner-reported physical facts из REG-02 новогоТЗ признаются именно сообщением владельца, а не тестом Codex.
