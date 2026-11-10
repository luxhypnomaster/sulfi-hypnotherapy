# Задание 16 — фактический результат

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Текущая контрольная точка: de27d86.

Runtime consent подтверждён фактическим JSON, а не только ответом владельца. [Deploy 42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006) SUCCESS: existing Script/version4/source766f178, private bootstrap41, replay и отрицательные проверки. [Readback42876284145](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42876284145) подтверждает DEPLOYED_STORAGE_VERIFIED. Независимый anonymous HTTP200 application/json health повторно проверен; raw health.liveVerified=false — константа, не доказательство сквозной готовности. Старый «Сульфи — дневник» не изменялся.

Последние APK22: sourcee4ed74b, CI42878716769 SUCCESS,419Flutter PASS,33new/24oldNode PASS. Они пока без endpoint; подключёнными APK их не называем. Текущий Node33 PASS. [Первый live E2E42877004822](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42877004822) FAILED: media.beginUpload превысил20sec timeout. Изолированный новый transport исправлен,3regressionPASS. [Повтор42878030592](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592) выполняется, результат не предполагается. Android OAuth Web client ID отсутствует; законная настройка описана в ANDROID_OAUTH_SETUP_RU.md. Физический Android NOT_RUN.


| Факт | Результат |
|---|---|
| C0 | COMPLETE, исходный PREFLIGHT сохранён; не повторялся |
| FULL_CODE_IMPLEMENTED | YES — код серверных и Flutter-потоков реализован; Серверные и Flutter-потоки реализованы; это не означает147PASS. Конфликтные G3 замены аудио закрыты, миграция не заявлена законченной |
| CLASP_LOGIN_COMPLETED | YES — два реальных main-run, scope и owner verification |
| GITHUB_SECRET_MISSING | NO — repository CLASPRC_JSON; значение не извлекалось/не выводилось |
| SERVER_LIVE | YES — anonymous JSON health, version4, actual bootstrap/replay |
| DRIVE_TREE_LIVE | PASS — exact41 owner-only folders, replay/readback |
| FULL_E2E | NO / NOT_VERIFIED — нет доказанной цепочки двух APK через живой Drive |
| APK_BUILT | YES — обе0.4.14+22, CI42878716769 SUCCESS, общий sourcee4ed74b |
| ANDROID_NOT_RUN | YES — физического устройства нет |

Реализованы авторский каталог карточек трека/модуля/шаблона/сессии/сборки/ZIP, аннотации и обложки, точные manifests, реальная очередь, upload/commit/readback, клиентский каталог и выборочная установка через прежний LocalCatalog/CapsuleService. Дневник: текст/изображения/звук/видео/ContentLink, офлайн-очередь, quiet edit/reannounce/close/expiry, изолированный личный cache и read-state. Сохранены старые локальные файлы, история, SQLite, package IDs, ключ подписи и принятый плеер.

Сервер: V8 doGet/doPost, проверка Google JWT/ролей, private Drive snapshots/atomic head, namespace shards, курсоры/ETag/idempotency, grants/revoke/audit/sync, защищённый256KiB broker, resumableDrivePUT/RangeGET, SHA/MIME, immutable revisions и bootstrap41папки. Закрытие публикации прекращает новые загрузки, не удаляя используемые байты.

Повторную авторизацию clasp, компьютер и ручной перенос кода не запрашивал. Android Google web OAuth client ID не настроен и не подменяется клиентом clasp. Подробности — CLOUD_ACCESS.md, TESTS.md (147строк), APK_INFO.md и ISSUES_AND_NEXT.md. APK на Google Drive не загружались.

Задание16 в целом НЕ закрыто. C2 runtime/private bootstrap завершён. C4 live service E2E выполняется; native Android OAuth и физическая проверка обеих APK ещё не завершены. Не объявляем147PASS.