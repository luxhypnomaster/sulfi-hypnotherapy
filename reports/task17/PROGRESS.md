# №17 — контрольная точка

Срез 2026-11-14T03:17:07+00:00. Не начинать G0 заново. Workspace `/dev/shm/sulfi17`, ветка `fix/task17-stable-auth-queue`, draft PR48 base PR47 НЕ merged. Latest Git HEAD может включать только отчёты/инструменты; app source **fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568**.

## Текущий CI

[https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43548636228](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43548636228), verify=success, candidate17=success, whole=in_progress/pending.

| Lane | Outcome |
|---|---|
|master25|failure|
|master26|in_progress|
|client25|in_progress|

APK27 НЕ выданы. Собранные бинарники остаются в приватном карантине до полного native gate и независимой проверки скачанных файлов.

Нельзя dispatch delivery пока run in_progress: concurrency прервёт его. Сначала дождаться actual3native gate и прочитать логи/JSON SHA через read_native_log.py. При новом fail не blind retry; screenshots/hostdiagnostics→подтверждённая причина или BLOCKED. Предыдущий run934 receipts сохранены в native_attempt_9340241, не подмешивать к финальным fbd.

## После CI

Если3native PASS: delivery_gate.py pins fbd/43548636228 и cache task17-quarantine-pair-fbd(fullSHA); требует successfulwholeCI+unchangedruntime+privateemptydraft. RootCLI может создать пустой private tag task17-qa-pair-27 targetfbd только после gate. Delivery-only cachedbytes, no rebuild/sign. Потом независимый rawdownload2assets, cert/pkg/version/config/SHA/DEXguard→APK_PAIR_17.json. Никакого APK в Drive. Если native BLOCKED, не выпускать APK и не выдумывать links.

Обновить финальные CI JSON,67matrix и отчёты, Drive raw SHA/size/parent readback. Уже8files IDs в DRIVE_FILES_17.json, обновлять их, не дублировать. Новые required acceptance/efficiency/readback дополнить. Новый folder17 https://drive.google.com/drive/folders/1fXpE8oU3HSE1g89jQppUxFPBgJLh7LqI; старый16 не менять. Не запускать старый /dev/shm/task17-write-reports.py: он затрёт свежие результаты.

## Разрешение / внешние блокеры

GAS6/дневник/OAuth/ACL/main/signing/userdevices не менялись. Серверный one-condition Diary patch подготовлен в SERVER_CHANGE_REQUEST_17.md. Для отдельного approval ровно3tool files: workflow alchemist-task17-approved-diary.yml + approved_diary_patch.mjs + test_approved_diary_patch.mjs. Не копировать вmain/не dispatchдоразрешения.8controlled testsPASS/23file dryrun, ONLYDiarydiff. GoogleJwt/Router feature нельзя deploy. Numeric admin currentversion пока NOT_RUN; public health source совпал с исторической6.

OWNER Google2accounts,15/30/60min, module/program→ContentLink→CLIENTofflineheard3tracks NOT_RUN. Private GitHub download требует loginownerChrome; второй телефон можно QuickShare без repoaccess. При installer conflict НЕ uninstall/clear/downgrade.

Инструменты: env -u GH_TOKEN gh (envtokeninvalid), pushcredentialhelpergh. SHM для крупных файлов; /workspace/task17-delivery для small Drive uploads. No KVMlocal, noagents. Логи gh run view после wholecompleted, прямой APIredirect403. Native rawchunks не выводить. Все документы17 сохранять в отдельной папке.
