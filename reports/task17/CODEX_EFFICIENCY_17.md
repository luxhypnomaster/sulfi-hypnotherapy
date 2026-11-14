# №17 — затраты и повторы

Неизвестны weekly/5h проценты пользователя; оценки не выдумываются. Счётчики перекрывающихся адресных прогонов не складываются в число уникальных тестов. Один большой LIVE E2E ради отчётности не повторялся.

## G0–G4

G0: один ZIP,10файлов,9MANIFEST digest/byte проверок,67критериев. Пять действующих Docs K/F/passport/roadmap/16А сохранены для адресного чтения. Read-only GAS health200. Два production RED, затем отдельный frozen catalog credential RED. Исторический trace владельца недоступен и не выдуман.

G1: адресные серии4PASS,8PASS/1FAIL (старый тест пытался переключить уже выбранный аккаунт через signIn вместо explicit switch), затем13PASS с late SDK race. Неверное имя test-файла дало loading error, отдельно записано как ошибка команды. Privacy/server-role отрицательные проверки сохранены.

G2/G3: пересекающиеся серии9/7/4/8 и финальная19PASS; actual Dart→JS loopback с lost commit reply,3валидных AACfixtures и существующим installer. Debug OFF не скрывает попытки. Старый GAS6 short-only RED и минимальный candidate GREEN. Ни Google, ни Drive тут не LIVE.

G4: сначала5новых unit/widget PASS, потом реальный stale reader-cache author label RED→GREEN добавил шестой тест. Catalog200% прежний тест и отдельный preview200% вариант PASS. Analyze/format запускались адресно после изменений. Не повторяется полный набор для одних отчётов.

## CI / Android — полная хронология

| Run | Исходник / цель | Фактический исход и причина следующего шага |
|---|---|---|
|43513034708|server-only PR checks|SUCCESS; не Android и не deployment.|
|43513716062|5cfb8a1, первый full verify|457PASS/11FAIL;10legacy labels,1настоящий verified-switch self-generation bug. Build/native SKIPPED. Исправления адресно15PASS + прежний privacy1PASS. Один wrong filename loading error не скрыт.|
|43515852713 attempt1|85ff507, full verify/build|468FlutterPASS/0FAIL, CLIENT tests, Node47+legacy24, schema/analyze/format PASS. Build FAIL до appcompile: official Kotlinstdlib2.2.21 resolution. После HEAD200 двух officialPOM разрешён один bounded failed-jobs retry.|
|43515852713 attempt2|тот же85ff507|Успешный verify НЕ повторялся (старые timestamps). Build signed pair27 SUCCESS. Native3 STOP до VM: token contents:read не читает private draft baseline,403. Ни один native upgrade не объявлен PASS. Пара85 осталась QUARANTINED, НЕ выдана.|
|43546562439|4a84759, только cached native|403 исправлен trusted manual contents:write; затем наш trailing-slash repo root404. STOP до VM. URL исправлен, строгий mocked route и real read-only metadata preflight PASS; preflight перенесён до SDK.|
|43546879054|driver9340241, APK85ff507, cached native|MASTER25 baseline UI и upgrade/cold/rows/media/nativeAudioTrack PASS; последний новый offline draft BLOCKED_DRIVER из-за EditText индекса после keyboard scroll. MASTER26/CLIENT25 остановились на старом watch до upgrade: ADBdisconnect/UIAutomation timeout. Снимки/XML/receipts сохранены. OOM не доказан.|
|43548636228|fbdaa7b, финальный новый app snapshot|Один новый full verify/build оправдан реальным published-author label fix и шестым widget test. Native driver: physical framebuffer720x1280, modern-gpu swiftshader вместо swiftshader_indirect, screenshot до UIAutomation, host RAM/disk/ADB/OOM diagnostics; scrolltop+exact SQLite draft values. Это одна ограниченная новая гипотеза, не слепой повтор прежнего fail. Текущие результаты CI_17.json/NATIVE_*_17.json.|

Новый source APK fbd нельзя подменять старой парой85 даже при совпадающем versionCode27. До первой выдачи обе пары остаются раздельными cache; source27 ранее не публиковался. Если новый native stall повторится без новой доказанной причины, STOP/BLOCKED, а не третий бессмысленный emulator retry.

## Инфраструктура и доставка

GitHub artifact storage quota получена; старые artifacts НЕ удалены. Private Actions logs содержат bounded SHA chunks только synthetic native receipts/screens; parser проверяет длину/SHA. Direct jobs/logs provider403 обойдён штатным gh run view после завершения run, не изменением ACL. Один client log EOF прочитан второй раз и проверен по SHA; это повтор чтения, не emulator.

Локального KVM нет, бесполезных local emulator installs нет. Delivery-only workflow не запускает signing/build/full tests и повторно использует exact cached bytes, но gate требует полный успешный verify/build/native и unchanged runtime.9Python negative tests PASS. Public release/repo opening/новые repo permissions не выполняются. Если delivery разрешён safety gate, ownerCLI создаёт только пустой PRIVATE draft; CI загружает ровно два APK и публичные diagnostics. Независимый raw download/cert/SHA обязателен. APK на Drive не загружаются.

Серверный инструмент main-only/defaultOFF, repository secret после8unit tests и pinned SDK install.8controlled tests + реальный Git-source23file dry-run PASS, live не запускался. Нужен отдельный approval; это не основание запускать общий production workflow/другие накопленные server diffs.

## Следующий запуск

Начать с PROGRESS.md, CI_17.json, acceptance/native/download receipts; не повторять G0 и успешный full verify ради отчётов. Установка на реальные телефоны и Google consent/15/30/60min — человеческий этап. Пока blocker независим, можно завершать проверяемые отчёты/скачивание, не выдумывая LIVE/OWNER PASS.
