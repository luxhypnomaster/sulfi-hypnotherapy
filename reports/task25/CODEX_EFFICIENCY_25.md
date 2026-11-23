# №25 — реальные повторы и основания

Приложения frozen737ea741636e9abe7c20353d9d5b8301cf44a5bb. Нет заявлений о процентах квоты. Полный итоговый Flutter574/2SKIP,Node114,Python53 исходной интеграции повторно не запускались после tool/report-only changes. Текущие инструменты68PythonPASS, actionlintPASS. Исходный compare baseline571→final574 был оправдан3новыми integration tests.

|Run|Тип|Новый факт / исправление перед повтором|
|---|---|---|
|45096588062|Certificate inspect|Один разрешённый public cert inspect PASS, не повторялся|
|45100730089|Build attempt1|Default setup-android tools obsolete; точный platform-tools исправленPR60|
|45101058374|Build attempt2|GET draft asset403; отдельный trusted GET-only baseline job capabilitiesPR61; app/sign jobs read-only|
|45101750589|Build attempt3|Ignored GeneratedPluginRegistrant отсутствует до pubget;PR62 генерирует locked deps, все31pin остаются mandatory; clean checkout воспроизведён локально|
|45102506987|Build attempt4|Шаллоу FlutterSHA безtag даёт0.0.0unknown;PR63 официальныйtag3.47.9+exactSHA, не spoof version|
|45103325755|Build/sign attempt5|SUCCESS, две actualsignedAPK. После этого ни rebuild, ни resign|
|45104377872|Native attempt1|CLIENT12PASS, actualupdate; transientAXдоказан healthyXML/screenshot;PR64 freshreadretry max3 без повторных UIactions + existingMasterReader|
|45106402826|Native attempt2|KVM permission race доAndroid;PR65 realFD/API12/createVM/udev settle доheavy downloads|
|45107294363|Native attempt3|KVM PASS, ADBclosed old28; новый monitor фактическогоchildexit, independent editions/failfastfalse, smaller physical framebuffer с тем же logicalframePR66|
|45157723278|Native attempt4|CLIENT15PASS; MASTER QEMU SIGSEGV; нетOOMkill/wrapper signals. Renderer/address UNKNOWN|
|45161085603|Diagnostic attempt5|PR67 bounded exception/module metadata; MASTER-only без repeatedCLIENT/36/delivery; не signing/build. Не повторять при NO_MINIDUMP_FOUND без новой evidence/hypothesis|

На main перенесены лишь отдельно проверенные operational files через обычные PR58–67. Parent app PR51–57 не объединялись. Secret-bearing job не исполняет feature app code; диагностический workflow вообще без signing secrets. Не повторялись закрытые Administration API/secret-list403, старый0stepsbilling, local emulator installation безKVM, production E2E ради отчётности. Состояние remote/артефактов проверялось read-only.

Локальный repeat45→68 оправдан расширением охвата всем QA-tool suite;68 включает45, складывать их нельзя. Успешный CLIENT API34 не запускать заново ради диагностики MASTER. Реальный модуль аварии UNKNOWN до metadata; swangle/lavapipe17 уже неудачны, наугад не повторять.
