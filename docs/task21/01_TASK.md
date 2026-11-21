# Задание №21 — цель, границы, ожидаемый результат

## Цель
Устранить разрыв между разработанными в №20 HEAD/snapshot/vitrine и реальной *исполняемой* архитектурой без самовольной замены GAS6/provider. Подготовить проверенный **provider-neutral backend binding** и клиентский Flutter runtime connector, сохранить старые данные и методы на время миграции, довести недостающий статичный preview публикации, выполнить максимальную native/CI проверку без фальшивого PASS. Это подготавливает отдельное разрешение владельца на staged/live подключение, но не включает его.

## Что сделать
1. Получить исходник/историю из PR51 и всех ancestor PR; подтвердить актуальный SHA, существующий серверный Router, SQLite queue18, Auth19 default OFF, текущие role checks, реальные места для DI и readback.
2. Определить/зафиксировать минимальную каноническую версию API: `catalog.head`, `catalog.snapshot`, `vitrine.config.read`, `vitrine.config.prepare/commit` либо совместимые с существующим Router имена; **не вводить параллельные серверные истины**. Одинаковые schema/version/hash/etag/scope и error codes у серверного кандидата и Flutter. Не указывать PHP/Postgres/Supabase/TatNet как выбранный provider.
3. Реализовать **локально запускаемый server adapter** с настоящим тестируемым хранилищем в sandbox/fixture и atomic prepare→readback→HEAD flip, CAS/idempotency receipts, rollback; если требуется, сделать кандидат GAS Router handlers в невключённом экспериментальном модуле для локального node drybuild, без подключения к live GAS6. Не имитировать транзакцию там, где доказанной атомарности нет.
4. Flutter: подключить injectable version-negotiated metadata transport в runtime factory, end-to-end `HEAD equal → 0 snapshot`, `HEAD changed → immutable snapshot → verify → SQLite current`, account/scope isolation, bounded timeout/retries/coalescing в очереди №18, без отдельного worker/второй очереди. При отсутствии поддерживающего сервера — **fail closed** и прежний каталог сохраняется.
5. Доказать поток настройки витрины `MASTER draft → server-authorized prepare/commit receipt → verified config revision → CLIENT`, без скрытой публикации под видом локального сохранения. При неподдерживаемом/отсутствующем backend кнопка publish disabled + объяснение. Серверная ACL должна проверять реального principal, не имя APK/email/UI flag.
6. В существующем редакторе реализовать **статичный preview выбранной публикации внутри реального фиксированного Home-баннера**, без ротации, изменения размера, read-state и исходных media. Не создавать параллельный редактор. Проверить оба preview: full reader и static Home.
7. Подготовить воспроизводимый native Android package path для MASTER+CLIENT, сохраняя package IDs, прежний signing policy, Java/Gradle/SDK; не выпускать неподписанный APK как устанавливаемое обновление, не удалять исходный APK28, не раздавать тестовый APK без QA gate. При CI billing 0 steps и локальном OOM выполнить дешевый source/Flutter bundle и чётко зафиксировать блокер. Не обходить spending limit/не менять GitHub billing.
8. Обновить отчёты и заполнить матрицу `PASS/PARTIAL/BLOCKED/NOT_RUN` с уровнем LOCAL, STAGING, NATIVE, LIVE, OWNER, не повышая автоматически уровень тестов №20. Предоставить отдельный риск-отчёт и список exact changes, требующих последующего OWNER approval.

## Чего НЕ делать
- Никакого production GAS6 deploy, смены backend-провайдера, реальных ACL/OAuth/migrations, запуска live/public endpoint, изменения prod OAuth key/credentials, Google Drive rights или пользовательских данных.
- Не мержить main/PR48–51, не менять исходные role/grant модели, не запускать Auth19 default ON, не пересоздавать локальные базы/личные медиа.
- Не создавать семистрочную ADM-панель ради пустых цифр. Она согласована в S-D-ADM-001 v2.2 и будет отдельным полнофункциональным ТЗ после серверной готовности. Не считать созданием UI backend readiness.
- Не брать сторонний VPN, платные подписки, внешние секреты, не запускать destructive cleanup/clear cache; ограничение read-only/unknown учитывать.

## Формат выпуска
Одна stacked draft PR для №21 с проверяемыми commit checkpoints; отчёт в `reports/task21/`, самодостаточная README/ACCEPTANCE; по возможности папка Google Drive `For_Codex/Отчёты — Задание 21` с текстовыми отчётами, `EVIDENCE_21.zip` без секретов и без APK/source; ссылки на PR/CI/логи. В конце: список того, что можно проверить на телефоне, и закрытые/открытые запросы на разрешение владельца.
