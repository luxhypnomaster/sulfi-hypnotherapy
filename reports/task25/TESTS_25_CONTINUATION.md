# Дополнительные проверки №25, source5790139b0c2dc45363434451aa951b14b496d8fc

|Проверка|Результат|Доказательство|
|---|---|---|
|python3 -m unittest discover -s scripts/task25 -p test_*.py -v|23PASS:13inspect controlled +6workflow structural +4existing pins|logs/python25_resume.log|
|actionlint1.7.12 -oneline -shellcheck= -pyflakes= review_only/sulfi-signing-inspect25.yml|PASS0, source/schema/expressions/actions validation|SIGNING_INSPECT_LINT_25.json; logs/signing_workflow_actionlint25.log|
|Proposed two-filepatch on isolated mainarchive, gitapply--check/apply/reverse|PASS, ровно2новых пути, originalhashesrestored|SIGNING_INSPECT_DRYRUN_25.json|
|Sourcegate335protected/31nativepins +ancestry|PASS_SOURCE, no app/native/server drift|SOURCE_GATE_25_CONTINUATION.json|
|Fresh officialarchiveSHA/CRC/all11bytes +PR51/52/54/55/56metadata|PASS, unchanged|RESUME_INPUT_25.json|

Новые negativecases: untrustedrepo/ref/actor/re-runactor/event/workflow/confirmation не читают secretfields; missing/bad/oversized encoding; wrongcert; trustedCertEntry; subprocesserror/timeout/unexpectedexception; cleanup/temppermissions; no secret echo/cross-forwarding; no outputoverwrite/symlink; public-onlyartifact; immutableaction/toolhash beforecredentials. Только canary-fakes; ничего не выдано за настоящий privatekey/certPASS.

Линтер скачан в user-owned /dev/shm, без systeminstallation: officialGitHub releasev1.7.12 SHA2568aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8, checksumfile433028cf0ba3c42163ea1a668dedce30fcdbe84fe912b1a5e288c006eab8a4f5. Внешние shellcheck/pyflakes не использовались; все3embeddedPythonblock отдельно compile-checked в6workflowtests. PyYAML уже находился в среде; рабочийinspect script зависит только отstdlib и keytool, не отPyYAML.

Сохранены прежние fullFlutter574/2SKIP, Node114, Python53; полныйповтор без app/runtime изменений не выполнялся. Targeted23включает прежние4: дополнительных новых19, не повторно посчитанные76. Apps executable source737ea741636e9abe7c20353d9d5b8301cf44a5bb остаётся тем же, новый инструментsource5790139b0c2dc45363434451aa951b14b496d8fc. Тесты не доказывают работу GitHubsecret/самогоkeystore/пароля/реальныхAndroid/Google. Actualdispatch0новых, новыйrunnerprobe0, APK/native0; real signing/certinspection BLOCKED_OWNER.

Фактический RED→GREEN для нового инструмента: logs/signing_unprotected_RED_25.log (1FAIL, текущая main protected=false не проверялась); окончательный23PASS в logs/python25_resume.log после strictprotected trust/job/script guards. Вне этого малого исправления app/runtime не менялся. Actionlint после изменения сноваPASS. Полные Flutter/Node не повторялись. История предыдущих controlled22 иbaseline сохраняется в Git, но заключительный23 — актуальныйtool-snapshot.
