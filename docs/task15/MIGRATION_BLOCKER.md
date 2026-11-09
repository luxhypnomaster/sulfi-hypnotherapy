# G3 — PARTIAL / MIGRATION_BLOCKER

Полная миграция exact audio refs отложена по stop condition PHASE_GATES_AND_BUDGET.md. Schema9 audio_assets остаётся одним текущим объектом на logical ID; не добавлены фиктивные CAS-таблицы и не изменён утверждённый плеер.

Блокер: SessionEngine разрешает audioAssetId через текущую библиотеку в трёх местах; SessionController replayIssues/snapshotForStart проверяет текущие метаданные, но не находит прежние байты по RevisionKey. LibraryService.fileFor/discard/delete работают с текущим путём. CapsuleService экспортирует один текущий audio_assets row на ID, LocalCatalog отвергает две версии одного ID. Поэтому замена только схемы или resolver оставила бы историю/preview/экспорт с разным значением exact. Нужно согласованно мигрировать все эти readers и ownership/GC с populated fixtures; неполная миграция не применяется.

Воспроизводимый fixture: test/task15_revision_boundary_test.dart: история содержит A/v1; кандидат B/v2 имеет тот же ID и другой SHA. save B безопасно отвергается существующим guard. Это доказательство BLOCKED REV-02/03/04, не PASS coexistence. Не разрешать live deployment.

Исправлена отдельная потеря файла: initialize удалял orphan asset_* даже при сохранённой track revision. Теперь старые SHA из content_revisions и снимков удерживают реальные байты; при неизвестном SHA очистка консервативна. Это не полный ownership GC: legacy discard/delete ещё требуют миграции. Cross-ID физическая дедупликация НЕ заявлена.

Dry-run теперь различает missing content hashes, фактические legacy записи, staging и 16 MiB reserve. Metadata-only не считается новыми байтами; свободное место проверяется повторно перед commit. Физические дубли всё ещё учитываются как записи.

Проверки: g3-before.log — оба регресса воспроизведены до исправления; g3-safe-tests.log — 34 PASS, включая прежние capsules. g3-crash-tests.log — 2 PASS: настоящий SIGKILL отдельного flutter_tester до/после commit, SQLite reopen, reconcile и повтор. Это не моделирование выключения питания и не физический Android.

Rollback: нет изменения audio schema, путей или пользовательских строк. Для отката UI/preflight/retention вернуть G3 code commit; сохранённые bytes не удалять. G4/G5 независимы и продолжаются; SERVER_READY: NO.
