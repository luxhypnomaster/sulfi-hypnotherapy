# №16-Б — дополнения к прежним 147 критериям

Дата: 12.11.2026. Ветка: `fix/task16b-auth-transfer-publication`. Кандидат приложения: `012f7f69b7ad99c0d44f2a442d9649aa1481117e`. Draft PR: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45 . Продолжение №16/16-А, не №17.

Исходная матрица docs/task16/ACCEPTANCE_MATRIX.md и исходные отчёты №16/16-А сохранены без изменения. Snapshot reports/task16a/continuation24/ACCEPTANCE_CURRENT_24.json (99 PASS / 46 PARTIAL / 1 BLOCKED / 1 NOT_RUN) — историческая оценка, её числа не переобъявляются итогом №16-Б.

| Исходные критерии №16 | Новое фактическое доказательство | Что ещё нельзя закрыть |
|---|---|---|
| AUTH-06/07/09 | Новый пакет владельца подтверждает initial MASTER/CLIENT и publish/deny на двух телефонах; read-only runtime подтверждает distinctAccounts/server role check | Стабильность нового APK25 refresh и критический полный путь не проверены людьми |
| AUTH-08/13/14/15/16 | RSA/claim/role/ACL negative regressions остаются; owner-bound retry/cache; токены только RAM | Новые candidate server diagnostics не deployed |
| BASE-05 | Совпадение package/cert и additive/no schema change; отдельная synthetic emulator update проверка описана в EMULATOR_16B | Реальная база владельца не изымалась и не подвергалась миграции |
| CAT-02/03/04/06/08/09 | Сохранение metadata/cover, независимые catalog/announce действия, exact closure/receipt и reuse без дублирования | Реальная витрина/объявление Элмана и install вторым телефоном |
| Медиа / синхронизация / client install | Контролируемый потерянный ответ, authoritative offset, SHA, pause/restart, отдельные bytes/verify/commit | Physical radio/mobile/network switch и offline звук всех трёх треков |

Итог: №16 остаётся незакрытым до конкретной owner acceptance. Новые 80 строк №16-Б находятся отдельно в ACCEPTANCE_16B.csv; CODE/EMULATOR/LIVE/OWNER уровни разделены. Номера №17 и нового сервера не создавались.
