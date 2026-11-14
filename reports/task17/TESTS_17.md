# №17 — фактически выполненные проверки

## CODE / CONTROLLED

Полная проверка source `fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568` в CI43548636228: **469 Flutter,3 CLIENT,47 серверных Node+24 legacy PASS**, format/analyze/schema/lock PASS; обе signed APK27 собраны. Весь старый run имел FAILURE из-за MASTER-стенда: его не переименовываем в SUCCESS. Runtime послеfbd неизменен, полные проверки ради harness/docs не повторялись.

Адресные проверки текущего стенда:3 реальных subprocess-теста монитора (обычное завершение, код7, SIGTERM),3 проверки навигации/readback по реальным failure XML,11 отрицательных delivery-gate тестов (включая неуспешный26, несовпадающий driver/source, public draft/повторную запись). Feature-only rollback planner:11 Node PASS, включая чужой HEAD/отсутствие CAS/разделение deployment и HEAD. Они не заменяют Google/телефон.

## Native Android

| Проверка | CI | Доказательство |
|---|---|---|
|MASTER25→27/API34|43583577375, job132413251139|13 PASS; Google baseline draft NOT_RUN|
|MASTER26→27/API34|43614090740, job132505244736|13 PASS; Google baseline draft NOT_RUN; весь run SUCCESS|
|CLIENT25→27/API35|43548636228, job132310281448|12 PASS; Google baseline draft NOT_RUN|

UI-created baseline, обычное install-r, exact SQLite rows/IDs/media SHA/integrity, UI-видимость, native AudioTrack, cold restart. Для MASTER — новый локальный черновик после обновления с точным текстом и сохранением. Не использовались SQL-seeding, fake Google, uninstall/clear/downgrade. Снимки и JSON receipts извлечены из CI с проверкой длины/SHA и сохранены в native_final26_pin12 и исторических каталогах.

## Диагностика и обоснование повторов

| Run | Новая гипотеза / реальный результат |
|---|---|
|43608962837|Process monitor: QEMU нормальный exit0; UI journal search ошибочно принят за editor. Native12 PASS, последний draft не прошёл.|
|43610436406|Строгая проверка editor route; монитор настоящего QEMU зафиксировал **SIGSEGV-11** до candidate/cleanup, oom_kill0.|
|43611509589|Закреплена официальная Stable37.2.12; **native13 PASS**, но вспомогательный GUI version CLI завершился127, весь job FAIL. Не квалифицирован как выпуск.|
|43612932602|Headless version check и ready barrier PASS. Новый fail — transient-пустой accessibility readback названия; screenshot/XML содержат точное значение, QEMU exit0.|
|43614090740|Ограниченное read-only ожидание точного значения + фактическая IME visibility; **весь run SUCCESS, native13 PASS**.|
|43615276560|Delivery-only: exact3native proofs/core tree identity/private empty target/cached bytes, SUCCESS. Без build/sign/native/production deployment.|

Каждый новый native запуск отвечал новой диагностической гипотезе. Результаты failed run не скрыты. Полная хронология до этой серии — CODEX_EFFICIENCY_17.md. Точная faulting function37.2.13 неизвестна; workaround измерен, upstream bug не объявлен закрытым.

## Реальное скачивание APK

После CI обе private release assets независимо скачаны через owner GitHub API (387644474 bytes). Реально исполнен `scripts/task17/verify_downloaded_apks.py`: SHA/размер, корректные package/version27, Java apksigner и **ровно один прежний сертификат**, compiled endpoint/Web Client ID, DEX storage guard — PASS. Результат `APK_PAIR_17.json`; не mock и не одна metadata производителя. Chrome телефона/download/installer NOT_RUN.

## LIVE / OWNER

Read-only admin inspect43584729310: действующий GAS6, HEAD совпадает сversion6,23файла/типы и известные статические SHA проверены. Никаких server push/deploy/rollback. Это исторический точный inspect, не новый повторный live E2E.

Настоящие Google MASTER/CLIENT, provider refresh15/30/60мин, legacy Google drafts, публикация каталога/ContentLink/выборочная установка на два телефона и слышимое offline — **NOT_RUN**. Короткая запись без blocks наGAS6 — **BLOCKED_OWNER_APPROVAL**, минимальный candidate diff controlled GREEN, не deployed.
