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
