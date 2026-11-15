# №18 — PARTIAL; APK28 пока не выдаются

Ветка `feat/task18-native-background-transfer`, draft PR49; PR48 не объединён. Исходник собранной карантинной пары: `59c3667a28357767533b25e92661b87d081d7227`. Это ещё НЕ разрешённая к установке пара. Production GAS6, main, OAuth/ACL/signing, APK27 и пользовательские данные сохранены.

Реализованы OS-owned Android executor, отдельный Flutter engine без UI/audio plugins, UIDT34+/dataSync FGS24–33, persisted bounded recovery, прежняя durable очередь, owner/role/epoch lease, подтверждённые chunk/whole SHA/receipts, системные Pause/Cancel и метрики. Устранены остановка основного запуска чужим watchdog и устаревшее WAITING_NETWORK уведомление после восстановления.

## Фактически проверено

- Full verify43704911303/source19c3345:485Flutter,3CLIENT,47+24Node,13schemas/4fixtures/10negative PASS; строгий git/source gate подтверждает повторное использование только неизменённых production Dart/server/dependency входов. Новые native изменения отдельно проходят compile/JVM/build/analyze.
- **API34 полный native фон source59 — 11/11 PASS**, run43730572606. Реальное уничтожение Activity+UI engine, прогресс при погашенном экране, Pause, cold explicit Resume, SIGKILL и автоматический OS recovery за6.65sec с другим PID, прежними task/source SHA/request/session; unique commit; network recovery/Cancel/exact range;3WAV+hash/module/program install; cold offline UID AudioTrack. Это controlled loopback TCP, Google/GAS/физическая слышимость NOT_RUN.
- **API36 полный native фон source59 — 10/10 PASS**, run43732895132. Те же сценарии кроме отдельного SIGKILL case, который выполнялся наAPI34. Evidence `api36_59/`.
- **Нормальное CLIENT27→28 — 13/13 PASS**, run43730982434. UI-created3tracks/2modules/pause/program/history/draft +5 supplemental legacy queue rows, прежние файлы/JSON/SQLite сохранены после обновления и холодного старта. Evidence `native59_aosp/client/`.
- Native Android SQLite conversion обеих редакций — PASS43715411268: USER_PAUSED/foreign/unbound не меняются, исходные IDs/request/etag/upload session/offset сохраняются; no legacy auto dispatch. Это отдельная controlled проверка, не Google.
- Candidate job43715408673 SUCCESS: две нормальные signed28 APK, прежний cert, configuration guards и JVM4. Они остаются в карантине.

## Новые непрошедшие gates — не скрывать

- MASTER43730982434: QEMU SIGSEGV до обновления при создании исходной паузы вAPK27; OOM не наблюдался. Следующий диагностический43733477006: QEMU завершился штатно0, исходная пауза открылась, но одноразовое чтение semantics не дождалось SeekBar. Failure XML содержит `0, Секунды`. Новый observer ожидает именно настоящий SeekBar до20sec, затем выполняет реальный вертикальный жест; ни SQL-паузы, ни ослабления критериев. Адресный MASTER-only run43734787048, без пересборки/повторногоCLIENT/full suite.
- API33 run43732897880: MASTER background/commit/Pause и CLIENT background PASS, но network auto recovery за120sec не подтверждён. Новый run43734790304 сохраняет фактические jobs/services/network при той же ошибке; не вызывает force-run/GUI/Resume для подмены автоматического восстановления.
- API35 run43732892168: background/network recovery/Cancel/exact range PASS; при завершении установки и открытой UI база ждёт блокировку. Причина ещё не доказана. Изолированный native causal experiment43734927899 сравнивает один/четыре потока sqflite на отдельном временном файле; настоящую library.sqlite не открывает. Не объявлять гипотезу исправленной до RED/GREEN и full native regression.

Signed source59 hashes: MASTER78fb218edc59b2ddf761cda38e6faaf76e6bcea9b5bea6ab6e0b5a995b8b7767; CLIENTe9fa12f7fd5e9a08e55eec163b2f2d1e6eaed2c260e105226429774e4d0ef821; cert0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6. `APK_PAIR_18` не создан; delivery НЕ запущен. Подготовленный инструмент fail-closed требует шесть доказанных native gates и допускает только новые файлы в существующем PRIVATE draft, без публикации/тегов/перезаписи27. Пока условия не выполнены. GitHub artifact quota не обходится удалением старых artifacts; APK на Drive не загружаются.

Скорость: real-loopback1/15/50MiB измерена, RPC budget/negative PASS; стабильное ускорение не заявляется. Анонимный catalog.list200/4405ms не является Google-входом или измерением Drive throughput. Production Diary message-only EMPTY_ENTRY остаётся отдельным№17 blocker; deploy не выполнялся.

Реальные Google/two phones/OEM/human hearing — NOT_RUN. Задание не закрыто. Отчёты owner-only: https://drive.google.com/drive/folders/100klr45KcMk0CNx21nYhoPvwMJ8i8xv-
