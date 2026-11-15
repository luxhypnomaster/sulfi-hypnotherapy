# №18 — текущие изменения, не принятый выпуск

- Android UIDT34+ / foreground dataSync24–33, ограниченные persisted recovery jobs и отдельный Flutter engine; только sqflite plugin, без AudioService/микрофона/пикеров в worker. Home/lock больше не выставляют USER_PAUSED.
- Короткая Google lease шифруется Keystore AES-GCM; native epoch, whoami и role/owner проверяются до private RPC. Logout отзывает native authority до очистки UI-сессии. Публичное чтение не даёт CLIENT права публикации или reader-sync без входа.
- Существующие SQLite app_settings intents/checkpoints сохранены. Добавлены download/install/media/reader-sync adapters и канонические состояния; нет второй очереди вместо старой и нет destructive SQLite migration.
- Upload reconcile после потерянного ответа использует тот же requestId/session/offset; receipt/descriptor проверяются. Catalog transition не создаёт вторую мутацию после восстановления подтверждения.
- Download owner-scoped staging, записанные chunk SHA, fsync→checkpoint, проверка prefix перед resume, whole SHA и persisted finalize receipt. Исправлен подтверждённый truncate/file-cursor дефект; неподтверждённый хвост удаляется только из staging. Исходники/история не удаляются.
- UI-save не подменяет queued/running publication payload. Периодический reader sync сохраняет USER_PAUSED/CANCELED. Native Resume проходит deferred path того же headless pump. Ошибки старта/сети/политики не показывают ложный RUNNING.
- Уведомления приватны на lockscreen, отдельный канал, действия pause/cancel с owner-проверкой. В очереди направления, network policy, реальный byte count, последний прогресс/HTTP/receipt и средняя подтверждённая скорость за запуск. No fixed throughput claim.
- Тестовый native target имеет другие package IDs и testOnly. Его synthetic identity/TCP не являются Google/GAS proof и не включаются в обычный main. Проверка отсутствия fixture в shipping binary обязательна до выдачи.

Не менялись: production GAS6/deployment/ACL/OAuth/signing/main, старый дневник, package IDs обычных приложений, schema9/template IDs/API. Не создавались№19/второй сервер/платный сервис. Новые APK ещё не выданы; 25-критериальная матрица сохраняет NOT_RUN/BLOCKED честно.


## Checkpoint cea4897
Native JobOwnership: scheduler ID+nonce+run generation; non-owner/late onStop never stops primary/newer run; recovery re-armed during long primary; FGS timeout/destruction limited to owned run.4 JVM invariants prepared and executing in candidate pipeline. No schema/path/key/ACL/OAuth/server changes.

Private draft403 fixed by isolated manual baseline GET+SHA/cache job, not by exposing draft or granting rights to APK code. Strict actual-run/tree gate reuses only unchanged passed Dart/server checks. Extended native observers require actual notification Pause/Cancel, same-task/session checkpoints, network automatic recovery and exact resumed range. No prepared test is marked PASS before real receipt.

## Продолжение16:25UTC
Сохранены actualAPI34/36 full PASS иCLIENT27→28 PASS receipts source59; доставка остаётся закрытой. Observer waiting реального SeekBar исправляет подтверждённую race только в nativeUIтесте. Добавлены boundedread-only scheduler/network failure snapshots и отдельный AndroidSQLite двухhandle causality probe на временном файле. Runtime source59/normalAPKbytes пока НЕ менялись; hypothesis ещё не принят заfix. Временная синтаксическая ошибка test-only UI была замечена локальным анализатором и исправлена до актуальногоnativebuild; ошибочный ожидавшийrun отменён.

## Код2ec64b4 — короткий FGS retry, без правок SQLite
На основании actualAPI33 ready-but-not-active recovery добавлено90sec retry-window только для существующего user-started pre34 foregroundService. Сохраняются durable retryAt и filters/lease; manual pause/cancel/stop будят ожидание. Обычный JobService/UIDT не удерживается этим окном. Notification heartbeat не накапливает параллельные незавершённые запросы и показывает waiting label. Fournewtargetedtests/analyze PASS; nativevalidation pending. THREAD_COUNT/PRAGMA/WAL/schema/database originals не изменены: pool-only гипотеза отвергнута реальными negative controls.
