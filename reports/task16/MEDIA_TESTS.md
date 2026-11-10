# Медиа и перенос

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


Контролируемые серверные тесты: SHA256 соответствует native crypto на padding boundaries, multiMB и serialized checkpoint; реальный GAS adapter исполняется с контролируемыми Drive HTTP responses (resumable PUT/Range, preallocated-ID final reply loss). Corrupt hash/short read/wrong actor/unaligned chunks/MIME spoof/incomplete commit/expired or revoked grant отвергаются. Ни owner OAuth, ни session URL не возвращаются.

Dart integration: H264/MP4 test fixture test/fixtures/task16_video.mp4 с расширением >2MB, SHA на обеих сторонах; resume download после262144bytes, без повторной полной передачи. Byte input synthetic; native playback probe контролируемый. PNG/AAC/audio/ZIP and exact manifests имеют local import/export/CRC/SHA/selection tests, selective package scanner rejects zip-slip/bomb/manifest mismatch. Это не многомегабайтное живое аудио с Android.

Live image/audio/video/ZIP bytes + hashes: NOT_VERIFIED (GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML). В отсутствие bootstrap ни synthetic audio, ни пользовательские данные не загружаются в незащищённое место. Живые размеры/контрольные суммы не подменяются суммами локальных fixtures.

Android: video_player2.14.1, native codec probe, реальный file player/pause/seek/lifecycle, конфликт с активной гипносессией блокируется. Реальные кодеки/звук/блокировка/длинные файлы/сеть на устройстве: NOT_RUN. Flutter использует streamed hash/copy, persistent .part и free-space preflight; по256KiB, без загрузки фильма целиком в память. Неподдерживаемый codec и лимит/квота показываются как ошибка, не Published.
