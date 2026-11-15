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
