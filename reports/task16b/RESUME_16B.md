# №16-Б — точка продолжения

Приложение и кандидат backend зафиксированы в 012f7f69b7ad99c0d44f2a442d9649aa1481117e, ветка fix/task16b-auth-transfer-publication, worktree /dev/shm/sulfi16b, draft PR45 к feat/task16-alchemist-full-server. Main, GAS6, signing и APK24 не менять. Не делать №17. Старые отчёты не перезаписывать.

G0–G4 реализованы; окончательный exact-source checks run43162781960 PASS (433 tests). APK build43163688437 attempt2 выполняется: первый attempt упал на внешнем Kotlin POM resolution,тот же POM доступен и повтор запрошен без смены source. Автономная цепочка /tmp/task16b_pipeline.py (state /tmp/task16b-pipeline.json, exec session55547, retry runner /tmp/task16b_pipeline_retry.py) дожидается checks, запускает alchemist-qa-pair.yml из ТОЙ ЖЕ ветки, затем checks.yml с emulator_qa=true. Скрипт останавливается на настоящем failure; не подменяет статусы успехом. Для GitHub CLI использовать env -u GH_TOKEN, не выводить credentials.

Пока pipeline работает, не менять source HEAD: private draft и emulator gate требуют совпадения source SHA. После signed pair delivery скачать/проверить обе APK и certificate/hash/package/version через metadata и байты. APK хранить только GitHub private draft, не Google Drive. APK24 assets736432720/736433144 сохранить.

Финальные отчёты — reports/task16b. Генератор /tmp/task16b_reports.py создаёт уже подготовленные тексты и 80-row matrix (33 PASS/45 PARTIAL/2 BLOCKED до финальных evidence); после его повторного запуска вручную сохранять дополнения actual proof, не стирать Drive links. Новые документальные REL-01/02/07/09 можно уточнить только по фактическим проверкам. Физический Wi-Fi/mobile и owner offline playback остаются BLOCKED/NOT_RUN.

На Drive в папке1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z уже размещён CHECKPOINT_16B.md (id1iNNzjoNXjEVD_7pjq0XSn6rrlJb3W3DG) и часть суффиксных отчётов/Flutter PNG. Ни старые отчёты, ни исходные16/16-А не удалять. Список новых upload IDs хранится tools functions store task16bUploads; перед повторной загрузкой по возможности использовать ID update только для собственных16B файлов, избегать дублей.

Завершить: actual TESTS/ISSUES/APK_INFO/RESULT, emulator evidence, финальная матрица, SHA256SUMS, Drive readback, отчётный checkpoint-коммит и обновление PR. Перед отчётным commit сначала запустить emulator от source012f, иначе exact-source draft validation не совпадёт. Новые JWT/trace серверные изменения НЕ DEPLOY; нужен отдельный owner approval на точную ревизию. Попросить владельца только испытать реально доступные APK и настоящий Google/master→каталог→дневник→client→offline путь.
