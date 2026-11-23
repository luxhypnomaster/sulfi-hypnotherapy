# Изменения №25 — кандидат29 и инструменты QA

Код приложений остаётся737ea741636e9abe7c20353d9d5b8301cf44a5bb; результаты21–24 сохранены в зависимой цепочке PR. Нового воспроизводимого runtime-дефекта не установлено, изменений модели/путей/SQLite/schema/API/ролей0.

|Область|Изменение|Проверка|
|---|---|---|
|Trusted main operations|Узкие PR58–67; только signing inspect/build/verify helpers/workflows, через обычные PR на protected main|Exact base/head/file hash readback, branch-rule owner readback reused; закрытые Admin API не повторялись|
|Build/sign|Из frozen source отдельные unsigned MASTER/CLIENT, debug signer отключён проверенным overlay; отдельная fresh-main job использует прежний key|Actual run45103325755, обе подписи и binary readback|
|QA transport|Provider SHA+ZIP CRC+точный состав; baseline28 как данные, независимо проверенные cert/IDs/версии|Signed pair independently restored после environment restart; без повторной сборки|
|Native harness|Strict generated31pins после locked pubget, официальный Flutter tag+exactSHA; свежие AX snapshots, existing reader mode, реальный KVM capability; host exit monitor и physical720/density280|Python70PASS/actionlint; actual CLIENT34native15PASS; MASTER crash честноBLOCKED|
|Crash metadata|Новый bounded parser только exception/IP→module relative offset, без memory/stack streams/raw dumps; MASTER-only scope не может запускать delivery|8synthetic format tests входят в70; diagnostic run отдельно, не physicalPASS|
|Отчёты|55criterion matrix обновлена, binary identity отделена от native/owner/live; исходные отчёты сохранены|History directory, Git commits, новые dated supplements в той же Drive folder|

Native/profile/diagnostic исправления не ослабляют P0 assertions. Приложение APK29 не менялось и не переподписывалось после успешной сборки. Production GAS6, OAuth/ACL, server code, действующие публикации/данные, старыеAPK и ключ подписи сохранены. Live-only dual-apk workflow и его server gate byte-identical, не запускались/не обходились. Offline QA — отдельный разрешённый защищённый путь; новые server21/22/Auth19 флагиOFF.

Исторические RED→GREEN и неудачные операции с обоснованием — `candidate29/*RED*`, `*GREEN*`, native_attempt*/ и CODEX_EFFICIENCY_25.md. Тесты парсера не объявляются обнаружением причины в настоящем dump.
