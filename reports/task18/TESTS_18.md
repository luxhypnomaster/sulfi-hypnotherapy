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
| MASTER27→28 API34 | historical BLOCKED before update, host QEMU SIGSEGV | finalize_de408/master; no owner data, not migration failure |
| MASTER27→28 API35 | 15 PASS | master35_de408/master/NATIVE_UI_UPGRADE_18.json; run43764129343 |
| full background API33 | 10 PASS | full33_de408/probe/NATIVE_PROBE_18.json; run43764132106 |
| full background API35 | 10 PASS | full35_de408/probe/NATIVE_PROBE_18.json; run43764134857 |
| full background API36 | 10 PASS | full36_de408/probe/NATIVE_PROBE_18.json; run43764137702 |
| app JVM /vendor scheduler | SUCCESS | candidate43744944796 :app:testDebugUnitTest and :sqflite_android:testDebugUnitTest,8app tests +wrapper5scheduler invariants; counts from sources, no XML artifact claimed |
| full background API34 | 11 PASS | full34_de408/probe/NATIVE_PROBE_18.json; run43744948169 |
| old27 queue conversion обеих редакций | PASS_CONTROLLED | legacy_de408/probe/NATIVE_LEGACY_QUEUE_18.json; run43764140442 |
| защита выдачи | 9 PASS (8 adversarial + canonical API endpoint) | python3 scripts/task18/test_delivery_gate.py |
| production Google/GAS file E2E / физические телефоны | NOT_RUN | не заменяются synthetic identities |

API34 действительно убивал процесс и наблюдал новое исполнение ОС за6,98sec: прежний request/session/offset/source SHA сохранён. Отдельный watchdog nonownership проверяется принудительным **тестовым** вызовом существующего job; это не метод возобновления cold-process case. Методы и границы не смешиваются.

SQLite causal proof: исходная1-thread и4-thread конфигурации не прошли overlapping-write control; настройки пула/timeout отвергнуты. Новый source overlay дал2COMMIT/rows2/integrityok/errors0, но сам run43739426806 FAIL из-за неверного observer expectation busy0 вместо unchangeddefault2500; сырые receipt не переписаны. SHIPPING app затем прошёл fullAPI35 на предыдущем a894; текущий DE проходит самостоятельные gates. Подробности SQLITE_SCHEDULER_PROOF_18.md.

Нормальный upgrade driver создаёт в APK27 через UI3разныхWAV (включая одинаковые названия),2модуля, положительную паузу настоящим вертикальным жестом, программу/history/current config, MASTER diary draft. Дополнительно вставляет5контролируемых legacy queue rows нативной SQLite под UID только эмулятора; это не замена UI baseline и не база владельца. Далее install-r, точное сравнение IDs/rows/mediaSHA/integrity и cold restart. Подпись/applicationId/schema9 прежние.

Все восстановленные CI-файлы прошли SHA/size/chunk проверку collect_ci_evidence.py. Raw log .log сохраняется принудительно только с ограниченным synthetic output; токены/аккаунты владельца/его записи не собирались. GitHub upload-artifact step может иметь conclusion success из-за continue-on-error, хотя upload реально отказал quota: наличие APK artifact не утверждается.

DELIVERY_GATE_18.json: все6current-source native gates PASS. Фактические API labels дополнительно сверены по emulator root logs api-level и Found systemPath. SOURCE SHA не смешан с59/a894. Normal MASTER frameworkAPI35, CLIENT34; fullprobe33/34/35/36. No Google/OWNER LIVE claim.

Scope уточнение: native notification Cancel реально проверен для CLIENT download; MASTER upload cancel — CODE, не отдельный native PASS. Force Stop использован после явной user pause для cold explicit Resume и после завершения install для offline proof; active-transfer Force Stop/reboot/OEM-policy отдельно NOT_RUN.

Private delivery43765843573 SUCCESS: exact normal cache/source/buildrecipe checks, byte/cert/config scan,9guardtests,6actualnativegates,2newassetuploads+independentredownloadSHA/cert. Readbackold27/draftprivacy/targetunchanged. Failedattempts43765533682/43765701087 werebeforeupload andpreservedinDELIVERY_ATTEMPTS_18.json. No newappbuild/signing/test-gate replay fordelivery. Browserphonecookies/publicdownload nottested orgranted.

Дополнительно обе опубликованные **в закрытом draft** APK скачаны непосредственно в рабочую среду, независимо от CI, и повторно проверены verify_pair.sh: SHA/размер/прежняя подпись/package/version/config/permissions/noProbe PASS. Это binary-readback, не физическая установка и не Google-вход. DELIVERY_READBACK_18.json.
