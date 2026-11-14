# №17 — безопасность

Google SDK выдаёт краткоживущий ID token; существующий сервер проверяет подпись, issuer, audience, expiry, sub и роль на защищённых операциях. Email и локальный режим не дают MASTER. Публичный Web client ID сохранён; OAuth registrations/scopes/Drive ACL не изменялись. Новый Apps Script и новый каталог/очередь не создавались.

Owner scope/hash вычисляется из server-verified subject и endpoint прежним алгоритмом. Queue guard проверяет owner и generation; logout сохраняет opt-out до SDK signout и запрещает silent восстановление. Старый async login не может включить завершённую сессию. Same-owner новый token не меняет owner. Другой owner не читает/не отправляет прежние задачи. Hint хранит только scope hash и последнюю локальную роль для offline read; он не является credential и не даёт серверных полномочий.

Токены остаются в памяти/штатном SDK, не сохраняются в SQLite, ZIP, trace или отчётах. Новый локальный runnerEpoch хранит намерение worker, не Google identity. Debug trace opt-in, RAM200/20мин, safe codes и ownerEqual; export не содержит task IDs, email/sub, URLs, тела запросов или медиа. Clipboard заполняется только явным действием пользователя.

HTTPS allowlist и GAS redirect guard не ослаблялись, bearer не переносится в произвольный redirect или URL. 401/403, network и data validation разделены; нет бесконечных retry. Потеря ответа commit требует GET authoritative state и replay прежнего requestId. Cancel не выполняет withdrawal и не удаляет локальные оригиналы.

Каталог public/private использует существующий серверный ACL. Дневниковый анонс не может скрыто опубликовать материал. ContentLink указывает exact typed logical ID/revision/digest; обычный авторский текст не превращается в CTA. CLIENT publish denied проверяется controlled серверными тестами; реальный второй Google-аккаунт NOT_RUN.

Workflow Task17 использует signing secrets только в доверенной ветке при workflow_dispatch. CLASPRC_JSON не передаётся feature-коду, PR/fork, эмулятору или reports upload. Main/live GAS/OAuth/ACL/ключи/приватность GitHub не менялись. Candidate Diary.js diff требует отдельного approval; ранее накопленные GoogleJwt.js/Router.js не должны попасть в deployment автоматически.


## Доверенные CI и узкий серверный инструмент

Native jobs получают contents:write только на ручном запуске доверенной ветки: GitHub требует это для чтения baseline assets из PRIVATE draft. Ни репозиторий, ни Drive не открываются. Emulator не получает CLASPRC_JSON или signing key; сборочный job удаляет свою временную копию ключа после проверки. Cached delivery не подписывает и не перестраивает APK;9отрицательных тестов проверяют запрет выдачи при отсутствующем native lane/непроверенном runtime/публичном repo или release/overwrite assets.

Подготовленный серверный инструмент состоит ровно из workflow и двух JS-файлов scripts/task17. В main их пока нет. Он manual-only/main-only/defaultOFF; репозиторный CLASPRC_JSON передаётся только после8controlled тестов и установки pinned clasp. Перед push проверяются immutable version6, неизменённый HEAD,20JS+vendor SHA,23file manifest, existing Script/deployment/owner, execution identity/access. Меняется только Diary. InitialConfig/manifest/private config сохраняются. Весь feature server с накопленными GoogleJwt/Router изменениями не развёртывается. При неизвестном исходе STOP→readback, не blind repeat. Никаких Google API/deploy из этого инструмента пока не было.

Разрешение на server apply и ограниченный rollback6 запрошено отдельно по п.05 ТЗ. По умолчанию развёртывание запрещено; отсутствие ответа не является согласием. Никакие приватные credentials не предлагается присылать в чат.
