# №16-Б — результат автономного этапа

Задание16 и16-А продолжаются,№17 не создавался. Исправления №16-Б реализованы,две подписанные APK25 доступны для проверки. **Полная физическая приёмка и закрытие№16 пока не объявлены.**

## Что реализовано

- Официальный Google SDK restore/refresh,единая identity обоих входов,различимые401/403/network ошибки. Offline не стирает данные;отвергнутый сервером токен не считается подтверждённым.
- Owner/revision/SHA-bound uploader,authoritative offset и receipt,resume/idempotency,ограниченные повторы,раздельные bytes/verify/catalog commit.
- Независимые «Добавить в каталог» и дневниковый анонс exact ContentLink;готовые файлы не передаются повторно,сбой сохраняет draft.
- Локальный preview/persistence обложки,категории мультисписком,сохранение метаданных;app-lifetime runner существующей очереди,реальные pause/resume/cancel и понятные стадии.

Исходник APK `012f7f69b7ad99c0d44f2a442d9649aa1481117e`. Ветка `fix/task16b-auth-transfer-publication`,[draft PR45](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45). Поздние commits содержат только отчёты/test harness;app source tree unchanged.

## APK

- [MASTER0.4.17+25](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-89fd5ff3b9d445c2d347/sulfi-master-test-25.apk) — ставить поверх24,без uninstall/очистки.
- [CLIENT0.4.17+25](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-89fd5ff3b9d445c2d347/sulfi-client-test-25.apk) — отдельный package/sandbox.
- [Закрытый draft с обеими APK](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/tag/untagged-89fd5ff3b9d445c2d347). Нужен GitHub login владельца;тестировщику без repo access можно передать APK через Quick Share. Публичных публикаций/ACL изменений нет,на Drive APK не загружались.

Обе APK действительно скачаны обратно;SHA256,size,V2 certificate fingerprint и compiled endpoint/WebID совпали. Подпись прежняя0b743568…10afc6;versionCode25,package IDs сохранены. Все значения/хеши — APK_INFO_16B.md и APK_READBACK_16B.json. APK24 assets остаются нетронутыми.

## Что проверено

- [Exact-source CI43162781960](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43162781960):433 Flutter PASS,analyze/format PASS;Node46 и старый дневник24;client edition3;13 schemas/4 fixtures/10 negatives.
- [Build43163688437](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43163688437):SUCCESS attempt2. Первый внешней Kotlin dependency-resolution failure сохранён отдельно;исходник/подпись не менялись.
- [Native smoke43165399224](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43165399224):update24→25 сохраняет audio/history/template/diary,SQLite integrity,CLIENT isolation и реальный UI capsule export/import PASS. Первоначально6 PASS/2 BLOCKED.
- [Corrected native probe43196379265](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43196379265):library/session/screen-off AudioTrack на24/25 подтверждены;7 PASS/1 BLOCKED. Один navigation expectation Home не принят,не скрыт общим success. Слышимость человеком не проверялась.
- Контролируемый actual Dart/production JS путь:сбой cover upload→сохранённый draft→retry→3 exact tracks→catalog→diary→client selective install;повтор без retransmission PASS. Это не настоящий Google/Drive/phone E2E.
- Реальный loopback benchmark20 запросов:TCP connections20→1,p50/p95 в PERFORMANCE_16B.json. Не выдаётся за скорость GAS/DNS/TLS/Wi-Fi/mobile.

## Приёмочная матрица и остаток

Все80 исходных критериев сохранены: **37 PASS / 41 PARTIAL / 2 BLOCKED**. Code/Emulator/Live/Owner раздельны в ACCEPTANCE_16B.csv. Оригинальные147 критериев и отчёты16/16-А не переписаны;DELTA_147_16B.md добавляет факты.

BLOCKED:физическое Wi-Fi/mobile/network switch и реальный offline Elman3tracks на телефонах владельца. PARTIAL:новые Google SDK flows/публикация/установка реальными MASTER иCLIENT до owner QA. Initial Google/role publish/deny APK24,уже подтверждённые владельцем,учтены отдельно.

Новый JWT/trace backend source остаётся только кандидатом:действующий GAS6 не изменялся. Для его deployment нужно отдельное разрешение на проверенную ревизию по SERVER_DEPLOY_PLAN_16B.md. Старый дневник,main,signing,private Drive ACL и пользовательские данные сохранены.

Первый шаг владельца:скачать MASTER APK25 в авторизованном GitHub браузере и установить поверх24;проверить свои четыре трека/историю/шаблоны/черновики. Затем второй реальный Google-аккаунт наCLIENT и сценарий PHONE_QA_16B.md. ПК,пароли,refresh tokens и ручной перенос server code не требуются.

Отчёты/PNG/матрица/evidence ZIP/SHA manifest размещены в [существующей папке№16](https://drive.google.com/drive/folders/1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z),без удаления оригиналов. Подробности — CHANGES_16B,TESTS_16B,ISSUES_16B,ROOT_CAUSE_16B,SECURITY_16B,EMULATOR_16B.
