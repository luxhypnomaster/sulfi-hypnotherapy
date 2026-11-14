# №17 — renderer comparison и полный HEAD rollback

Итог: MASTER26→27 по-прежнему BLOCKED; APK27 НЕ выданы. Production apply/rollback не выполнялись. Main остаётся b88637a (только ранее разрешённые3файла inspect), текущие изменения только feature fix/task17-stable-auth-queue.

## Native: проверены две разные гипотезы, не повтор прежнего renderer

1. Run43586282741, driverfb108fb: API34, requested swangle (ANGLE+SwiftShader вместо прямого SwiftShader). SDK-help подтвердил поддержку до boot. MASTER26baseline install/probe ADB failed до создания данных; receipt baseline26/sourcefbd SHA checked. 2BLOCKED, не upgrade PASS.
2. Run43586934519, driverf08d074: API34, requested lavapipe (Mesa, исключён общий SwiftShader engine). SDK-help подтвердил поддержку. amstart baseline26 timed out55sec, ADB offline; baseline creation STOP, candidate27 не ставился.2BLOCKED. Поддержка advertised/запрошенные flags не объявляются доказательством успешного renderer или устранённой причины.

Оба прогона толькоMASTER26 с exactcachedfbd APK, без rebuild/sign/fullFlutter. Все UI/material/positivepause/rows/media/integrity/cold/draft критерии сохранены. При невозможности baseline создание останавливается, пустая БД не принимается за сохранность. Не изменялись APK/SQLite и данные владельца. MASTER25API34 PASS13 и CLIENT25API35 PASS12 не повторялись.

После сбоев process listqemu пуст, ADBoffline/refused, свободная память после завершения около7GB. Кернельные OOM/segfault сообщения не получены, это НЕ доказательство отсутствия OOM или причины crash. Guest crash log недоступен при offline; скриншоты недоступны. Native receipts+SHA decoder manifests в native_swangle/native_lavapipe. Не объявлять это дефектом миграции или доказанным исправлением инфраструктуры.

Дальнейшие одинаковые native прогоны остановлены. Новый диагностический подход перед любым следующим upgrade: управлять lifetime emulator process с сохранением exitcode/signal, monitor RAM/cgroup/ADB на host во время boot, контролировать ОС без Sulfi, затем отдельно immutable26 firstscreen. Проверить Crashpad pending dump metadata до cleanup (путь может быть глубже2уровней). Не публиковать guest memory/сырой minidump, извлекать только exception/module offsets. Нужен конкретный факт отличия host/emulator, а не перебор ещё одного renderer. Ни новая среда, ни такой forensic run в этом цикле не запускались. Локального KVM нет.

## Rollback: deployment и HEAD разделены

SAFE_HEAD_ROLLBACK_17.md содержит полный сохранённый план. Переключение deployment на6 само по себе не восстанавливает HEAD и не является полным rollback. Если HEADforeign — никакого автоматического push, даже по флагу exclusiveWriter. Если HEADнашpatch, restore base6 допустим только после отдельного согласия и реального окна без других writers, с повторным полным readback непосредственно перед записью и после неё. AppsScript не даёт atomic content CAS; без исключительного окна гарантировать отсутствие гонки нельзя. Если окно/состояние не подтверждены — BLOCKED, HEAD не писать.

Чистый feature-only rollbackHeadPlan различаетBASE6/OUR_PATCH/FOREIGN и никогда не пишет HEAD.11Node testsPASS, включая foreignactiveSTOP/foreignHEADpreserve. В main этот код не переносился. Старый main tool rollback переключает только deployment; запрещено представлять его полным восстановлением и запускать без нового согласования.

## Подготовка выдачи: fail-closed

Gate подготовлен для трёх конкретных successful native proofs (samefbd binaries/coretrees), а не ложного повышения исторического failedrun доPASS.11Python negative testsPASS: failedMASTER26/wrongdriver/missingproof/changedruntime/publicrelease/overwrite отвергаются. Первый mock fixture имел отсутствующие job IDs (7errors), исправлен; это не Android/app failure. Реальный gate GET кGitHub сейчас STOP на failedMASTER26 до release/cache/upload. Private draft27 не создан, delivery workflow не запускался, APK_PAIR_17.json отсутствует.

После будущего настоящего MASTER26PASS: привязать exact successfulrun/job/driver, проверитьпарыcoretrees и реальные receipts, privateDraftowner-only, затем независимый rawdownload/apksigner/aapt/SHA/pkg/version/config/DEXguard. Инструменты для проверки доступны; доPASS файл не предлагается пользователю. APK на Drive не загружаются.

## Затраты и границы

2cachedCI толькоMASTER26; большие469Flutter/3CLIENT/47Node/24legacy и сборкаfbd не повторялись. Producer/sourcefbd неизменён.11Node и11Python targetedPASS, overlap runs не суммируются как новые тесты. Проценты пользовательской квоты неизвестны. Старые25/26, отчёты16, GoogleOAuth/ACL/подпись/дневник/пользовательские данные не изменены. Административный inspect6 из предыдущего цикла принят владельцем; в этом цикле повторного OAuth/runtime/deploy не было. OWNER2phones/realGoogle/слышимоеofflineNOT_RUN.
