# №16-Г — последняя контрольная точка

Ветка `fix/task16g-stabilize-programs`, draft PR47, база PR46b0cb53f. Не начинать заново G0–G3. Main/PR45/46/GAS6/signing/Google ACL/старые APK неизменны; старые тестовые объекты владельца восстанавливать не требуется. Прежний root cause №16-В UNKNOWN.

## Код и готовые проверки

Полный runtime/test source11909895da4f2967b77f12a8b8da98ff50b370d5: actual verify job43350711471 SUCCESS,448 Flutter/3CLIENT/46+24Node/analyze/format/contracts. Все7executable/test Git trees после этого неизменны; повторять полный suite без нового runtime/test изменения не нужно. G1 Android exact callback run43347643988 PASS148sec. G1 derivative-copy preflight11cases, hotjournal/WAL, no startup orphanGC; schema9/paths/template IDs untouched. G2 production Dart→JS program/module3track/diary text update/selective CLIENT install controlledPASS; actualGoogle/Drive NOT_RUN. G3 user labels Программы, legacy wire/table/capsule unchanged.

## Сейчас выполняется: CI43362294034

Native-only source0e0c4b8171cece30620feae85796379bde01d901; sourceAPKproducer9b94f24f3e5302c20a96dce5a2e7bdc074c21a1c. Ровно эта пара хранится в private Actions cache keytask16g-quarantine-built-pair-9b94f24f3e5302c20a96dce5a2e7bdc074c21a1c, pathRUNNER_TEMP/task16g-apks. Никакого нового build/signing/секретов. Не запускать второй параллельный CI. Цепочка: UI-created25→native update26→cold/referenced media SHA→CLIENT labels→actual app corruption/missingDB fail-closed→conditional private draft. До PASS всех gates кандидат не выдавать.

Предыдущие43359522821/43360904610 остановились до update26.3разных WAV черезUI PASS; module save не был подтверждён. Снимок попытки2 показывает Gboard закрывающий Save при enabled Flutter semantics: координатный tap попадал в клавиатуру. Новое исправление драйвера наблюдает mInputShown, скрывает клавиатуру и блокирует Save если нельзя подтвердить её отсутствие. Это подтверждённый дефект драйвера, не доказанный app-save bug. JSON/SHA/screens обоих attempts сохранены отдельно. Disk/SDK ранние неудачи и3идентичные внутренние buildpairs — CODEX_EFFICIENCY/BUILD_ATTEMPTS, не ownerdata tests. Не повторять идентичную неудачу без новой конкретной гипотезы.

## Завершение

После завершения текущего CI: `gh run view RUN --log > /dev/shm/private.log 2>&1`, никакого вывода signedURLs. `python3 scripts/task16g/read_native_log.py LOG reports/task16g` проверяет SHA каждого boundedsynthetic JSON/PNG/XML. Из одиночной FAULT_APP_16G= строки извлечь actualfaultreceipt. Получить CIjobs через gh JSON. Если safety gate не пройден — RESULT BLOCKED, noAPK, но закончить отчёты и доставку. Если release выпущен gates-скриптом — скачать обеAPK сGitHub, проверитьSHA/size/package/cert/compiledendpointOAuth/NativeGuard иточныйproducer; receiptAPK_READBACK_16G.json. Не GoogleDriveAPK.

Обновить RESULT/TESTS/ISSUES/EFF/OWNERQA/CHANGES и33строки ACCEPTANCE_16G.csv черезreport_acceptance.py. Физические Google/Drive/owner2phone/mic/heardSoundNOT_RUN; не считать пустую diaryAuthor таблицу2drafts. Отдельные remaining criteria PARTIAL/BLOCKED.

Driveexistingfolder1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z. Уже созданы3ownfileIDs вDRIVE_UPLOADS_16G.json (CHANGES/ISSUES/OWNERQA), их обновлять; остальные4отчёта создать. Только7своих16G, оригинальные16B/16V не трогать. Прочитатьmetadata+скачатьrawвсех7,сравнитьSHA/parent, сохранитьDRIVE_READBACK_16G.json. ПослеdeliveryобновитьREL06PASSиещёразmatrixreadback. Финальныйcheckpointpush иPR47bodyчерезRESTPATCH (ghpr editстарыйGraphQLbroken). GHcmds:env-uGH_TOKEN;pushcredentialhelpergh. Не merge/deploy/publicrelease/remoteartifactdelete/ownerphoneactions/new17.
