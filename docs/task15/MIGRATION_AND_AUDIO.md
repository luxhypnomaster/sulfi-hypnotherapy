# РЕВИЗИИ АУДИО / ФИЗИЧЕСКОЕ ХРАНИЛИЩЕ / МИГРАЦИИ

## Исходный известный факт №14
`ContentRevision` append-only table в SQLite v9, `RevisionKey{type,logicalId,revision,digest}` и capsule schema1/databaseSchema9 уже есть. Старые runtime/SessionStep/AudioAsset адресуют преимущественно `audioAssetId`, `AudioAsset` имеет один current `filePath`; UNIQUE(filePath) и legacy removal/GC не гарантируют хранение двух версий звука или dedup across IDs. Это **P1** по `ISSUES_AND_NEXT.md`, не просто косметика.

## Требуемый безопасный результат
- Logical ID аудио отдельно от immutable revision ID и физического `BlobKey(SHA256)`; гарантировать ссылки на все живые byte revisions. Shared Blob физически адресуется digest, но ownership и GC требуют точного учёта по revision/dependency/history/active-run. Не путать криптографический SHA целостности с подписью/доказательством прав.
- Любой runtime/preview/installer/library/history reader, получив exact revision, читает именно её, а не `latest` данного ID. Старые legacy unknownRefs не придумывать; предоставить deterministic best effort/обнаружить невозможность, не привязывать silently к latest.
- Внешний импорт новых байтов с тем же logical ID+новой revision не заменяет старые файлы, старую редакцию модуля и историю. Staging пишется в уникальный временный файл, fsync/verify SHA/size; registry commit transaction, cleanup на restart; статус «успех» лишь после согласованного commit.
- Защитить явное удаление ресурса: если content revision/immutable session/history/private draft ссылаются на blob, physical GC его не уничтожает. Если файлы без ссылок — безопасная reclaim с explicit reference proof; никогда не удалять чужой legacy file по совпадению sha без владения.
- Missing/deleted physical files не восстанавливать магически; отражать честный BLOCKED с описанием и возможностью переимпорта, без ложной «готово».

## Миграционные тесты
1. Populate v9 DB from earlier 14 fixtures (несколько audio, 2 module/definitions, templates, истории с attachments, diary assets, current draft, reader state) + реальные fixture bytes. Snapshot hashes+rows before → migrate→compare persisted data after.
2. Add revision1(A)→revision2(B) of same logical audio; в библиотеке и old/new SessionRun разными exact refs проверяется A и B. Перезапуск приложения не стирает A.
3. Two logically different content IDs reference the same digest bytes: один физический blob и оба readable refs (если строго безопасно); deletion one ID не удаляет other.
4. Stage(cancel), commit(exception), storage low, invalid hash, path traversal, zip bomb budget, duplicate ID with diff digest, conflict existing revision, process crash before SQL/after FS write. Crash harness из отдельного процесса; Android SIGKILL/power loss — отдельная физическая проверка (NOT RUN если не сделана).
5. Idempotent importer + consistent dry-run: missingBytes vs staging overhead vs already-present and metadata-only conflicts. Числа не должны быть ложно точными.
6. Undo/rollback preserve files, schema and history; migration failure never silently resets DB. Проверить старые capsule versions 6–9 и открытие app с принятыми личными данными.

## Stop condition
Если корректная схема не реализуема без тяжелого разрушительного перехода или нет способа доказать retention — НЕ выполнять DROP/RENAME старых таблиц на доверии. Изолировать риск, составить MIGRATION_BLOCKER с schema diff, fixtures, оценкой воздействия и альтернативами. Допустимый PARTIAL честно блокирует работу remote provider с конфликтующими immutable revision assets, но не должен блокировать независимые UI/dairy задачи.
