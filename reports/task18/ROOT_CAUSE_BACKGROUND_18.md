# №18 — G0: подтверждённые причины и границы

База506619a (приложение APK27:fbdaa7b). Полное ТЗ GoogleDoc сохранено docs/task18/TASK_RU.md с revision/SHA. Свежие RESULT/TESTS/ISSUES №17 прочитаны с Drive; №17 остаётся PARTIAL. Владелец сообщил штатное физическое обновление26→27, но это не новая проверка всех материалов.

1. AlchemistQueueIndicator.didChangeAppLifecycleState вызывает pauseAll на paused/detached. Это намеренное ограничение APK27, а не гарантия Android-фона.
2. AlchemistWorkQueue._pump принадлежит UI Dart isolate. Локальный SQLite outbox устойчив, но нет Android transfer JobService/dataSync executor. Manifest содержит только mediaPlayback, который не является разрешением передачи файлов.
3. StoreScreen.install передаёт interrupted:paused||!mounted: закрытие страницы останавливает выборочную установку. Install download partial существует на диске, сама задача установки не persistent.
4. Diary media/covers загружаются непосредственно из UI resolver. Reader sync имеет маленький persistent outbox, но HTTP принадлежит UI. Metadata mutations публикации принадлежат существующей очереди; переносить их в новый backend нельзя.
5. Низкая скорость: каждый256KiB upload — отдельный GAS RPC; commitUpload затем делает ещё один Range256KiB и сериализованный SHA checkpoint на каждый блок. Последовательность обоснована server integrity. Трёхтрековая публикация дополнительно регистрирует манифесты и проверяет receipt. Это источник round trips в коде, а не измеренный throughput Wi-Fi владельца. Trace должен различать их, не ослаблять ACL/SHA.

USER_PAUSED/attempts0 старых задач не доказывают сетевой отказ: явная старая пауза остаётся паузой. По owner screenshots нельзя вывести скорость или успешный commit. Серверный короткий message без blocks — отдельный известный GAS6 дефект №17, не причина жизненного цикла.
