# №16-Б — границы безопасности

Дата: 12.11.2026. Ветка: `fix/task16b-auth-transfer-publication`. Кандидат приложения: `012f7f69b7ad99c0d44f2a442d9649aa1481117e`. Draft PR: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45 . Продолжение №16/16-А, не №17.

- Действующий GAS deployment/version6, его Script ID, старый дневник, Google Drive permissions и main не менялись. Новые отчёты размещаются только в разрешённой папке №16; APK на Drive не загружаются.
- Signing key, packages и сертификат сохраняются. Candidate workflow читает прежние secrets только при ручном запуске из точной feature-ветки этого private repository; PR/fork не запускает этот job. Clasp/OAuth secrets для сборки не требуются.
- Новый server source не публиковался. RS256/issuer/exp/exact Web audience/verified email/server roles/ACL/SHA проверки сохранены. Trace содержит только случайный ID, operation, phase, elapsed, attempt, status/code.
- Access token/ID token остаётся в RAM, не сериализуется в SQLite/ZIP/лог/URL. Новые persisted scopes — хешированные. Исторические rows с прежним scope не удалялись: нельзя утверждать, что старая база очищена от любых прежних identity labels. Они не переиспользуются как другой проверенный аккаунт.
- Неопознанные legacy pending uploads не продолжаются автоматически под новым аккаунтом. Явно сохранённые черновики сохраняются; новая постановка в очередь требует подтверждённого owner binding.
- Android не получает Drive owner credentials/прямой доступ к приватному дереву. Ссылки на private/draft/withdrawn блокируются серверным resolver и на download chunks.
- G3 fail-closed guard для same logical ID / changed audio bytes сохранён. Никакой destructive migration, GC или эксперимента multirevision на базе пользователя.
- Private GitHub draft доступен владельцу/соответствующим repo collaborators. Ссылка сама по себе не обеспечивает доступ закрытому тестировщику. Без изменения ACL владелец может скачать APK и передать файл через Android Quick Share. Репозиторий не открыт и токены не раздаются.
