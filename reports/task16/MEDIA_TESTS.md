# Медиа и пакеты — реальные доказательства

Дата:10.11.2026 UTC. Ветка feat/task16-alchemist-full-server. APK/sourcee4ed74b, service-test source6f1c8b9 (тот же lib/test код; версия21→22), GAS/version4/source766f178. Старый «Сульфи — дневник» не менялся. C0/PREFLIGHT сохранён, не повторялся.

[Real service E2E42878030592 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592): авторские Flutter-сервисы → существующий GAS → private Drive → отдельный клиентский SQLite/installer.6540746B загружено и6540746B скачано, WAV/AAC/PNG/MP4/ZIP и SHA проверены. Recovery42887239597, artifact13797585085; протокол LIVE_SERVICE_E2E.json и LIVE_TIMELINE.json. Это НЕ испытание двух установленных Android APK.

[Deploy42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006)/readback42876284145: anonymous JSON health, exact41 private folders/replay/live negatives PASS. [Обе APK22/CI42878716769 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878716769):419Flutter/33newNode/24oldNode/13schemas/formatter/analyzer/fixedCLIENT/package/signing PASS. Пока LOCAL_BUILD_ENDPOINT_NOT_CONFIGURED: владелец подтвердил, что Web OAuth client ещё не создан. Нужны официальные Web+две Android регистрации, см. ANDROID_OAUTH_SETUP_RU.md; clasp повторно авторизовывать не нужно. Физический Android NOT_RUN.

| Образец | Размер bytes | Проверка |
|---|---:|---|
| WAV |2205044| source/client/direct-Drive SHA equal; PCM16LE22050Hz/mono/50sec |
| AAC variants |5010×2| exact SHA,12secAAC each; module missing-only install |
| ZIP |2220602| source/client/direct-Drive SHA equal; CRC/safe paths; embedded WAV exact; installer PASS |
| Diary PNG |68| source/client equal; independently decoded2×2RGBA |
| Diary AAC |5001| source/client equal, exact original fixture |
| Diary MP4 |2100011| source/client/direct-Drive SHA equal; H26464×48/1sec + valid2MiB free atom, Linux decodePASS |

WAV SHA97cb9320823ba56e51b829c7f750748ec81f4d1e0b5c979c2af61e69cac2d0e9; ZIP5f1de5aa7861be368db52e6c550b5c9cf2d0aeadf1da7afc5cb4dc729f0bdec7; MP4ff6ba84c2b76cb94d31d9addc480d019af8b6a97b6aaa273ea686d6393a8e0f1. Подробные direct readbacks — DRIVE_WAV/AAC/ZIP/DIARY_MEDIA_READBACK.json. Все7actual blobs проверены sole-owner/sharedfalse, публичный Drive ACL не включался.

LIVE service: upload stop262144/resume exact; download video stop262144/new downloader resume; metadata edit0upload; broker reader не имеет Drive OAuth credentials. Реальный token/Drive session URL/fileId не передаётся читателю. Последующий unpublish+archive даёт404 на новые bytes; offline module remains installed. Удалений source blobs/личных файлов не выполнялось.

Native playback/background/restart/low-space/кодеки на телефоне NOT_RUN. Capsule corruption/zip-slip/bomb/CRC/SHA/faults и process-like persistence проверены локальными тестами, не выдаются за физическую Android QA. Время/квоты/размеры — PERFORMANCE_AND_LIMITS.md.
