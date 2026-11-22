# Проверка границ dormantinspect №25

Это automated/static/control review, не внешнее экспертное одобрение и не живой secretreadback. Сам workflow отсутствует в .github/workflows. Его запуск/передачаmain в этой задаче не выполнены.

|Граница|Факт|Остаток|
|---|---|---|
|Trigger|Только workflow_dispatch,main,hardcodedrepository,ownerиtriggeringowner,явнаяconfirmation;6structuraltests|РеальныйGitHubdispatcherNOT_RUN|
|Sources|Trustedmain sparsecheckout exactgithub.sha; actionfullSHAs; hardcoded scriptSHA доsecretstep|Нужны отдельныйownerreview/permission иmainreadback передактивацией|
|Privileges|contents:read,секреты только в1step;3необходимых repositorysecrets|Фактическаядоступность/валидностьсекретовNOT_RUN;403не повторялся|
|Secretmaterial|Base64decode bounded1MiB,private tempdir700/store600; passwordsenv notargv; childenvминимален;stderr/exceptiondetailsневыводятся|Cleanupпроверенcontrolled; реальныеkeystorebytesнеполучены|
|Operation|keytool-list+exportcert только publicDER,matchhistoricalcertSHA;PrivateKeyEntrylist|Не проверены keypassword/privatekeysigningusability; новыйcertневыдавался|
|Outputs|Fixedsmallpublic-result.jsononly,no rawDER/keystore/env/alias/password;upload metadataonly,uniquerunID+attempt,retention3days,overwritefalse|СамиGitHubartifactsNOT_RUN; никакойAPKвыдачи|
|Cleanup|TemporaryDirectory/finally доPASSreceipt,always-step удаляеттолько .sulfi25-cert-* вownRunnerTemp|EphemeralGitHubrunnerassumption,форсированнуюостановкуVMнеиспытывали|
|Productboundary|Нетnetwork/Google/Drive/API/sign/build/Gradle/ADB/userdatabaseопераций;defaultflags/dual-apkнеизменны|Не являетсяAndroid/native/serveracceptance|

Тестовыенаборыиспользуютsyntheticcanariesиmonkeypatchpublicdigestдляконтролируемыхbytes, **не** выданныйсертификат и **не**поддельныйREALPASS. Ошибкитулзы/cleanup всегдаBLOCKED; отсутствиевыводасырогоstderrважнеедетальногоstacktrace. ПубличныйcertSHAнеравенпровереннойспособностиподписатьAPK;инструментсамвыдаётNOT_PROVEN/NOT_TESTED/NOT_RUNдляэтихгейтов.

Передфактическойактивацией сноваverifymainSHA/paths/fulltwofilediff/scriptpin/actioncommits иownergrant. ПрирасхожденииSTOP;неподменятьинструментомпроверкуproductionserver,невыдаватьсекретыPR/fork/произвольномуref. РепозиторийPUBLIC;артефакттолькоpublicmetadata,безполныхисторийпользователей. Main/GAS/OAuth/ACL/signing/устройстванеизменялись.

Обнаружено реальное protected=false. Добавлен отдельный publictrustjob (permissions{},безcheckout/secretrefs), который явно отказывает на такомref. Inspectjob требуетtrustsuccess иgithub.ref_protected=true до выделения job; скрипт дублируетguard. RED1→GREEN23 иновыйactionlintPASS это проверяют локально. Отсутствие currentprotection не исправлялось изменением настроек и не скрыто. Protected workflow execution/secretreadback по-прежнему BLOCKED.
