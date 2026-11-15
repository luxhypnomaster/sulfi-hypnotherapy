# №18 — PARTIAL, выдача APK28 пока заблокирована native gate

Ветка feat/task18-native-background-transfer, draft PR49 (база PR48 не merged). Текущий исходник подписанной пары:59c3667a28357767533b25e92661b87d081d7227. main b88637a, GAS6, OAuth, Drive ACL, подпись, исходные27 и данные владельца сохранены.

Реализованы независимый Android headless executor (UIDT34+, dataSync FGS24–33, persisted bounded recovery), существующая durable очередь обоих направлений, owner/role/epoch lease, проверяемые chunk/whole SHA/receipts, bounded retries, системные действия и метрики. Дополнительные подтверждённые исправления: non-owning watchdog не останавливает основной запуск; obsolete WAITING_NETWORK уведомление снимается при новом executor.

**Проверено:**

- Verify43704911303/19c3345:485 Flutter/3CLIENT/47+24Node, contract13schema/4fixtures/10negative, format/analyze PASS. Строгий source gate подтверждает неизменность production lib/test/server/assets/dependencies; новые native/test-only файлы проходят отдельные compile/analyze/Android gates.
- Native API34 sourcecea4897: MASTER background/pause/explicit cold Resume/unique program commit PASS; CLIENT background bytes и WAITING_NETWORK→automatic OS recovery подтверждены. Общие probes10/11 FAIL позже на Cancel observer; не считать install/offline на этом исходнике завершённым. Исторический7-case install/offline AudioTrack PASS относится к app4ab0588. Все это CONTROLLED, без Google/GAS.
- Run43708103115/sourcecea4897: нормальное обновление MASTER14/CLIENT12 UI-created data PASS,3 независимых SHA/cert readback. Эта пара историческая: её заменяет59 из-за исправления stale notification.
- Run43715411268/source59: обе реальные Android SQLite legacy conversion проверки PASS. Старые queued/running безопасно ждут согласия, USER_PAUSED/foreign/unbound не изменены; прежние IDs/request/etag/session/offset сохранены; foreign Resume запрещён. Это controlled native conversion, а не настоящая Google-авторизация.
- Candidate job43715408673/source59 SUCCESS: обе нормальные APK28 собраны и проверены прежним сертификатом, analyzer/JVM task PASS. Новая полная проверка27→28 с дополнительными5 native legacy rows остановилась ДО создания baseline на SystemUI/Launcher ANR; обновление не выполнялось.

**Сейчас выполняются:** full AOSP API34 background/SIGKILL/recovery probe43730572606 (те же fixture59 bytes); normal cached-pair AOSP27→28 safety43730982434. Последний не пересобирает APK/не читает ключ: проверяет реально успешный candidate job и точное совпадение входов/recipe, затем SHA/cert/config. Результаты до завершения не предполагать.

APK source59: MASTER SHA78fb218edc59b2ddf761cda38e6faaf76e6bcea9b5bea6ab6e0b5a995b8b7767; CLIENT SHAe9fa12f7fd5e9a08e55eec163b2f2d1e6eaed2c260e105226429774e4d0ef821. Сертификат0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6. Оригинальный quarantine receipt safeForOwnerInstall=false сохранён; APK_PAIR_18 и ссылка на выдачу ещё не созданы. Actions artifacts фактически BLOCKED_QUOTA; старые artifacts не удаляются, APK28 на Drive без отдельного согласования не загружаются.

Скорость: текущие1/15/50MiB real-loopback TCP измерены в двух режимах, RPC-budget negative PASS; фиксированного ускорения нет. Анонимный LIVE catalog.list ответил200 за4405ms, первая страница содержит1diaryEntry; это не Google-вход и не throughput аудио. Production Diary EMPTY_ENTRY для message-only остаётся отдельным17 blocker без разрешения deploy.

Осталось: завершить текущие gates, затем API33/35/36, проверить фактическую отмену/range/offline/cold process, безопасно выдать проверенную пару. Реальные Google/два телефона/OEM/слышимость и настоящий GAS file throughput NOT_RUN. Папка отчётов: https://drive.google.com/drive/folders/100klr45KcMk0CNx21nYhoPvwMJ8i8xv- (owner-only).
