# Задание16 — фактический итог текущего этапа

Дата:10.11.2026 UTC. Ветка feat/task16-alchemist-full-server. APK/sourcee4ed74b, service-test source6f1c8b9 (тот же lib/test код; версия21→22), GAS/version4/source766f178. Старый «Сульфи — дневник» не менялся. C0/PREFLIGHT сохранён, не повторялся.

[Real service E2E42878030592 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592): авторские Flutter-сервисы → существующий GAS → private Drive → отдельный клиентский SQLite/installer.6540746B загружено и6540746B скачано, WAV/AAC/PNG/MP4/ZIP и SHA проверены. Recovery42887239597, artifact13797585085; протокол LIVE_SERVICE_E2E.json и LIVE_TIMELINE.json. Это НЕ испытание двух установленных Android APK.

[Deploy42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006)/readback42876284145: anonymous JSON health, exact41 private folders/replay/live negatives PASS. [Обе APK22/CI42878716769 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878716769):419Flutter/33newNode/24oldNode/13schemas/formatter/analyzer/fixedCLIENT/package/signing PASS. Пока LOCAL_BUILD_ENDPOINT_NOT_CONFIGURED: владелец подтвердил, что Web OAuth client ещё не создан. Нужны официальные Web+две Android регистрации, см. ANDROID_OAUTH_SETUP_RU.md; clasp повторно авторизовывать не нужно. Физический Android NOT_RUN.

| Контрольная точка | Факт |
|---|---|
| C0 | COMPLETE; первоначальный PREFLIGHT неизменён |
| C1 | Полный серверный код/Flutter-потоки реализованы; G3 конфликтная замена аудио остаётся fail-closed по разрешённой ТЗ политике |
| C2/runtime | PASS: existing sole Script/version4, публичный JSON, private41-folder bootstrap/replay/security |
| C3 | Код и обе подписанные APK22 готовы; native OAuth/endpoint ещё не настроены |
| C4/service | PASS: реальные Flutter-сервисы/Google Drive,10checkpoint phases, hashes/resume/metadata-only/missing-only install/private denial/withdraw/offline retention |
| FULL_E2E two APK | NOT_VERIFIED: APK пока не connected; Android SDK/телефон NOT_RUN |
| C5 | Фактические отчёты/147строк/комплект SERVER_HANDOFF/ссылки APK в существующей папке №16 |

Исправления после consent: настоящий Advanced Drive adapter(create resource/null/options, без undefined pageToken, empty ACL fail-closed), безопасный bootstrap/replay и диагностика стадий; отдельный Alchemist HTTP transport с bounded5min response timeout после настоящего сбоя20sec media.beginUpload. Legacy DiaryApi не менялся.

Live сценарий: пауза upload после262144B и resume без лишних ACKbytes; публикация/установка annotated WAV; модуль3точных трека+2паузы, скачаны только2отсутствующих AAC (10020B); восстановление receipt после потерянного ответа уже выполненного publish; annotation-only без повторной передачи; шаблон и реальный ZIP; дневник с PNG/AAC/MP4 и exact ContentLink; возобновление video download новым downloader; private entry404/anonymous mutation403; unpublish/archive прекращают новые downloads, установленная копия сохраняется.

Материальное ограничение: полный смешанный live сценарий занял51:42. Максимальный HTTP-leg publish67910ms, uploadChunk31792ms, commit26041ms; старые20секунд действительно недостаточны. Это не low-latency сервер и не проверка многочасового фильма; размеры около2.1–2.2MB, видео1secH264 с допустимым2MiB free atom. См. PERFORMANCE_AND_LIMITS.md. Не обещаем скорость/квоты вне измеренного.

Task16 целиком НЕ закрыто: владелец ещё не создал Web OAuth client/две Android registrations; нет настройки обеих APK и физического QA. Продолжать №16, не создавать №17. Повторного server create/bootstrap-from-scratch/C0 не требуется. Личные файлы/история/плеер не удалялись; APK только GitHub, не Drive.
