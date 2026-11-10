# Задание 16 — фактический результат

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


| Факт | Результат |
|---|---|
| C0 | COMPLETE, исходный PREFLIGHT сохранён; не повторялся |
| FULL_CODE_IMPLEMENTED | YES — код серверных и Flutter-потоков реализован; Серверные и Flutter-потоки реализованы; это не означает147PASS. Конфликтные G3 замены аудио закрыты, миграция не заявлена законченной |
| CLASP_LOGIN_COMPLETED | YES — два реальных main-run, scope и owner verification |
| GITHUB_SECRET_MISSING | NO — repository CLASPRC_JSON; значение не извлекалось/не выводилось |
| SERVER_LIVE | NO — GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML |
| DRIVE_TREE_LIVE | NOT_VERIFIED |
| FULL_E2E | NO / NOT_VERIFIED — нет доказанной цепочки двух APK через живой Drive |
| APK_BUILT | YES — обе0.4.14+21, CI42819404870 SUCCESS, общий source953d5bc |
| ANDROID_NOT_RUN | YES — физического устройства нет |

Реализованы авторский каталог карточек трека/модуля/шаблона/сессии/сборки/ZIP, аннотации и обложки, точные manifests, реальная очередь, upload/commit/readback, клиентский каталог и выборочная установка через прежний LocalCatalog/CapsuleService. Дневник: текст/изображения/звук/видео/ContentLink, офлайн-очередь, quiet edit/reannounce/close/expiry, изолированный личный cache и read-state. Сохранены старые локальные файлы, история, SQLite, package IDs, ключ подписи и принятый плеер.

Сервер: V8 doGet/doPost, проверка Google JWT/ролей, private Drive snapshots/atomic head, namespace shards, курсоры/ETag/idempotency, grants/revoke/audit/sync, защищённый256KiB broker, resumableDrivePUT/RangeGET, SHA/MIME, immutable revisions и bootstrap41папки. Закрытие публикации прекращает новые загрузки, не удаляя используемые байты.

Повторную авторизацию clasp, компьютер и ручной перенос кода не запрашивал. Android Google web OAuth client ID не настроен и не подменяется клиентом clasp. Подробности — CLOUD_ACCESS.md, TESTS.md (147строк), APK_INFO.md и ISSUES_AND_NEXT.md. APK на Google Drive не загружались.

Задание16 в целом НЕ закрыто. C1 source gate завершён, C2 дошёл до реальной version2/deployment с readback, C3 код/локальные tests/две APK готовы, C4 live E2E BLOCKED, C5 текущие факты и доказательства подготовлены. Не объявляем работающее облако или147PASS.
