# №25 v1.0 — PARTIAL, source integration готова, APK заблокированы

Кодовый source `737ea741636e9abe7c20353d9d5b8301cf44a5bb`; ветка feat/task25-integration-native-gates; [draft PR57](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57) на фактическом PR56 d0a6d9a6daaeca215992e0b771a2332502ecee41. PR51/52/54/55/56 остаются OPEN DRAFT UNMERGED. [Отчёты](https://drive.google.com/drive/folders/1o5g7O5jm5yw2URWVCIhEJrbP40ddMPwn).

|Граница|Результат|
|---|---|
|INTEGRATION_READY|**YES — SOURCE/LOCAL ONLY**. Все доступные source/tests/ancestry gates пройдены|
|P0_SOURCE_COPY_GATES|PASS_LOCAL на синтетических SQLite/files/capsules; не гарантия ownerAndroid|
|NATIVE_CANDIDATE_MASTER|**BLOCKED_ENV/BLOCKED_OWNER**, APK отсутствует|
|NATIVE_CANDIDATE_CLIENT|**BLOCKED_ENV/BLOCKED_OWNER**, APK отсутствует|
|OWNER_DEVICE_ACCEPTED|**NOT_RUN**, никакой установки/доступа к телефону|
|SERVER_PROD_READY|**false / BLOCKED_LIVE**, незакрытые №22 сохранены; GAS6 не меняли|

ZIP19023B SHA256 cc1264a1afba03ff7ebb781702106d1162fdab16b6f9c9ba3b2b41ff36bba4b9 совпал с независимым pin оперативного паспорта. Прочитаны все11файлов, CRC/10manifest hashes+size/55unique criteria PASS. Проверены remote heads/ancestry, selected base56 содержит весьstack. Runtime335files и31native/config pin не изменены. Ни одной новой подтверждённой runtime ошибки, поэтому рискованных правок приложения нет.

Добавлены3интеграционных теста: программа MASTER→CLIENT с3AAC/паузами и templateID; author revision change не меняет установленный состав; completed offlineFSM/frozen history; user-paused queue и точные медиа/8таблиц после холодного headless copy-open. Candidate backend доступен, но двеedition не используют его приOFF. Read-only source checker и4adversarial tests защищают исходники от drift/symlink/pathescape без перепривязкиpins.

Итог: **574Flutter PASS /2SKIP /0FAIL**, дополнительный compiled CLIENT1PASS, Node79+24legacy+11security=114PASS, Python53PASS, analyzerclean, format238/0changes, StorageSafety Android36 Java typecompile PASS. Полный финальный suite выполнен после freeze; targeted counts не прибавлены дважды. Подробные команды/ограничения TESTS_25.md.

Один безопасный runner probe [45048084597](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45048084597) SUCCESS9steps, без секретов и GAS writes. Это **не** CI текущего Fluttersource. В Cloud нет protected signer/emulator/KVM, список repo secret names недоступен403. Существующий доверенныйmain workflow pinned APK24/private-only; новый current-source signing workflow недоступен без отдельного review/main разрешения. dual-apk production gate неизменен. Нативная сборка/установка/подпись не имитировались, ключ не создавался.

Матрица55: ALREADY_DONE=1, BLOCKED=7, NOT_RUN=1, PARTIAL=3, PASS_LOCAL=21, PASS_POLICY=4, PASS_READONLY=1, PASS_REPORT=6, PASS_RUNNER=1, PASS_SOURCE=10. PASS уровни SOURCE/LOCAL/POLICY/REPORT/RUNNER/READONLY не эквивалентны PHONE/GOOGLE/NATIVE. Native критерии явно BLOCKED, не выданы за готовую APK. APK_INFO/READBACK сознательно нет; вместо них APK_BLOCKER. Нет publicrelease/tag/merge/deploy/OAuth/ACL/signing/userdata изменений.

Следующий безопасный шаг — review PR57 и доступная доверенная signing+Android среда для точного approved SHA (SAFE_NATIVE_PLAN_25). Затем два native normal-upgrade gates/независимый binary readback; только после ихPASS выдача владельцу. Ничего устанавливать сейчас не требуется. Старый owner24→25 диагноз UNKNOWN и незакрытые №22/23 не переименованы в исправленные.
