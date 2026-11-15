# №18 — ограничения безопасности и незакрытые проверки

Private задачи привязаны к hash(endpoint|server-verified scope), а не к выбранному UI email. Native lease проверяет epoch/expiry/role; worker повторяет whoami, совпадение scope/owner/role обязательно. Manual logout сначала отзывает native authority; интерактивного фонового Google SDK нет. Старые задачи не переименовываются под нового owner. Один уже отправленный запрос невозможно отозвать с сервера; следующий запрос не получает новый аккаунт.

Токен — только короткоживущая Keystore AES-GCM lease в приватных preferences, не в task JSON/backup/trace. JobService защищён BIND_JOB_SERVICE; service/notification receiver не экспортированы. PendingIntent immutable, action owner-bound. UIDT user-stop/Force Stop не обходятся. Recovery/backoff/startup failures ограничены. Ошибка storage не приводит к reset SQLite.

Обычный transferMain всегда использует production connection=null. TestOnly .transferprobe source не импортирован normal main, не получает Google/signing secrets и реальные материалы. Перед выдачей28 нужно binary-подтверждение отсутствия fixture token/class/testOnly/cleartext overlay. Это реально проверено в candidate43708103115 и обоих independent native jobs, sourcecea4897: отсутствие fixture Dart/native classes, testOnly и cleartext overlay, наличие storage guard/public endpoint/правильных permissions PASS. Issuance остаётся отдельным gate до нового-source background доказательств; исходный quarantine receipt не изменён.

Отчёты18 в owner-only MyDrive root folder100klr45KcMk0CNx21nYhoPvwMJ8i8xv-. Повторный metadata read показал только user/owner. Наследование public-writer For_Codex не использовано, существующие ACL не менялись. APK18 на Drive не загружались; отдельное старое исключение public CLIENT27 не считается разрешением на любой следующий APK.

Реальные Google-пользователи, две физические установки, OEM/power-policy и конечная конфиденциальность уведомлений на телефоне — NOT_RUN. CODE/контролируемые тесты этого не заменяют.

## Изолированные продолжения
Новые SQLite causality probes используют отдельный временный файл внутри testOnly.transferprobe; перед сменой экспериментального числа потоков не открыта production DB. Изменение pool на живой базе не производится. Host minidump parser читает только exception/module metadata с allowlist basename и bounds; stack/environment/raw dump не выгружаются. На диагностическом MASTER43733477006 minidump отсутствует; это не доказательство fault function. Новые normalAPK вexisting PRIVATE draft не загружены: fail-closed delivery требует6реальных native receipts; no create/publish/tag/delete/clobber/main/ACL/OAuth.

## Текущий кандидат DE408

Candidate43744944796 реально проверил оба normal APK: прежний certificate SHA256, package/version/config, permissions, StorageSafety, отсутствие fixture classes/testOnly/cleartext. FullVerify489Flutter PASS. Signing/main/Google OAuth/ACL/GAS6/старые27 неизменны. Доставочный guard теперь дополнительно отвергает пустые/неполные/дублированные/не-PASS cases, иной source/driver, изменённый JSON и path traversal:8локальных tests PASS. Metadata read15.11 подтвердил owner-only folder; ACL не переписывались.

Actual candidate delivery43765843573: onlytwo normal28assets addedtoexistingPRIVATEdraft, original27IDs/SHAunchanged; authenticatedindependentassetdownloadSHA/certverified. No publicrelease/newtag/repoprivacy/DriveACL/productionGAS/signing/main changes. Ownerreportsfolder remainsprivate; APKfilesNOTuploadedtoDrive.9guardtestsinclude canonicalrootURL regression; fail-closed assertionsretained.
