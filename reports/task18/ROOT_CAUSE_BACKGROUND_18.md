# №18 — G0: подтверждённые причины и границы

База506619a (приложение APK27:fbdaa7b). Полное ТЗ GoogleDoc сохранено docs/task18/TASK_RU.md с revision/SHA. Свежие RESULT/TESTS/ISSUES №17 прочитаны с Drive; №17 остаётся PARTIAL. Владелец сообщил штатное физическое обновление26→27, но это не новая проверка всех материалов.

1. AlchemistQueueIndicator.didChangeAppLifecycleState вызывает pauseAll на paused/detached. Это намеренное ограничение APK27, а не гарантия Android-фона.
2. AlchemistWorkQueue._pump принадлежит UI Dart isolate. Локальный SQLite outbox устойчив, но нет Android transfer JobService/dataSync executor. Manifest содержит только mediaPlayback, который не является разрешением передачи файлов.
3. StoreScreen.install передаёт interrupted:paused||!mounted: закрытие страницы останавливает выборочную установку. Install download partial существует на диске, сама задача установки не persistent.
4. Diary media/covers загружаются непосредственно из UI resolver. Reader sync имеет маленький persistent outbox, но HTTP принадлежит UI. Metadata mutations публикации принадлежат существующей очереди; переносить их в новый backend нельзя.
5. Низкая скорость: каждый256KiB upload — отдельный GAS RPC; commitUpload затем делает ещё один Range256KiB и сериализованный SHA checkpoint на каждый блок. Последовательность обоснована server integrity. Трёхтрековая публикация дополнительно регистрирует манифесты и проверяет receipt. Это источник round trips в коде, а не измеренный throughput Wi-Fi владельца. Trace должен различать их, не ослаблять ACL/SHA.

USER_PAUSED/attempts0 старых задач не доказывают сетевой отказ: явная старая пауза остаётся паузой. По owner screenshots нельзя вывести скорость или успешный commit. Серверный короткий message без blocks — отдельный известный GAS6 дефект №17, не причина жизненного цикла.

## Native continuation source59 — граница доказанного

API34/36 полные controlled background сценарии PASS; это доказывает устранение зависимости исполнения от UI на этих API, но не покрывает Google/OEM/все Android. API35 после15MiB transfer и новогоUI наблюдались повторные sqflite lock warnings, очередь ещё running и inventory0. Статический аудит: vendored sqflite_android2.4.5 использует один process-global native HandlerThread; фоновый executor открывает отдельный handle singleInstance=false к той жеSQLite. Возможный lock order: handleA держит SQLite write transaction, операция handleB занимает единственный native thread в ожиданииA, A COMMIT остаётся позадиB. Это ГИПОТЕЗА, не установленная причина; isolated native two-handle experiment43734927899 проверяет default1 против4 потоков без открытия library.sqlite. До результата менять рабочий pool и выдавать APK нельзя.

API33 network-auto recovery в43732897880 не подтверждён за120sec. Без end-snapshot JobScheduler/network нельзя приписать ошибку OAuth/серверу/производительности.43734790304 добавляет read-only scheduler/services/network evidence при прежнем критерии, без принудительного старта.

MASTER43733477006 не повторил прежний QEMU SIGSEGV: host process exit0, нетOOM, ошибка произошла до обновления в одноразовом поиске seconds-wheel semantics. Последующий failure XML содержит реальный android.widget.SeekBar с `0, Секунды`; observer теперь ждёт именно этот элемент20sec и выполняет прежний физический vertical gesture. Это исправление test-observer, не доказательство исправления старого неизвестного native crash и не изменение паузы APK.

## Продолжение после scheduler readback и native SQLite controls

API33/43734790304: recovery1802 имеет TIMING_DELAY/CONNECTIVITY и все неявные условия, Ready=true, !pending/!active, validated Wi-Fi104. Foreground service уже отсутствует; ordinary job batching допускает длительную задержку. Исправление2ec64b4 сохраняет уже разрешённый пользовательский FGS на короткое90sec retry-window, не сокращая durable retryAt и не предоставляя того же окна regular JobService. Owner/lease/user pause/cancel не меняются. Four targeted tests+localanalyze PASS; новая native-проверка этого кода ещё NOT_RUN.

SQLite: фактические pool1/43736599516 и pool4/43737027095 на native Android SQLite оба дали SQLiteDatabaseLockedException при намеренно перекрывающихся write transactions. Изолированные данные; production DB не открывалась. **Pool-only fix rejected** — THREAD_COUNT остаётся1. Эти контроли не доказали точную причину бесконечного Dart mutex wait в API35 install.

Добавление busy_timeout в отдельном native эксперименте43737664851 не дало ни PASS, ни SQL failure receipt: Android child app_process завершился137/Killed. Причина неизвестна; QEMU crash/hostOOM не приписываются без доказательств.43738174779 исполняет только положительный4-thread bounded-busy control с phase/PID stdout и read-only LMK/ActivityManager/memory dump при такой ошибке. Рабочие PRAGMA/schema/vendor SQLite исходники пока НЕ менялись. Не повторять слепо старые negative runs и не выдавать эксперимент за доказанный fix.

## Native candidate transaction arbitration — direct evidence
43739426806 produced BOTH_COMMITS_COMPLETE/rows2/integrityok/errors0, A_COMMITTED precedesB_WRITE_STARTED. Existing one-thread executor previously admitted foreignconnection SQL while a transaction's nextCOMMIT needed that same thread. Candidate defers foreign SQL until actualowner commit/rollback. Stock4threads/busy tweaks rejected by failed controls. This is real AndroidSQLite/source-overlay evidence, not shippedAPK/Google proof. OverallrunFAIL was wrong observerdefaultbusy assertion2500vs0; no greenrun fabricated. Exact scope: SQLITE_SCHEDULER_PROOF_18.md. Promoted source still needs real app/background/upgrade regression to associate with API35 install failure.

## a894 cold-process gate: actual cause boundary
API34/43742074940: oldPID2942, no newPID for660sec; uploaded2621440 and verified0. Both1801(original nownon-UIJ) and1802persistentwatchdog Ready=true/notpending/notactive, network100validated, no newworker/bootstrap/DBopen occurred. This proves scheduling did not restart the process in the test window; it does not indicate corruptDB or failedSQLite recovery. New standardconditionalJobScheduler deadline (delay+10sec onlyif currentnetworkpolicy allows) addresses batchedreadyregularjobs. Crashwatchdog2min onlywhile active; regularrecoveryrun bounded8min, OSstop/quotas stillauthoritative. Offline/metered waits do not get deadlinepolling; lease rechecksactualnetwork beforeeveryHTTP and startupnetworkfailures becomeWAITING_NETWORK. New runtime stillunverified: no issuea894.

## Текущий DE408: подтверждение исправления cold-recovery

43744948169 API34 full SUCCESS11: реальный новый PID3205 после SIGKILL PID2975 за6,98sec, прежние task/request/session/source SHA/offset и2новых уникальных чанка. Никакого UI или force-run в cold-case. Это проверяет conditional-deadline реализацию на Android14; не гарантирует старт вопреки Force Stop/OS quota/OEM. Fullverify текущего исходника489Flutter PASS. CLIENT normal27→28 13PASS. MASTER API34 QEMU SIGSEGV до update — отдельная инфраструктурная ошибка без OOM; current-source native rerouteAPI35 ещё должен завершиться.
