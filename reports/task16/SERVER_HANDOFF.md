# Передача нового сервера — №16

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Текущая контрольная точка: de27d86.

Runtime consent подтверждён фактическим JSON, а не только ответом владельца. [Deploy 42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006) SUCCESS: existing Script/version4/source766f178, private bootstrap41, replay и отрицательные проверки. [Readback42876284145](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42876284145) подтверждает DEPLOYED_STORAGE_VERIFIED. Независимый anonymous HTTP200 application/json health повторно проверен; raw health.liveVerified=false — константа, не доказательство сквозной готовности. Старый «Сульфи — дневник» не изменялся.

Последние APK22: sourcee4ed74b, CI42878716769 SUCCESS,419Flutter PASS,33new/24oldNode PASS. Они пока без endpoint; подключёнными APK их не называем. Текущий Node33 PASS. [Первый live E2E42877004822](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42877004822) FAILED: media.beginUpload превысил20sec timeout. Изолированный новый transport исправлен,3regressionPASS. [Повтор42878030592](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592) выполняется, результат не предполагается. Android OAuth Web client ID отсутствует; законная настройка описана в ANDROID_OAUTH_SETUP_RU.md. Физический Android NOT_RUN.


Точное имя: «Сервер Проекта Алхимик». Script ID: 1810esAOGDfsUf6EYdT9y7uY5_v0dzBmb5YSfwPZkxtZJsKw_ByEre0Vc. Endpoint: https://script.google.com/macros/s/AKfycbzw36cEXSHVgfRxSl7k-6c2yV4uyPapqb-zndib8AlbHxhFCstXqxoqvqTMJvlHTT5zEg/exec. Не подставлять URL старого дневника. Cloud source/deploy берётся только из trusted main после tests/readiness; текущая app development branch отдельная.

Повторный запуск: Actions → Alchemist production deploy (manual) → branch main → Run workflow. Он проверяет owner OAuth, exact-title+marker create-once, private Script ACL, полный source SHA/readback, immutable version, stable deployment ID, bootstrap41/replay/negative security. Если блокер не устранён, не запускать в цикле и не создавать проект вручную.

Секрет: только repository CLASPRC_JSON, не environment. В публичной конфигурации APK могут быть SULFI_ALCHEMIST_API и SULFI_GOOGLE_WEB_CLIENT_ID; значения только после настоящего /exec readback/legitimate Google client setup. CI clasp audience/refresh/access tokens никогда не в APK.

Файлы контракта: SERVER_CONTRACT.md, DRIVE_TREE_AND_ACL.md, SECURITY_AND_ROLLBACK.md, TESTS.md, SOURCE_HASHES/DEPLOYMENT artifacts только если соответствующий шаг выполнен. Snapshot head/private folder registry/owner grants остаются в защищённом Script Properties/Drive, не в этом shared report.

Continue source: 6927854, branch feat/task16-alchemist-full-server; аудит C0 не повторять. Старый Apps Script не изменять. APK распространяются GitHub artifacts, отчёты — текущая папка For_Codex/Отчёты — Задание16. Подробные блокеры/phone-only actions — ISSUES_AND_NEXT.md.

Фактическая immutable версия4, deployment source766f178. Копия complete source/tools/manifest/vendor/license/tests и конфигурационных schemas — SERVER_HANDOFF_TASK16.zip; в ней нет credentials/InitialConfig/owner sub/APK. Код из архива не требует ручного переноса владельцем; рабочий путь остаётся GitHub Actions + clasp. Данные и runtime authorization не входят в Git rollback.
