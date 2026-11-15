# №18 — фактически проведённые проверки

Кандидатный исходник `de408f1cae08fce16069a701d147a0b1064053ba`. CODE, CONTROLLED NATIVE и OWNER LIVE разделены. Старые эксперименты и отрицательные результаты сохранены в PROGRESS.md, Git и именованных evidence directories; они не подставляются в gates текущего исходника.

| Проверка | Фактический результат | Evidence |
|---|---|---|
| Основные Flutter | 489 PASS /0 failures | FULL_VERIFY_DE408_18.json, evidence/FULL_VERIFY_DE408_18.log; run43744944796 verify SUCCESS |
| CLIENT Flutter | 3 PASS | тот же verify |
| Node Alchemist / legacy | 47 /24 PASS | тот же verify |
| format / analyze / contracts | SUCCESS | тот же verify |
| normal signed MASTER+CLIENT28 | candidate18 SUCCESS | QUARANTINE_DE408_18.json; package/version/config/подпись/no probe guards |
| CLIENT27→28 normal package | 13 PASS | finalize_de408/client/NATIVE_UI_UPGRADE_18.json |
| MASTER27→28 API34 | BLOCKED before update, host QEMU SIGSEGV | finalize_de408/master; no owner data, not migration failure |
| full background API34 | 11 PASS | full34_de408/probe/NATIVE_PROBE_18.json; run43744948169 |
| old27 queue conversion обеих редакций | PASS_CONTROLLED | legacy_de408/probe/NATIVE_LEGACY_QUEUE_18.json; run43764140442 |
| защита выдачи | 8 PASS | python3 scripts/task18/test_delivery_gate.py |
| production Google/GAS file E2E / физические телефоны | NOT_RUN | не заменяются synthetic identities |

API34 действительно убивал процесс и наблюдал новое исполнение ОС за6,98sec: прежний request/session/offset/source SHA сохранён. Отдельный watchdog nonownership проверяется принудительным **тестовым** вызовом существующего job; это не метод возобновления cold-process case. Методы и границы не смешиваются.

SQLite causal proof: исходная1-thread и4-thread конфигурации не прошли overlapping-write control; настройки пула/timeout отвергнуты. Новый source overlay дал2COMMIT/rows2/integrityok/errors0, но сам run43739426806 FAIL из-за неверного observer expectation busy0 вместо unchangeddefault2500; сырые receipt не переписаны. SHIPPING app затем прошёл fullAPI35 на предыдущем a894; текущий DE проходит самостоятельные gates. Подробности SQLITE_SCHEDULER_PROOF_18.md.

Нормальный upgrade driver создаёт в APK27 через UI3разныхWAV (включая одинаковые названия),2модуля, положительную паузу настоящим вертикальным жестом, программу/history/current config, MASTER diary draft. Дополнительно вставляет5контролируемых legacy queue rows нативной SQLite под UID только эмулятора; это не замена UI baseline и не база владельца. Далее install-r, точное сравнение IDs/rows/mediaSHA/integrity и cold restart. Подпись/applicationId/schema9 прежние.

Все восстановленные CI-файлы прошли SHA/size/chunk проверку collect_ci_evidence.py. Raw log .log сохраняется принудительно только с ограниченным synthetic output; токены/аккаунты владельца/его записи не собирались. GitHub upload-artifact step может иметь conclusion success из-за continue-on-error, хотя upload реально отказал quota: наличие APK artifact не утверждается.
