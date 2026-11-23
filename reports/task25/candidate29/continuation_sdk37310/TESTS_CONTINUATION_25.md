# №25 — проверки продолжения

## Неизменная база приложений

Appsource737ea741636e9abe7c20353d9d5b8301cf44a5bb. Свежий read-only source gate подтвердил335 protectedfiles,31nativepins и ancestry всех зависимостей. Деревья lib/android/server/third_party/assets совпадают с замороженной сборкой. PR51/52/54/55/56/57 OPEN DRAFT UNMERGED.

Ранее выполненные574FlutterPASS/2SKIP, CLIENTdefine1PASS,114NodePASS,53исходныхPythonPASS, analyze/format и фактический dual build остаются доказательствами этих же runtime bytes. После только QA/report изменений они не запускались заново. SKIP/live gaps не превращены в PASS.

## Новые локальные проверки

- Текущая QA-tools группа:110PASS,0FAIL; actionlint1.7.12PASS. Промежуточные91/100/102/103/108 — перекрывающиеся наборы, не складывать.
- ZIP-тесты: размер/hash/CRC, traversal/дубликаты/symlink/special-files, обязательные vendor files/version, безопасный install/restore lifecycle, отказ signing-context, строгая readiness.
- Hostmetadata: только разрешённые PID/module/fileoffset, недоступность dmesg, отсутствие сырых дампов/лога ядра/памяти/стека, diagnostic defaultOFF и невозможность доставки/API36 из diagnostic mode.
- Host-control: регистрPC/executable maps без absolute ASLRадресов; false/missing/mismatched receipt failclosed. Реальный локальный Pythoncontrol (не mock): SIGUSR1/2 игнорируются, SIGSEGV даёт exit-11, stdout/stderr пусты, core отключён. Это Linux-процесс, не Android и не Google.
- Strong AST comparison сохраняет исходные P0 assertions/cases/Javafixture после явных разрешённых инфраструктурных отличий.

## Фактические CI-прогоны

|Run|Результат и граница доказательства|
|---|---|
|45207789337|Полный35/36 запрос; обе actual SDK37.3.10 receipts PASS; подпись/байты29 PASS. MASTER35 и CLIENT35: по5 раннихPASS, hostQEMUSIGSEGV на pause старой28 до upgrade. НетOOM/cancel;36/deliverySKIPPED. Independent validatorBLOCKED.|
|45210761918|GDB отсутствует. Fixture не начат; upstream action boot-нулAndroid, strong readiness остановил install. QEMUexit0. Не считать nativePASS или повтором fatal.|
|45212351651|GDB установлен, host-control exit127. Обязательный внешнийpreflight заблокировал все Androidшаги.|
|45213411298|Control прошёл до fatal, но GDBpolicy ошибочно подавляла stop (noprint→nostop). AndroidSKIPPED. Ошибка инструмента подтверждена официальной документацией.|

Окончательный диагностический результат добавляется отдельным RUN12_RESULT после терминального readback, а не по зелёному предварительному step. Ранее полные MASTER34/35по17PASS и CLIENT34 15PASS сохранены; они не подменяют четыре обязательных гейта одной допущенной пары.

Обе APK29 неоднократно независимо скачаны и проверены apksigner/aapt/SHA/ZIP/package/version/ABI/config/permissions; новые run readback используют те же неизменные bytes. Подпись сама по себе не доказывает безопасное обновление.

Физические устройства, настоящий Google-вход двух аккаунтов, OEMблокировка/долгий live background transfer29, микрофон/акустическое прослушивание, native image/video diary attachments — NOT_RUN. Частичные №22/23, неизменённый production Diary17patch и первоначальный owner24→25 UNKNOWN сохранены в ISSUES.

Run12 отдельно подтверждён:17/17MASTER35PASS, GDBcontrolSIG11/PCmodulelibc реальныйPASS;actualQEMUexit0/signals[].14rawnativeAndroidsnapshotкопий×15SQLiteтаблиц independentlyread-only/hash/integrity/schemaPASS. Не полныйдопускпары; rawБДнепубликуются. Текущий полныйrun13 45218835360 используетновыйstricterhostObserverproof; завершениеещёожидается.
