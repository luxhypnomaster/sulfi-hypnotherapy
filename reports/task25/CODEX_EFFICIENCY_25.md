# №25 — экономия и основания реальных запусков

Приложения frozen737ea741636e9abe7c20353d9d5b8301cf44a5bb. Нет выдуманных процентов квоты. Full Flutter574/2SKIP,Node114,исходныеPython53 не повторялись после tool/report-only правок; актуальный QA-tools набор76PASS, actionlintPASS. Группы45/68/70/75/76 перекрываются и не суммируются.

|Run|Назначение / результат|Основание следующего шага|
|---|---|---|
|45096588062|Разрешённый public certificate inspect SUCCESS|Не повторялся; owner independent JSON подтверждён, actual signatures позже проверены|
|45100730089|Build1 obsolete SDK tools|PR60 platform-tools fixed|
|45101058374|Build2 draft asset GET403|PR61 isolated trusted baseline GET-only job; app/sign read-only|
|45101750589|Build3 ignored generated registrant checked too early|PR62 locked pubget then all31pins, реальная clean checkout repro|
|45102506987|Build4 Flutter shallow SHA lacked version tag|PR63 official3.47.9tag+exactSHA, no version spoof/upgrade|
|45103325755|Build5 actual unsigned+existing-key sign обеих APK SUCCESS|После него rebuild/resign0|
|45104377872|Native1 CLIENT12PASS включая update, transient AX BLOCKED; MASTER cancel|PR64 bounded fresh read-only AX и existing MasterReader, реальный healthy subsequent XML|
|45106402826|Native2 KVM race before Android|PR65 udevsettle+realFD/API12/createVM before heavy downloads|
|45107294363|Native3 ADB lost old28pause, no exit evidence|PR66 actual childmonitor, physical720 same logicalframe, failfastfalse preserves independent edition|
|45157723278|Native4 CLIENT34full15PASS, MASTER old28SIGSEGV|PR67 bounded safe crashmetadata; dedicated MASTER-only diagnostic, no duplicate CLIENT|
|45161085603|Native5 MASTER16PASS: actual update/cold/dataPASS, last editor observerBLOCKED; QEMUexit0/no dump|PR68 existing reader→list→author QA navigation; controlledRED+strictAST; no appBack/rolechanges|
|45164078203|Native6 MASTER34full17PASS; CLIENT old28SIGSEGV/no dump|PR69 last AOSP35/36 platform hypothesis from successful18 +identical pause27/28 bytes|
|45166539406|Native7 MASTER35full17PASS, CLIENT old28SIGSEGV/no dump;36/deliverySKIPPED|STOP. No further same-platform/renderer experiments, no rebuild/signing|

Почему новый набор35/36 не выдаётся за14PASS: canonical25 asksAPI34/35/36whereavailable, исходный P0dataset/assertions/Javafixture/actualAPKbytes неизменны, CLI только добавляет35. Старые14failures сохранены, полный допуск всё равноBLOCKED. Scope-specific14PASS не подменил текущие4requiredgates.

Не повторялись закрытые Administration/secret-list403, старый0stepsbilling, local emulator installation безKVM, production E2E ради отчёта. Не выполнялись swangle/lavapipe, уже неудачные в17. Safe metadata не нашла dump — faultfunctionUNKNOWN, не новая выдуманная rootcause. Main: только обычные narrowoperationalPR58–69, actual base/head/hash/protection readback, не adminbypass claim. App PR51–57 не объединялись. Credentials не попадали app/Gradle/QA-коду.

Дополнительный actual APKcontent scan выполнен streaming, без распаковки личных данных/новых fullCI. Документы/матрица/целостность доставки проверяются отдельно; это не повод повторять574Flutter/Node114. После завершения native7 active CI нет.
