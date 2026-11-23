# №25 — оставшиеся препятствия после продолжения

Общий статус PARTIAL; обеAPK BLOCKED. Весь исходный список ISSUES_25.md сохраняется. Новая информация не закрывает ни Google/production22, ни nativeP0, ни старый owner24→25 UNKNOWN.

- BLOCKED_TRUST: GitHub main protected=false. Реальный запуск с signing credentials не выполнялся. Новый инструмент отказывает до secretjob. Настройки защиты/ACL/main не менялись. Нужен отдельно согласованный защищённый путь; ownergrant на2files не даёт права менять branchprotection.
- BLOCKED_OWNER: inspect workflow отсутствует в активной .github/workflows и не находится наtrustedmain. Полный diff2file подготовлен, actionlint/control/copyapply проверены. Отдельного mainразрешения пока нет.
- BLOCKED_CREDENTIAL_READBACK: настоящиеrepository signing secrets/сертификат/пароль ключа не проверены; Cloudbindingsпусты, прежний403не повторялся. Никакихplaintextcredentials/новыхkeys.
- BLOCKED_NATIVE: emulator/KVM/signingсреда отсутствует. Никаких APK/AAB/Gradle/install/ADB/устройстввладельца. Послеcertinspect ещёпотребуются build+native normalupgrade+independentreadback.
- Прежние43PASS+1ALREADY_DONE/7BLOCKED/3PARTIAL/1NOT_RUN остаются ровно на их уровнях. НовыйguardснабжёнRED→GREEN, но это не physicalPASS.

Первый безопасный шаг: review точного двухфайлового предложения и решения по защищённой signing-среде. Без отдельного конкретного разрешения не переноситьфайлы вmain и не менятьprotection. Не выдавать старуюпару28 за новую25; не проситьuninstall/clear/downgrade/реальныеDB.
