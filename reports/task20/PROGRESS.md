# №20 — checkpoint 0, 2026-11-21

Ветка feat/task20-catalog-vitrine от dca81961146747adc4a3f06107012df429ed747a (PR50 draft). Архив и все семь manifest записей PASS. PR48/49/50 не объединены; их код сохранён по ancestry.

BASELINE → HEAD-SNAPSHOT → CLIENT-SYNC → DIARY-LOCAL-READ → DIARY-HOME → MASTER-VITRINE → regression/evidence.

GAS6, OAuth, ACL, main, signing, данные и APK28 не менять. Auth19 OFF. Live HEAD/admin API отсутствует: только изолированный адаптер и честный BLOCKED live.

В работе: аудит классов/SQLite/SDD и адресные тесты. Android/CI/owner доказательства отдельно.

## Checkpoint 1
HEAD/snapshot изолированный Node adapter: light read, immutable prepare/readback, atomic commit boundary, scoped ACL, idempotency, CAS, config1..60. Не подключён к Router. SQLite lastGood sync использует существующие download tasks;6intents/1job/equalHEAD/no-full-fetch, scope/corrupt/atomic tests PASS. Local-only read namespace additive; legacy completed cycles перенесены без удаления, старый режим проверяется явно. Targeted Flutter26 PASS. HOME/settings код добавлен; widget/security/regression проверки в работе.
