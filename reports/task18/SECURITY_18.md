# №18 — ограничения безопасности и незакрытые проверки

Private задачи привязаны к hash(endpoint|server-verified scope), а не к выбранному UI email. Native lease проверяет epoch/expiry/role; worker повторяет whoami, совпадение scope/owner/role обязательно. Manual logout сначала отзывает native authority; интерактивного фонового Google SDK нет. Старые задачи не переименовываются под нового owner. Один уже отправленный запрос невозможно отозвать с сервера; следующий запрос не получает новый аккаунт.

Токен — только короткоживущая Keystore AES-GCM lease в приватных preferences, не в task JSON/backup/trace. JobService защищён BIND_JOB_SERVICE; service/notification receiver не экспортированы. PendingIntent immutable, action owner-bound. UIDT user-stop/Force Stop не обходятся. Recovery/backoff/startup failures ограничены. Ошибка storage не приводит к reset SQLite.

Обычный transferMain всегда использует production connection=null. TestOnly .transferprobe source не импортирован normal main, не получает Google/signing secrets и реальные материалы. Перед выдачей28 нужно binary-подтверждение отсутствия fixture token/class/testOnly/cleartext overlay. Оно NOT_RUN, поэтому safety release пока запрещён.

Отчёты18 в owner-only MyDrive root folder100klr45KcMk0CNx21nYhoPvwMJ8i8xv-. Повторный metadata read показал только user/owner. Наследование public-writer For_Codex не использовано, существующие ACL не менялись. APK18 на Drive не загружались; отдельное старое исключение public CLIENT27 не считается разрешением на любой следующий APK.

Реальные Google-пользователи, две физические установки, OEM/power-policy и конечная конфиденциальность уведомлений на телефоне — NOT_RUN. CODE/контролируемые тесты этого не заменяют.
