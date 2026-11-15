# №18 — G1: контролируемая архитектура и границы

## Контракт

Одна domain DB library.sqlite/schema9. Существующие alchemist_card:* и alchemist_diary_queue:* остаются source of truth публикации; existing upload checkpoints/requestId/session/offset/receipt сохраняются. Новые явные download intent records в той же app_settings описывают установку каталога или cache media; это отдельное направление, не дубликат публикационной очереди. Работает один OS-backed executor на APK. MASTER и CLIENT имеют разные applicationId/приватные файлы/Keystore; общий код не означает общую физическую базу.

UI durable enqueue → Android UIDT(API34+) / dataSync FGS(API24–33) → отдельный FlutterEngine с transferMain → существующие publisher/installer/API → durable offsets и receipts. Headless engine принадлежит JobService/Service, а не Activity; уничтожение Flutter UI не уничтожает executor. UI никогда одновременно не выполняет второй upload pump. Нативная lease/epoch/control — только authority и execution hints, не вторая очередь/копия manifest.

## Android policy

min24/target36. API34+ user-initiated network JobScheduler.setUserInitiated, RUN_USER_INITIATED_JOBS, system notification, estimate bytes, NetworkRequest. Явный запуск только из visible Activity/допустимого пользовательского действия; OS onStop/timeouts сохраняют состояние, job retry выполняется только разрешённым способом. API24–33 foreground dataSync с разрешением, startForeground немедленно и private notification. Для отложенного recovery — ограниченный regular JobScheduler(network/backoff), без вечного long-running WorkManager и без обещания обойти Android16 quota. Reboot/force-stop не запускают интерактивный вход; очередь не теряется, восстановление только когда ОС разрешает. Android15 dataSync6h/24h и onTimeout документированы, даже если основной путь34+ UIDT. Старый mediaPlayback не используется для данных.

Источники (прочитаны): https://developer.android.com/develop/background-work/background-tasks/uidt ; https://developer.android.com/develop/background-work/services/fgs/timeout ; https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/long-running . OEM/реальные устройства отдельно OWNER NOT_RUN.

## Авторизация

Foreground использует прежний verified Google subject/role; короткий ID token передаётся только в приватную Android Keystore AES-GCM lease, не SQLite/логи. Worker повторно вызывает auth.whoami и сверяет subject-derived scope/owner/role. Каждая RPC проверяет lease epoch/expiry/logout; интерактивный picker никогда не запускается из JobService. Expired/rejected/другой owner → WAITING_AUTH, сохранение очереди. Logout сначала отзывает native lease, затем прежнюю UI identity. PUBLIC lease допустима только для явного чтения опубликованных файлов; не даёт upload/private authority.

## Сохранность и миграция

Без изменения template IDs/schema9/media paths. Аддитивные поля _work: direction/kind/executor/autoResume/timestamps/retryPolicy. Неразличимые старые USER_PAUSED не запускать автоматически. Старые active/paused от17 переводить в безопасное ожидание первоначального owner/явного Resume без сброса requestId/offset/receipt/pending. Только новая явная операция включает native intent. Download: owner-scoped staging и ledger проверенных чанков; flush перед checkpoint, truncate только unconfirmed staging tail, hash+manifest→прежний transactional capsule importer→receipt. Личные исходники не удаляются.

## Pause/cancel/retry

USER_PAUSED только явная кнопка. Home/lock не меняют user intent. Ручная пауза/отмена закрывает следующий dispatch, текущая HTTP может уже получить ack; сохранение его receipt обязательно. Cancellation не unpublish. Network/policy → сохраняемые причины и bounded exponential backoff. Зависший verify имеет предел прогресса/времени, не hot loop. Уведомления показывают реальные X/Y, unknown total без процента; lockscreen private.

## Design gate

G0 завершён до implementation. Контролируемый review: native ownership, один pump, deny cross-owner, logout-before-lease, no token logs, сохраняемый ack/receipt, staged atomic install, API/OEM limits и additive migration зафиксированы. Реализацию разрешает прямое задание владельца; отдельное разрешение обязательно только для production GAS/OAuth/ACL/signing/main. Такие изменения не планируются. Если GAS6 не поддержит точную capability — STOP для соответствующего live сценария и точечный SERVER_CHANGE_REQUEST, без deploy.

## Откат

Не Android downgrade. Сохранять APK27 и оригинальные checkpoints, не менять их формат разрушительно. При regression остановить executor, сохранять файлы/ledger/DB и сделать исправленный versionCode>28. Новые поля позволяют старому коду игнорировать extras, но APK27 не обещается как безопасная установка поверх28. Никакой миграции настоящей базы владельца при разработке.

## Conditional recovery deadline after native a894 cold-failure
An OS-owned persistent2minute watchdog exists onlywhile actual transfers are active. A normalreadyjob may otherwise remain batched afterprocessdeath. If networkpolicy currentlyallows, standardoverrideDeadline=minimumLatency+10sec bounds normalbatch eligibility; Androidmaystilldefer underquotas/restriction/stoppedstate. Network/unmetered policy is rechecked by the worker beforeHTTP because deadlinecanoverride jobconstraints. Offline/metered policywait has nodeadline, hence no endlessdeadlinetimerpoll. Recoveryrun has8mincooperativebudget belowordinary10minwindow; OSstopcancomeearlier and preserves checkpoints. Nonowningwatchdog cannotstop/pause duplicateanexecutor. This is not expedited/FGS-start-from-background, force-run, exactalarm or force-stopbypass. Native/source tests mustverify currentbytes beforeissuance.

## Проверка текущего исполнения и короткой сети

API24–33 уже запущенный пользователем dataSync FGS сохраняет максимум90sec ожидания краткого network retry, выполняя его только в durable due time. Ручная пауза/cancel/auth/policy/чужой owner исключены; обычный regular JobService не получает этого продления. Idle wait прерывается stop/control. Нет дополнительных HTTP до due time.

SQLite остаётся однопоточным: native SQL scheduler откладывает чужую connection, пока текущая transaction владеет thread; COMMIT/ROLLBACK/close освобождают владельца. Это внутреннее упорядочение SQL, не вторая transfer queue. Отсутствует изменение SQL schema, timeout, WAL или реальных данных. Integrity/upgrade/background проходят отдельные native gates.
