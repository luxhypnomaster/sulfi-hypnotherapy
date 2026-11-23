# №25 — оставшиеся препятствия

P0: полный native gate пары не пройден. На GitHub-hosted Android соSDK37.2.12 и37.3.10 встречается hostQEMU SIGSEGV при открытии часов в эталоннойAPK28. В run8 подтверждёнexit-11 безOOM/cancel. В run13GDB увиделSIGSEGV в executable mapping вне публичного allowlist, затем сам не смог продолжить; точная функция и причинаUNKNOWN. ДоAPK29 в неудачномMASTERсценарии дело не дошло. Это не доказанная ошибкаSQLite-миграции или новойAPK.

GDBконтрольработает и даёт отдельные полныеMASTER/CLIENT PASS, однако наблюдение не является устойчивым исправлением. API36 не запускался из-за обязательного predecessor-gate, а не объявлен недоступнымSDK. Складывать частичные результаты из разных прогонов или пропускать паузу/подменять UI вставкойSQL нельзя.

Официальные softwarelaunchflags здесь неприменимы без изменения engine initialization: AudioServiceActivity предоставляет cachedengine, AudioServicePlugin создаётFlutterEngine(applicationContext) безshellargs. ПодтвержденоactualAPK29DEX иlockedplugin0.18.19. PR76неmerged/run14неисполнен. Не менять и не переподписывать immutablebaseline28 ради искусственногоPASS.

ЛокальныйCloud не предоставляет/dev/kvm; локальные эмуляторы не устанавливались. Нужен стабильно работающий Android-тестовый узел либо отдельно согласованная приёмка на специальном тестовом устройстве с безопасной подготовкой. Основной телефон владельца не использовался. Прямо сейчас допуск установки на него не доказан.

Дополнительно: installedversionsUNKNOWN; настоящие MASTER/CLIENT Googlelogin, роли иphysicalдвухтелефонныйсценарийNOT_RUN. G3revisionmaterialization, полныйprivatebackup/restore, частьlargevideo/moderation/admin/live22/23 открыты; экспериментальныеflagsOFF. Коэффициентыweightedrating не утверждены, NOT_CALIBRATED; missingRubedoart не придуман. GAS6Diary17 one-conditionpatch не применён, productionrollback не выполнялся. Исходныйowner24→25UNKNOWN и старые отчёты сохранены.

Quarantinebuild45103325755/artifact14786149620 хранит две подписанныеAPK29 до2026-11-26 03:09:31UTC. Новых tester-artifacts нет. Не выдавать quarantine URL за допущенный установщик. НаDrive APK не загружались; в публично унаследованную папку отчётов помещаются только санитарные материалы.
