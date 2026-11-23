# №25 — фактические проверки продолжения

Приложения `737ea741636e9abe7c20353d9d5b8301cf44a5bb` неизменны. QA-код `bf9818624b2a652724850d5d35d7e941ac82421f`. 335protected и31nativepins PASS; lib/android/server/third_party/assets совпадают с замороженной сборкой. Окончательный текущий набор QA-инструментов:115PASS/0FAIL, actionlintPASS. Пять новых snapshot-reader тестов включают реальнуюSQLite/WAL, несоответствие строк/файловыхSHA, traversal/ссылки, границы controlled-report и реальные .wav имена снимков.

Ранее574FlutterPASS/2SKIP, CLIENTdefine1PASS,114NodePASS и53исходныхPythonPASS подтверждены на тех же runtime bytes и сейчас не повторялись. SKIPlive/performance остаютсяSKIP. Промежуточные91/100/102/103/108/110/120 не являются дополнительными уникальными тестами;120 включает позже отвергнутый software-prototype.

|Run|Результат|
|---|---|
|45207789337|Реальный pinnedSDK37.3.10 в обоих35jobs; MASTER/CLIENT по5 раннихPASS, затемQEMU hostSIGSEGV вold28pause. Оба36/deliverySKIPPED.|
|45210761918|Наhost нетGDB. Fixture не установлен; upstreamactionboot после failedprehook, strongreadiness остановил тест. QEMUexit0.|
|45212351651|GDBустановлен, hostcontrol exit127; Android полностьюSKIPPED.|
|45213411298|Controlfatalбезstop: noprint отменялstop; AndroidSKIPPED. Исправлено по официальнойдокументации.|
|45214392456|MASTER35 17/17PASS, реальныйGDBcontrolPASS, actualQEMUexit0/signals[]. Независимо14 rawsnapshot×15таблиц/всеprivatefileSHA/schema9/integrityok. Single-diagnostic, не полный допуск.|
|45218835360|CLIENT35 15/15PASS+strict hostgate; независимо12 rawsnapshot×15таблиц. MASTER5PASS+BLOCKED наold28pause, GDBSIGSEGV+resumeerror. API36/deliverySKIPPED.|
|software/run14|NOT_DISPATCHED: source/DEXpreflight доказал неприменимость Intentflags кcached AudioService engine; PR76closedunmerged.|

Каждый использованный artifactZIP независимо скачан черезGitHubconnector, сверены providerSHA/размер/CRC. APK29 также проверены независимо отsigningjob: apksigner/aapt/SHA/ZIP/package/version/SDK/ABI/config/permissions. Не выдавать криптографическийPASS за доказанную сохранность на телефоне.

Снимкисозданы настоящей UIAPK28; supplementaryqueue/cache/settings вставлены только в synthetic AndroidSQLite и явно не являются Google/serverE2E. Reader открывает копии сmode=ro и сохраняет входныеtar. ВнешнийSAFZIP отсутствует вprivate-tar — только нативнаяSHA-сверка, без заявления независимогоrawчтения.

OWNER_PHONE, два настоящих Google-аккаунта, физическое прослушивание/микрофон, OEMlockscreen/livebackground29, native image/video diary attachments — NOT_RUN. Старыйowner24→25 rootcauseUNKNOWN. Производственные ограничения22/23 и неприменённый Diary17patch сохранены.
