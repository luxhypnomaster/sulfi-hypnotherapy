# Незавершённое и точка продолжения

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Текущая контрольная точка: de27d86.

Runtime consent подтверждён фактическим JSON, а не только ответом владельца. [Deploy 42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006) SUCCESS: existing Script/version4/source766f178, private bootstrap41, replay и отрицательные проверки. [Readback42876284145](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42876284145) подтверждает DEPLOYED_STORAGE_VERIFIED. Независимый anonymous HTTP200 application/json health повторно проверен; raw health.liveVerified=false — константа, не доказательство сквозной готовности. Старый «Сульфи — дневник» не изменялся.

Последние APK22: sourcee4ed74b, CI42878716769 SUCCESS,419Flutter PASS,33new/24oldNode PASS. Они пока без endpoint; подключёнными APK их не называем. Текущий Node33 PASS. [Первый live E2E42877004822](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42877004822) FAILED: media.beginUpload превысил20sec timeout. Изолированный новый transport исправлен,3regressionPASS. [Повтор42878030592](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592) выполняется, результат не предполагается. Android OAuth Web client ID отсутствует; законная настройка описана в ANDROID_OAUTH_SETUP_RU.md. Физический Android NOT_RUN.


1. Runtime/consent и bootstrap41 УСТРАНЕНЫ и реально проверены. Не повторять C0, clasp login или создание Script. Использовать существующие version4/deployment и pathKey registry.
2. Дождаться фактического результата live Flutter-service E2E42877004822; исправлять конкретные сбои и закреплять обновлённый source hash через узкий main PR, без допуска arbitrary PR к production identity. Linux-services не подменяют две установленные APK.
3. Android OAuth: отсутствует публичный Web client ID и подтверждение двух Android client registrations. ANDROID_OAUTH_SETUP_RU.md содержит официальную phone-only процедуру, package/SHA-1 взяты из read-only CI42875871201, не из предположения. Google запрещает автоматическое создание обычных OAuth clients; в среде нет браузерной сессии владельца. Не использовать clasp client или undocumented/IAP APIs как обход.
4. После законной регистрации настроить публичный Web audience, собрать обе APK с тем же ключом/package и большим versionCode. Проверить SDK вход и обновление поверх на телефоне. Пока NOT_RUN.
5. G3 same-ID changed audio остаётся fail-closed по разрешённой ТЗ политике: не подменять используемые bytes без inventory/backup/reconciliation. Нет разрушительных миграций.
6. Физические playback/background/lock/low-space/interruptions, установка поверх с личной библиотекой и действительный вход Google ещё не проверены.

Продолжать №16, не создавать №17. APK не загружать на Google Drive. Старый проект дневника не менять. Контрольные точки и ограничения сохранять в PROGRESS.md.

Подтверждение владельца10.11.2026: OAuth Web client ещё НЕ создан. Это подтверждённая отдельная конфигурационная незавершённость, не повторная авторизация clasp и не runtime consent. Продолжать независимые server/Drive/CI проверки.
