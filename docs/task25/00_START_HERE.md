# Задание №25 v1.0 — Интеграция Сульфи, P0-гейты и две тестовые Android APK

**Обязательный результат:** проверенный единый интеграционный кандидат на базе №20–24, независимая матрица сохранности данных, при наличии доказанных разрешённых предусловий — два ПРОВЕРОЧНЫХ подписанных APK: MASTER и CLIENT. Если хотя бы критический гейт не пройден, оставаться PARTIAL/BLOCKED и НЕ выдавать несовместимую APK или релиз.

Вход: этот ZIP со всеми включёнными файлами и манифестом. Работать автономно, код менять только в отдельной ветке. НЕ требуется одобрение на каждый безопасный тест/кодовую правку; отдельное разрешение требуется для production/main/live/публичного релиза и личных данных владельца.

**Состояние при написании (22.11.2026):** PR #51 (№20) → #52 (№21) → #54 (№22) → #55 (№23) → #56 (№24) — stacked OPEN DRAFT, НЕ merged. Задание №22 PARTIAL (47 PASS_LOCAL/7 PARTIAL/2 BLOCKED_LIVE/2 DEFERRED), №23 PARTIAL (17 PASS/1 PARTIAL/2 DEFERRED), №24 local-complete (10 PASS/8 ALREADY_DONE); объединение в main/живое внедрение не подтверждены.

**Достоверные источники:**
- Repo https://github.com/luxhypnomaster/sulfi-hypnotherapy
- PR56 https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/56
- №22 https://drive.google.com/drive/folders/1xYICmox_IY9Z5CRSIqjPJFyGuN4nk9fB
- №23 https://drive.google.com/drive/folders/1PTajEPsRzE-WdpprT3teQoh53Zr0NfRq
- №24 https://drive.google.com/drive/folders/1rCulDJG1HEX6Kl7M2pv2YsFtv8oqdGcF
- Базовый регламент https://docs.google.com/document/d/1FABRBXaL8wV0fiMtMaS1Exjz12d0kUyE72v0n_s8arw/edit
- Оперативное состояние https://docs.google.com/document/d/1c7I4Ry8RZAk-5yWF1rgy9sdexSJEaCA47OxNRmooPvI/edit

**Порядок чтения:** (1) этот документ, (2) 01–07, (3) acceptance 08, (4) 09_COMMAND, (5) 10_MANIFEST. Проверить ZIP CRC, SHA отдельных файлов и Git remote heads до изменения исходника. Нельзя считать этот документ указанием нарушать гейты безопасности.

**Ключевые запреты:** не удалять/не очищать/не импортировать поверх оригинальной SQLite и личных медиа; не менять packageName/applicationId/signing для обновляемой пары; не создавать новый signing key; не сливать в main, не force-push, не выпускать GitHub release, не делать production deploy, не трогать живой GAS, OAuth/ACL, не раскрывать credentials, не снимать запреты на серверные feature flags, не утверждать production readiness. Безопасные тесты исключительно на synthetic fixture и изолированных копиях.

**Приёмка:** 08_ACCEPTANCE.csv (55 пунктов) — итоговые PASS_LOCAL, PASS_NATIVE, PARTIAL, BLOCKED, NOT_RUN, DEFERRED_OWNER, ALREADY_DONE; каждый со ссылкой на log/commit/артефакт. APK не требуется ценой риска: при hard STOP фиксировать вывод и продолжать независимые lanes.
