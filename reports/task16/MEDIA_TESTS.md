# Медиа и перенос

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Текущая контрольная точка: de27d86.

Runtime consent подтверждён фактическим JSON, а не только ответом владельца. [Deploy 42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006) SUCCESS: existing Script/version4/source766f178, private bootstrap41, replay и отрицательные проверки. [Readback42876284145](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42876284145) подтверждает DEPLOYED_STORAGE_VERIFIED. Независимый anonymous HTTP200 application/json health повторно проверен; raw health.liveVerified=false — константа, не доказательство сквозной готовности. Старый «Сульфи — дневник» не изменялся.

Последние APK21: source953d5bc, CI42819404870 SUCCESS, 418Flutter PASS. Они пока без endpoint; подключёнными APK их не называем. Текущий Node33 PASS. [Первый live E2E42877004822](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42877004822) FAILED: media.beginUpload превысил20sec timeout. Изолированный новый transport исправлен,3regressionPASS. [Повтор42878030592](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592) выполняется, результат не предполагается. Android OAuth Web client ID отсутствует; законная настройка описана в ANDROID_OAUTH_SETUP_RU.md. Физический Android NOT_RUN.


Контролируемые серверные тесты: SHA256 соответствует native crypto на padding boundaries, multiMB и serialized checkpoint; реальный GAS adapter исполняется с контролируемыми Drive HTTP responses (resumable PUT/Range, preallocated-ID final reply loss). Corrupt hash/short read/wrong actor/unaligned chunks/MIME spoof/incomplete commit/expired or revoked grant отвергаются. Ни owner OAuth, ни session URL не возвращаются.

Dart integration: H264/MP4 test fixture test/fixtures/task16_video.mp4 с расширением >2MB, SHA на обеих сторонах; resume download после262144bytes, без повторной полной передачи. Byte input synthetic; native playback probe контролируемый. PNG/AAC/audio/ZIP and exact manifests имеют local import/export/CRC/SHA/selection tests, selective package scanner rejects zip-slip/bomb/manifest mismatch. Это не многомегабайтное живое аудио с Android.

Live image/audio/video/ZIP bytes + hashes: NOT_VERIFIED (GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML). В отсутствие bootstrap ни synthetic audio, ни пользовательские данные не загружаются в незащищённое место. Живые размеры/контрольные суммы не подменяются суммами локальных fixtures.

Android: video_player2.14.1, native codec probe, реальный file player/pause/seek/lifecycle, конфликт с активной гипносессией блокируется. Реальные кодеки/звук/блокировка/длинные файлы/сеть на устройстве: NOT_RUN. Flutter использует streamed hash/copy, persistent .part и free-space preflight; по256KiB, без загрузки фильма целиком в память. Неподдерживаемый codec и лимит/квота показываются как ошибка, не Published.
