# Изменения №25

Source `737ea741636e9abe7c20353d9d5b8301cf44a5bb`; draft PR57 от PR56. Слияний/cherry-pick/rebase/force-push не было: подтверждённая цепочка уже содержит все изменения №20–24.

|Область|До|После|Влияние/откат|
|---|---|---|---|
|test/task25_integration_test.dart|Нет одной связанной проверки program install→author change→offline engine→cold DB/queue|3 новых содержательных integration tests с реальными SQLite/files/loopback candidate server и controlled audio|Только test; без пользовательских данных/переименования ID|
|scripts/task25/source_gate.py + test_source_gate.py|Исторические guards ограничены своими этапами|Read-only335 runtime/31 native hash pins + ancestry, отказ при drift/missing/symlink/path escape;4tests|Не выполняет native/deploy/dispatch, pins не пересоздаёт|
|docs/task25|Нет сохранённого официального входа|11 raw файлов пакета, CRC/10manifest hashes/outerSHA|Исторические №16–24 сохранены|
|reports/task25|Нет текущей интеграционной матрицы|55критериев, SHA/CI/Android/signing audit, rawlogs, конкретные blockers и план|Только документация/санитизированные доказательства|
|README/BACKLOG|Индекс до №24|Ссылка на №25 и открытые native gates|Не продуктовый редизайн|
|lib/android/third_party/server/.github/pubspec.lock/yaml|Код PR56|**Побайтово без изменений**|335 protected +31 pins PASS; прежняя версия/IDs/signature config|

Нет подтверждённого нового runtime дефекта, поэтому ни фиктивного RED, ни исправления «на всякий случай». Новые tests были GREEN на существующей интегрированной реализации. Все прежние RED→GREEN regressions заново GREEN. Ни второй каталог/очередь/сервер, ни schema migration, ни новые зависимости/эстетика не добавлены.

Различия с main содержат накопленный независимый stack, это не разрешение перенести его целиком. Изменения №22 изолированы/defaultOFF, №23 data guards/owner boundaries сохранены, №24 routing untouched. SOURCE_TREES/PROTECTED/DEPENDENCY_GRAPH объясняют ancestry и docs-only tails. Новый runtime patch не требуется; для rollback этого этапа достаточно не принимать тестовые/документальные изменения PR57. Откат приложения/GAS/данных не выполняется.
