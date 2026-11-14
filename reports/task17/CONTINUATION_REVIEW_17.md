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


## Итог текущего цикла — 14.11.2026

Run43583577375 completed FAILURE (один lane PASS, второй BLOCKED). Идентичность определяется baseline из SHA-проверенной квитанции и Actions job metadata, не порядком job IDs: во втором run порядок25/26 изменился. Предварительное устное обозначение job до readback было неверным и исправлено.

- MASTER25→27 API34, job132413251139:13PASS+legacyGoogleDraft1NOT_RUN. Реальные UI3импорта,2модуля с положительной паузой, программа/current/history; normal native update, exact rows/media SHA/integrity, UI видимость, cold restart, новый offline local-device draft с точными title/message и cold persistence PASS. Не человеческое прослушивание и не Google вход.
- MASTER26, job132413250955:5PASS, затем old baseline watch instrumentation ADB failed; qemu исчез, ADBoffline, freeRAMпосле6965MB. Candidate27 НЕ устанавливался. OOM/exit cause не доказаны; grep fallback сработал, сообщений OOM в сохранённой диагностике нет. Android34 не устранил прежний qemu отказ. Тот же emulator повторно не запускать без новой доказанной причины/способа диагностики. Не менять приложение ради неподтверждённого host crash.
- CLIENT25→27 API35 по прежнему43548636228:12PASS+legacyGoogleDraft1NOT_RUN, сохранено как независимое прежнее доказательство. Не смешивать платформы и источники. APK source всех проверокfbd неизменён.

Все receipts/screens/rawSHA readback второго API34 в native_api34_attempt2/{master25,master26}. NATIVE_REVIEW_RESULTS_17.json связывает actual baseline↔job. Gates не ослаблены. Пара27 НЕ выдана; release/delivery не запускались, настоящий двухтелефонныйE2E NOT_RUN.

Проверенные границы: main0800f34... неизменён; production workflow не имеет dry-run и НЕ запускался; новый inspect tool в main НЕ перенесён. Административная version/23файла/executeAs/access LIVE остаются BLOCKED, не PASS. До согласованного read-only main запуска не запрашивается разрешение применять Diary patch или rollback. Действующее разрешение — только preparation/review.

Затраты продолжения:2cached native cycles (43582943729:новаяAPI34гипотеза;43583577375:исправление подтверждённого navigation driver по XML). Ни fullFlutter, ни APK build/sign не повторялись. Дополнительные server-checks автоматически на push:43582947578,43583183562,43583582178,43583699206 SUCCESS; не объявлены живым сервером. Native navigation1unittest с4assertionsPASS, server tool10NodePASS,2отдельных negative grant processesPASS. Проценты пользовательской квоты неизвестны. Последующие повторные VM не запускались.


## Более позднее разрешение и actual admin PASS
Владелец разрешил3files+inspect. Main b88637a содержит только согласованные3файла ef84719; CI43584729310SUCCESS, actualversion6/HEADsame/full23hash/type/executeAs/access PASS. Production apply/rollback НЕ разрешены и НЕ выполнялись. SERVER_ADMIN_RESULT_17.md / review_only/ADMIN_READBACK_17.json — актуальное состояние; прежний текст BLOCKED выше сохранён как хронология, а не текущая блокировка. MASTER26native остаётся BLOCKED, APKневыданы.
