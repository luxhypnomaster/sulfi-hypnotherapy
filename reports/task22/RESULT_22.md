# Результат №22 v1.7 — PARTIAL, проверяемый кодовый кандидат

Кодовая точка `a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde`; ветка `feat/task22-server-ratings-admin`, base PR52 `40b7c59e67921f456c3c5a4e943bd40f7232f336` → PR51 `a7c29a7b478b6c3b001d70d3158b4a65d57b3c50`. PR51/52 OPEN DRAFT, не merged. main `b88637a105b2182c7b836311ebb3de7ad037b08f` не менялся. Draft PR22: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/54.

Архив 31966 B, наблюдаемый SHA-256 `a967a71dd370093444d506ca32f56a5542a0ee7243a2dee2ddc3f34bec92a13d`. 13 файлов прочитаны; CRC,12 manifest hashes/sizes и идентичность docs PASS. Внешний независимо закреплённый SHA владелец не предоставлял; это отмечено, не подменено вымышленной проверкой.

## Реализовано
- Настоящие SQLite server jobs/lease/fencing/receipt/idempotency/CAS, ограниченные retries, redacted incidents. Это серверная очередь кандидата, не вторая Android-очередь.
- AES256-GCM backup полного disposable server store и всех требуемых медиа: manifest, independent readback и действительное изолированное восстановление SQLite/файлов. Upload/integrity и restore verification — разные статусы.
- Provider-neutral UID из verified issuer/sub, без email auto-link; OWNER/lead ADMIN/ordinary ADMIN/EDITOR/AUTHOR/CLIENT, server-side ACL. Добавлен bridge к существующему Google verifier; live provider/ACL не менялся.
- F031–034: локальный добровольный отзыв, отдельный consent/revoke, точное исполнение и exposure, неизменные rating epochs; отдельные consumerDirect/professionalDirect и weighted=null/NOT_CALIBRATED. Чистый заменяемый calculator/registry/typed policy, draft/preview/validate/activate/rollback и audit.
- Независимый ratingsRevision/hash overlay, scoped lastGood, coalesced refresh через существующую queue18; HEAD без нового snapshot при прежней версии.
- Курсы с точными ordered program refs, локальными черновиками, drag/order, server receipt, verified readiness, sequence cursor и frozen execution binding; используются старые installer/engine.
- Семь разделов MASTER, реальные показатели кандидата/unknown quotas, формы ролей, операций и категорий, сохранённые пакетные metadata-правки с предпросмотром/receipt. Статичный Home preview №21 сохранён.

## Что проверено
LOCAL/synthetic STAGING: Flutter 539 PASS / 2 SKIP / 0 FAIL; Node полный прогон79 PASS; старый дневник24 PASS; analyze без замечаний; no-cloud GAS source assembly PASS. Адресные результаты входят в общий итог и не складываются с ним. Фиктивные credentials тестового loopback не являются Google-входом.

LIVE: **READONLY_HEALTH PASS; authenticated API BLOCKED / NOT_RUN**. Runtime22 — Node/SQLite sandbox поверх runtime21, production GAS binding отсутствует. Свежий administrative readback GAS6 и полный действующий private Drive/ScriptProperties backup/restore не получены. Существующий endpoint GET health вернул200/JSON; это не административное чтение версии и не проверка полного API. Никакого deploy или переключения флагов не сделано.

NATIVE/APK/OWNER phones: **DEFERRED_BY_OWNER** по v1.7. APK, bundle, Gradle, эмуляторы и подпись в №22 не запускались. Это не environment failure. Старые APK/данные сохранены.

## Незавершённое
Полный live adapter/backup gate; автоматическая rematerialization official module→program и безопасное применение аудиоревизий; merge/reclassification категорий; backup schedule/settings/restore UI; полный revision breakdown/moderation dashboard; утверждённая Rubedo-графика. Production weights/полномочие lead-admin publish/конечный rating UX остаются OPEN, чисел не назначали.

Все58 критериев имеют отдельный статус в ACCEPTANCE_22. №22 не объявляется FULL PASS. Следующий безопасный шаг — review Draft PR и продолжение указанных кодовых gaps; live-внедрение только после подтверждённых source/backup/restore/rollback гейтов. №23 автоматически не начинался.

Отчёты: https://drive.google.com/drive/folders/1xYICmox_IY9Z5CRSIqjPJFyGuN4nk9fB. В папке только очищенные документы/logs/screens, без исходников, баз, ключей или APK.
