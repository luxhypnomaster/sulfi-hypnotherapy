# №18 — performance baseline, не обещание скорости

Фактические1/15/50MiB (1024²bytes), настоящий loopback TCP, production JS DOMAIN, synthetic binary fixtures, mock Drive. Google/GAS/Wi-Fi transfer NOT_RUN. Проверены SHA/bytes/256KiB RPC counts; upload включает local hash/acks/server verify, download — chunk/full hash/final receipt. Два прохода без pool и с уже существующим production keep-alive pool. Это не новое ускорение18, server CPU/TLS/Google latency не изолированы.

|MiB|Upload без pool,ms|Upload pool,ms|Download без pool,ms|Download pool,ms|
|---|---:|---:|---:|---:|
|1|215.9|190.7|222.4|241.5|
|15|1974.9|1383.6|2874.6|1419.7|
|50|5205.6|4273.2|5048.7|5376.7|

50MiB pooled download был медленнее: фиксированный процент ускорения НЕ заявляется. Upload RPC1begin +4/60/200chunk +4/60/200verify; download1descriptor +4/60/200chunk +1finalize. GAS6 дополнительно проверяет приватные Drive metadata/ACL и сохраняет registry; их реальные длительности без авторизованного прогона не измерены.

Read-only anonymous production health:1734/1652/1877ms, HTTP200, schema1, chunkBytes262144, HTTP Range=false, source1a0cf8e5a60144075eec793767953586bfa319a2 (наблюдение01:36 UTC до перезапуска среды). Это НЕ throughput файлов. Записи/токены/deploy не использовались. Нельзя выдавать health latency ×числоRPC за реальную скорость.

JSON baseline/pooled сохранены в0ed382c. Воспроизведение opt-in: TASK18_PERF_OUTPUT=/dev/shm/perf.json flutter test test/task18_performance_test.dart; второй режим TASK18_PERF_KEEPALIVE=1. Новое сохранение download receipt после baseline отдельно не перемерялось, это не final APK benchmark.

Per-stage safe trace: logical RPC latency/count, localHash, confirmed bytes/wall time/retries, HTTP status/last progress. Не выводятся токены, private URL, тексты/аудио. Live1/15/50MiB Wi-Fi/сервер и multi-file task должны быть сняты после безопасной выдачи28. Серверную оптимизацию только через отдельный diff/rollback/разрешение, production не менялся.


## Актуальный повтор после добавления journal/final receipt,15.11 11:26UTC

Два последовательных opt-in теста на текущем Dart-коде: каждый1PASS,1/15/50MiB и прежние RPC/SHA/bytes условия. Повтор обоснован тем, что первый baseline предшествовал final receipt persistence; запускались последовательно для уменьшения взаимного влияния. JSON PERFORMANCE_FINAL_NO_POOL_18/POOL_18 содержит точный driverSource и ограничения. Native OS/GAS эти Linux-измерения не проверяют.

|MiB|Upload no pool,ms|Upload existing pool,ms|Download no pool,ms|Download existing pool,ms|
|---|---:|---:|---:|---:|
|1|219.0|239.7|188.9|197.6|
|15|1702.9|1638.1|1916.8|1723.3|
|50|5580.2|5738.2|6416.9|6794.7|

Результаты меняются между проходами; это не стабильная оценка пользовательского Wi-Fi и не обещание ускорения. Уже имеющийся keep-alive не является новой серверной оптимизацией. Подтверждённая по коду цена: 15MiB upload=121RPC, download=62RPC, плюс ACL/registry/manifest у настоящего GAS. Серверные оптимизации/пакетирование без нового измерения и отдельного разрешения НЕ применялись; SHA/ACL не ослаблены.
