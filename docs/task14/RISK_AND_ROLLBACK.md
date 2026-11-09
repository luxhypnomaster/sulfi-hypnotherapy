# №14 — БЕЗОПАСНОСТЬ ДАННЫХ, НЕДОПУСТИМЫЕ УПРОЩЕНИЯ

- Запрет reset/uninstall для проверки и запрет очистки app data. Принятая APK №13 уже стоит у владельца. Сначала проверять install signing continuity; отдельный APK из CI не менять ключи. Не форсировать downgrade схемы.
- Если версия БД выросла: старый архив/backup (созданный локально без раскрытия пользовательских файлов), additive migrations, тесты старые→новые, оговорённый бездеструктивный rollback план. Старые приложения с новой схемой не объявлять гарантированно работоспособными без тестов.
- Локальный SQLite и ФС не транзакционны совместно: commit ordering durable staging→verify→safe move→registry transaction→reconciliation. Ошибка не должна объявлять installed.
- Не хранить файловую систему по пользовательским путям из ZIP. Использовать безопасный sandbox, whitelist, digest, bounded file sizes и профилактику zip traversal/zip bomb. Проверять MIME/extension, не доверять имени из манифеста.
- Личная копия, официальная ревизия, старый SessionRun, editable draft и дневник — разные сущности с разными ownership и сроками удержания.
- Нет основания утверждать, что существующие снимки истории хранят старые аудиобайты. Удерживать ещё доступные refs; ранее удалённые файлы не восстанавливаются автоматически.
- «Offline fixture» ≠ живой облачный каталог и не доказательство доступности официальных материалов. Auth, publishing, payments, server deploy требуют отдельного задания/согласия.
- Доказывать отрицательные сценарии: corruption before commit, duplication, error after moving file before DB, failure on opened app, app kill/restart, missing dependency, insufficient space, unsupported schema.
- Не добавлять ни чужие медданные, ни исходные реальные пользовательские аудиозаписи в публичные screenshots/logs/Drive reports.
- Если риск миграции не удалось снять тестами: не запускать её на данных владельца, отдать частичный результат с точным blocker и планом безопасной следующей работы.
