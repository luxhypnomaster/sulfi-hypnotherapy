# №17 — ограниченное разрешение владельца, production STOP

Владелец разрешил подготовку и независимую проверку трёх файлов. Не разрешены перенос в main, push/deploy/rollback production или перенос других server diffs. Это разрешение не трактуется как разрешение применения.

Полный diff относительно фактической origin/main0800f34: THREE_FILES_FULL_17.diff (176+ строк; точная версия ef84719). Только workflow, approved_diary_patch.mjs, test_approved_diary_patch.mjs. INSPECT_DELTA показывает изменения к предыдущему кандидату.9Node controlled tests PASS; это не независимый человеческий review и не live admin proof.

Добавлен inspect: только GET Script, deployment, content(version6), HEAD; подтверждение owner; exact23files,20JS+vendor pinnedSHA; version6/HEAD equality/InitialConfig owner/source; execution/access/endpoint. Выводятся только sanitized administrative identity/config, oauthScopes и name/type/bytes/SHA, не содержимое InitialConfig или credentials. Выход до clasp push/create-version/create-deployment. Read-only grant не позволяет выбрать apply/rollback; прежний main-only guard сохранён. Любое расхождение STOP.

Административный readback сейчас BLOCKED: локального clasp credential нет; repository secret доступен только Actions доверенной main. Старые workflows runtime/auth-status не возвращают нужные version/file hashes; historical health не заменяет admin readback. Новые три файла НЕ перенесены в main; feature не получает Google secret. Нужен отдельный разрешённый способ запуска inspect (например, согласованный перенос ровно этих трёх reviewed файлов в main и ручной запуск только mode=inspect без execute_approved_patch). Это НЕ разрешение production apply/rollback. До actual readback запрос на применение patch преждевременен.

План отката сохранён в SERVER_CHANGE_REQUEST_17.md: immutable6, тот же deployment/executeAs/access, проверка active file manifest принадлежит только Diary patch, readback после переключения; никаких Drive data/ACL/OAuth изменений. Сам rollback запрещён до отдельного будущего разрешения.

Native: ef84719 меняет только cached QA runner, не приложения. Один сравнительный API34 цикл, MASTER25 и MASTER26, fbd immutable pair, exact prior469 verify/build плюс SHA/bytes/core trees. Прежние API35 fail сохранены. Новые результаты PENDING, ничего не выдано. API34 не доказывает устранение API35 launcher/qemu сбоя. При повторном отказе не запускать тот же прогон автоматически.
