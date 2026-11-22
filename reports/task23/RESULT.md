# Задание №23 v1.1 — PARTIAL

P0 локальная сохранность и безопасные капсулы реализованы и проверены на синтетических данных. **Новых APK/AAB, Gradle/native build, Actions build, emulator и физической приёмки не было: DEFERRED_BY_OWNER.** Merge, production deploy, изменение GAS/OAuth/ACL/signing/main и данных владельца не выполнялись.

- Draft PR: **https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/55**.
- Отчёты/доказательства: **https://drive.google.com/drive/folders/1PTajEPsRzE-WdpprT3teQoh53Zr0NfRq**.
- Ветка: `feat/task23-data-integrity-native-qa`, основа **`ff32a0f86b8fe9c5ffe7e75406d8b3291471d9c2`** (PR54 на PR52, оба draft/unmerged). Проверенный код: **`5fae671c9829c021151e3c9e6ed0467692a7867a`**; более поздние коммиты — отчёты/доказательства.
- Вход: `Задание_23.zip`, v1.1, 7718B, SHA **`123d4bd298ebecc92176eec44fed718eecc6f04b09472e10ca197e3627d46a69`**; CRC/6 manifest hashes+bytes PASS; все 7 файлов прочитаны.

## Что изменилось

Ранний отказ от создания пустой базы headless-worker; отказ от пустой замены при другом SQLite-источнике; сохранение неизвестных капсул вместо удаления по имени; привязка restore к проверенному manifest и актуальному состоянию DB/медиа; точное ограничение приватных черновиков владельцем в полном экспорте; отмена смешанного экспорта при смене аккаунта. SQLite остаётся schema9, wire capsule schema1, IDs/история/origin не мигрируются.

Добавлен copy-only recovery-tool с dry-run, trusted caller owner-binding и внешним SHA manifest, верификацией файлов/sidecars и исключительно новой изолированной целью. Подготовлен **не исполняющий build** release planner с source/toolchain/signing/version checks и будущим Android-протоколом. 43 исходных файла №22 не изменены.

## Проверено

**554 Flutter PASS / 2 SKIP / 0 FAIL; 13 Python PASS; анализатор без замечаний.** Четыре исходных дефекта сначала воспроизведены RED, затем те же тесты GREEN. Миграции6/7/8→9, холодный старт, отсутствие Google/неверные hints, A→B isolation, frozen history, WAL/journal/corruption, selective capsules и rollback проверялись только на синтетических копиях. Подробности и команды — TESTS.md, сырые логи — EVIDENCE_23.zip/Git.

Матрица всех20 критериев: **17 PASS на заявленном SOURCE/TEST/REPORT уровне, 1 PARTIAL, 2 DEFERRED**. BLOCKED-критериев0; отсутствие физических результатов не скрывается локальными PASS. Частичный пункт — точное воспроизведение прежнего owner-wide MASTER24→25: исходной БД телефона нет, общая причина всех пустых списков **UNKNOWN**. Исправленные новые дефекты не выдаются за доказанный диагноз того инцидента.

## Остаток и безопасный следующий шаг

Review draft PR55 с учётом неслитой цепочки PR52/54. Сейчас владельцу **не требуется устанавливать APK**. После завершения следующих разработок и отдельного разрешения — будущий native gate с прежней подписью, увеличенным versionCode, UI-created synthetic materials и нормальным обновлением без удаления. Затем два реальных телефона/Google-пользователя. До этого выпуск/физическая сохранность не объявляются завершёнными.

Исходные ТЗ/отчёты №16–22/старые APK сохранены. Репозиторий уже public по фактическому readback; видимость и Drive ACL не менялись. Передача в Drive ограничена обезличенной отчётностью, контрольными суммами и тестовыми доказательствами. В комплекте нет пользовательских SQLite/аудио/токенов/ключей. DELIVERY_23.json и DRIVE_READBACK_23.json фиксируют реальные file IDs, размеры и независимые download-SHA.
