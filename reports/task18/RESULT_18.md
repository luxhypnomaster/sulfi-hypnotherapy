# №18 — PARTIAL; новая APK не выдана

Контрольная точка native-кода: cea4897cbf8b3a4ee33bd6ad0f40edc1bd55b429, ветка feat/task18-native-background-transfer, draft PR49. main, GAS6, OAuth, ACL, подпись и материалы27 сохранены.

Реализован OS-owned headless executor для обеих APK: UIDT34+, dataSync FGS24–33, ограниченный persisted recovery. Существующие intent/очередь/SQLite schema9 сохранены. Добавлены durable download/media/read-sync adapters, owner/role/epoch lease, chunk/whole SHA и final receipts, воспроизводимые retries, системные Pause/Cancel и честные статусы. Дополнительное native исправление ограничивает onStop/timeout конкретным владеющим запуском, чтобы вспомогательное задание не останавливало основной transfer.

## Что действительно проверено

- Полный verify job43704911303/source19c3345:485 Flutter/3CLIENT/47+24Node PASS, contract13schema+4fixture+10negative PASS, формат и анализ чистые. Native изменения после него проверяются отдельно; reuse18 проверяет реально успешный job и неизменность всех Dart/test/server/dependency inputs.
- Native probe43704911357:7PASS на Android API34. После наблюдаемого уничтожения UI-движка и Activity, в том же процессе, при выключенном экране продолжались обе передачи.3 реальных PCM WAV/15728646bytes,1 программа, уникальный commit. CLIENT проверил3whole hashes/модуль/программу, холодно стартовал без Wi-Fi/data и запустил UID-bound AudioTrack. App4ab0588/driver19c3345; это controlled native proof, НЕ Google/GAS/физическая слышимость.
- Finalize43708103115/sourcecea4897 SUCCESS: fresh native build/JVM task PASS; MASTER14/14 и CLIENT12/12 actual normal APK27→28 UI-data safety PASS.3 независимых manifest/SHA/cert/config readback совпали; прежние27 read/SHA PASS. Реальные Google owner queues — controlled unit proof only, не native authenticated PASS. Старый403 устранён без изменения release/ACL. Расширенные probes6/7 остановились до передачи из-за внешнего SystemUI ANR и затем оставшейся открытой шторки; evidence сохранены. Следующий observer-only cached probe готов, без ослабления критериев.
- Скорость:1/15/50MiB loopback TCP/domain и раздельные стадии измерены; Google throughput ещё не измерен. Фиксированное ускорение не заявляется.

## Блокировки / границы доказательств

Новая нормальная пара28 sourcecea4897 собрана с прежним сертификатом, native local-data upgrade gate и3независимых SHA/cert readback PASS. Оригинальный quarantine receipt не переписан; выдача всё ещё не выполнена: новый-source extended background/API coverage остаются NOT_RUN/ожидают доказательств. Старый source19 quarantine не выдавать. Actions artifact upload фактически BLOCKED_QUOTA: continue-on-error не является доказательством upload. Старые artifacts не удалены; APK28 на Drive не загружались.

Настоящие Google MASTER/CLIENT, физические телефоны/OEM, мобильный metered переход, слышимость и25-я приёмка NOT_RUN. TestOnly .transferprobe не выдаётся владельцу и не заменяет сохранность настоящих пакетов. №17 и его server patch не объявлены завершёнными.

Отчёты: https://drive.google.com/drive/folders/100klr45KcMk0CNx21nYhoPvwMJ8i8xv- (owner-only). Дальше: закончить текущие native gates, исправить только подтверждённые дефекты, провести независимую проверку пары, затем согласовать доступную выдачу и дать физический протокол.
