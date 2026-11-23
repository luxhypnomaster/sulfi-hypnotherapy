# №25 — подписанная пара29, приёмка PARTIAL

Состояние 2026-11-23. Исходный отчёт сохранён в `history_before_candidate29/`, материалы Google Drive не удалялись.

Код приложений: **737ea741636e9abe7c20353d9d5b8301cf44a5bb**. Ветка `feat/task25-integration-native-gates`, [draft PR57](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57), база — проверенный PR56d0a6d9a6. PR51/52/54/55/56/57 остаются OPEN DRAFT UNMERGED. Изменений runtime335/native31 после проверенного исходника нет. Новые commits — инструменты QA и отчёты.

|Область|Фактический результат|
|---|---|
|INTEGRATION_READY|PASS_SOURCE_LOCAL:574Flutter PASS/2SKIP,114Node,53Python исходной интеграции; analyzer/format/pins PASS|
|Сборка MASTER/CLIENT29|PASS_BINARY: обе реально собраны и подписаны существующим ключом, run45103325755 SUCCESS|
|Независимая проверка бинарников|PASS: исходник, SHA, размер, cert, applicationId, version29, ABI, SDK, права; повторный readback после перезапуска среды|
|NATIVE_CANDIDATE_CLIENT|API34 CONTROLLED PASS15, включая normal install-r28→29, точные строки/медиа, cold restart и native playback|
|NATIVE_CANDIDATE_MASTER|BLOCKED: QEMU SIGSEGV на старой28 до установки29; это не доказанный дефект миграции|
|Оба API36|NOT_RUN: обязательный API34 gate не пройден; критерии не ослаблены|
|SERVER_PROD_READY|false для новых функций21/22; GAS6 сохранён, новые флаги OFF|
|OWNER_DEVICE / REAL_GOOGLE|NOT_RUN, телефоны не затронуты; реальный установленный versionCode UNKNOWN|
|Выдача пары для телефона|BLOCKED. APK находятся в quarantine; установка владельцу не рекомендуется|

[Реальная сборка](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45103325755), [native run4](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45157723278). Существующий cert `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`, оба APK `0.4.21+29`, min24/target36. Подробности — APK_INFO/APK_READBACK и NATIVE_UPGRADE.

Новый узкий PR67 добавил безопасное чтение только кода исключения/исполняемого модуля аварии и режим MASTER-only без выдачи APK; production/signing не затронуты. Диагностический run45161085603 проверяется отдельно. Его успех сам по себе не является четырьмя native PASS или разрешением на выдачу.

Без merge всего стека, production deploy, нового ключа, изменения OAuth/ACL или действий с личными данными. Исторический owner24→25 остаётся UNKNOWN. Ограничения22/23 перечислены в ISSUES.
