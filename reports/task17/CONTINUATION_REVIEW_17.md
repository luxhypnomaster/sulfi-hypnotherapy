# №17 — продолжение по ограниченному разрешению владельца

## Production STOP

Разрешены подготовка и проверка трёх файлов, но не main/push/deploy/rollback. main0800f34... сохранён. GoogleJwt/Router/весьPR48 не переносились. Разрешение на production apply НЕ запрашивается до административных доказательств.

Полный diff: review_only/THREE_FILES_FULL_17.diff, исходник инструмента03a0ea8. Добавлен inspect с GET-only административным чтением, ранним return до записи/CLI.9проверок и затем независимый разбор выявил отсутствующий контроль типа файлов: identical SHA+JSON GoogleJwt ранее принимался; новый regression RED→строгий SERVER_JS/JSON guard GREEN,10tests. Ещё два отдельных процесса подтверждают READ_ONLY_INSPECTION не допускает apply/rollback до credentials/Google. Это controlled, не внешний человеческий аудит и не LIVE readback.

Административный readback BLOCKED: Google OAuth только в repository secret Actions, допустим только trusted main. Доступные main workflows не предоставляют весь требуемый numeric version/file manifest. Не подменять live историческими hashes/health. Владелец получил точный отдельный запрос на перенос только этих3файлов и mode=inspect/execute_approved_patch=false. Ответ не получен; перенос и запуск не выполнялись. Saved rollback в SERVER_CHANGE_REQUEST_17.md сохранён и не выполнялся.

Архив SERVER_REVIEW_ONLY_17.zip на Drive:1ox7BmiwikMFmMO-HqDCidzByA8x8M11Y, parent17; raw SHA/size/parent proof review_only/REVIEW_DELIVERY_17.json. В архиве полный diff, сами3файла, тесты, manifest и сохранённый rollback. Старые отчёты остаются историей.

## MASTER native: новая проверяемая гипотеза

43582943729, driver ef84719, cached app fbd, API34 вместо35: baseline UI PASS частично, оба lane остановились CANNOT_RETURN_HOME до candidate. Сохранены SHA receipts/screens/XML в native_api34_attempt1. Оба снимка показывают системный Launcher, а не аварийное приложение. resource-id com.google.android.apps.nexuslauncher:id/... присутствует; home() распознавал только устаревшие английские подписи. Это подтверждённая причина DRIVER failure, не data loss и не оправдание снятия gate.

Исправлен только driver is_android_launcher: наблюдённый resource-id, ANR не игнорируется. Реальные два XML positive и app/ANR negatives PASS (1unittest,4assertions). App Back/бинарники/SQLite не менялись. Новый адресный повтор 43583577375, driver56a9b36, толькоMASTER25/26 API34 с exactcachedfbd SHA+469/build proof. Состояние PENDING; не считать PASS до raw receipt. Большие Flutter/build/подпись не повторялись. API34 не доказывает исчезновение прежнего API35 launcher/qemu сбоя.

APK27 остаются QUARANTINED/NOT_ISSUED; настоящийGoogle/двухтелефонныйE2E NOT_RUN. Старые25/26/данные/дневник/ACL/OAuth не менялись. Следующее действие — дождаться текущегоCI и readback receipts; не запускать заново G0/fullverify или очередной слепой emulator. Затем получить read-only main inspect permission; production apply потребует ещё отдельного согласия после проверки.
