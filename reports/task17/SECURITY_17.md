# №17 — безопасность

Google SDK выдаёт краткоживущий ID token; существующий сервер проверяет подпись, issuer, audience, expiry, sub и роль на защищённых операциях. Email и локальный режим не дают MASTER. Публичный Web client ID сохранён; OAuth registrations/scopes/Drive ACL не изменялись. Новый Apps Script и новый каталог/очередь не создавались.

Owner scope/hash вычисляется из server-verified subject и endpoint прежним алгоритмом. Queue guard проверяет owner и generation; logout сохраняет opt-out до SDK signout и запрещает silent восстановление. Старый async login не может включить завершённую сессию. Same-owner новый token не меняет owner. Другой owner не читает/не отправляет прежние задачи. Hint хранит только scope hash и последнюю локальную роль для offline read; он не является credential и не даёт серверных полномочий.

Токены остаются в памяти/штатном SDK, не сохраняются в SQLite, ZIP, trace или отчётах. Новый локальный runnerEpoch хранит намерение worker, не Google identity. Debug trace opt-in, RAM200/20мин, safe codes и ownerEqual; export не содержит task IDs, email/sub, URLs, тела запросов или медиа. Clipboard заполняется только явным действием пользователя.

HTTPS allowlist и GAS redirect guard не ослаблялись, bearer не переносится в произвольный redirect или URL. 401/403, network и data validation разделены; нет бесконечных retry. Потеря ответа commit требует GET authoritative state и replay прежнего requestId. Cancel не выполняет withdrawal и не удаляет локальные оригиналы.

Каталог public/private использует существующий серверный ACL. Дневниковый анонс не может скрыто опубликовать материал. ContentLink указывает exact typed logical ID/revision/digest; обычный авторский текст не превращается в CTA. CLIENT publish denied проверяется controlled серверными тестами; реальный второй Google-аккаунт NOT_RUN.

Workflow Task17 использует signing secrets только в доверенной ветке при workflow_dispatch. CLASPRC_JSON не передаётся feature-коду, PR/fork, эмулятору или reports upload. Main/live GAS/OAuth/ACL/ключи/приватность GitHub не менялись. Candidate Diary.js diff требует отдельного approval; ранее накопленные GoogleJwt.js/Router.js не должны попасть в deployment автоматически.
