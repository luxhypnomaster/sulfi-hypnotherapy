# Передача нового сервера — №16

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


Точное имя: «Сервер Проекта Алхимик». Script ID: 1810esAOGDfsUf6EYdT9y7uY5_v0dzBmb5YSfwPZkxtZJsKw_ByEre0Vc. Endpoint: https://script.google.com/macros/s/AKfycbzw36cEXSHVgfRxSl7k-6c2yV4uyPapqb-zndib8AlbHxhFCstXqxoqvqTMJvlHTT5zEg/exec. Не подставлять URL старого дневника. Cloud source/deploy берётся только из trusted main после tests/readiness; текущая app development branch отдельная.

Повторный запуск: Actions → Alchemist production deploy (manual) → branch main → Run workflow. Он проверяет owner OAuth, exact-title+marker create-once, private Script ACL, полный source SHA/readback, immutable version, stable deployment ID, bootstrap41/replay/negative security. Если блокер не устранён, не запускать в цикле и не создавать проект вручную.

Секрет: только repository CLASPRC_JSON, не environment. В публичной конфигурации APK могут быть SULFI_ALCHEMIST_API и SULFI_GOOGLE_WEB_CLIENT_ID; значения только после настоящего /exec readback/legitimate Google client setup. CI clasp audience/refresh/access tokens никогда не в APK.

Файлы контракта: SERVER_CONTRACT.md, DRIVE_TREE_AND_ACL.md, SECURITY_AND_ROLLBACK.md, TESTS.md, SOURCE_HASHES/DEPLOYMENT artifacts только если соответствующий шаг выполнен. Snapshot head/private folder registry/owner grants остаются в защищённом Script Properties/Drive, не в этом shared report.

Continue source: ae18d11bb0208bb7461574df152fa98b55c2fe2d, branch feat/task16-alchemist-full-server; аудит C0 не повторять. Старый Apps Script не изменять. APK распространяются GitHub artifacts, отчёты — текущая папка For_Codex/Отчёты — Задание16. Подробные блокеры/phone-only actions — ISSUES_AND_NEXT.md.

Фактическая immutable версия2, deployment source64893b3. Копия complete source/tools/manifest/vendor/license/tests и конфигурационных schemas — SERVER_HANDOFF_TASK16.zip; в ней нет credentials/InitialConfig/owner sub/APK. Код из архива не требует ручного переноса владельцем; рабочий путь остаётся GitHub Actions + clasp. Данные и runtime authorization не входят в Git rollback.
