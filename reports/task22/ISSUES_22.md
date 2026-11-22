# Остаток и ограничения №22

Кодовая точка `a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde`; ветка `feat/task22-server-ratings-admin`, base PR52 `40b7c59e67921f456c3c5a4e943bd40f7232f336` → PR51 `a7c29a7b478b6c3b001d70d3158b4a65d57b3c50`. PR51/52 OPEN DRAFT, не merged. main `b88637a105b2182c7b836311ebb3de7ad037b08f` не менялся. Draft PR22: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/54.

| ID | Факт | Статус/следующий безопасный шаг |
|---|---|---|
|LIVE22|Node/SQLite candidate не подключён к production GAS6; полного live backup/readback/restore нет|BLOCKED_LIVE. Не переносить Node в GAS. Закрыть точные adapter/source/backup/rollback гейты, без нового сервера по умолчанию|
|IAM22|Google bridge проверен controlled verifier, настоящая Google-пара не использовалась; legacy endpoint ACL не мигрировали|PARTIAL. Нужен staged verified integration, не email auto-link/реальный перенос аккаунтов|
|REV22|Сохранённые revision refs/epochs/forks/tombstones и update planning есть; official module→program automatic rematerialization/audio-revision apply нет|PARTIAL. Реализовать на копиях immutable version bytes прежде настоящих данных|
|TAX22|Category create/rename/parent/archive+case duplicate guard и batch metadata есть; merge/reclassification complete workflow нет|PARTIAL. Сначала plan/preview/CAS/redirect without deletion и regression|
|BACKUP22|Candidate полный SQL/media восстановлен; destination interface synthetic; stream больших video и production ScriptProperties не доказаны|PARTIAL/BLOCKED_LIVE. Полный private scoped backup и isolated production-shaped restore до deploy|
|ADMIN22|7 summary/routes реальны; backup schedule/restore/settings, role-definition editor и полный rating revision/moderation dashboard не завершены|PARTIAL, без пустых «успешно» действий|
|POLICY22|Typed versioned policy работает, production weights не выбраны; activation≤1000targets|OPEN methodology + PARTIAL scaling. Добавить staged batching до большой production выборки; public NOT_CALIBRATED сохранять|
|COURSE22|Exact refs/readiness/hash/cursor+existing installer/engine есть; утверждённой Rubedo SVG/bitmap нет|PARTIAL. Не изобретать новый художественный знак; сейчас4цветных текстовых состояния|
|NATIVE22|APK/Gradle/эмуляторы/телефоны прямо отложены владельцем|DEFERRED_BY_OWNER, не BLOCKED_ENV и не ложный physical PASS|
|CI22|Предыдущий hosted runner billing0steps, не новая регрессия|NOT_RUN №22. Не меняли billing/ACL/workflows; локальные logs отдельно|
|ENV22|Перезапуск очистил временный /dev/shm после f8ba3bd|RESOLVED_FOR_CANDIDATE. Источник восстановлен с сохранённого Git, reconstructed tests заново PASS; старые потерянные логи не counted|

Ни production write, ни OAuth/ACL/signing change, ни merge/deletion/GC не было. Независимые tracks продолжались при live blocker. Внешний digest архива наблюдаемый, не owner-pinned. Папка отчётов наследует anyone:writer: SHA подтверждает момент readback, не вечную неизменяемость. Не загружать туда private source/credentials/DB/APK.

Fresh GET health200 не снимает LIVE22/IAM22/backup gate. Fresh Script metadata shared=true при only-owner listed — PRIVATE_ACL_UNCONFIRMED, не объявление публичной утечки. Требуется authoritative readback перед live write; продолжающийся локальный код и доставка отчётов не блокировались. Итоговая ограниченность интерфейса не маскируется; конкретные G4/G5 gaps остаются PARTIAL.
