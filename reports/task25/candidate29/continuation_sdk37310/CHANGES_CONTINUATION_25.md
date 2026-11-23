# №25 — изменения продолжения 23.11.2026

Код приложений не изменён: 737ea741636e9abe7c20353d9d5b8301cf44a5bb. Две APK29 по-прежнему из единственного успешного build45103325755. Пересборок и переподписей в этом продолжении нет.

1. Проверена и закреплена официальная stable Android Emulator37.3.10 (build16970787, опубликован19ноября). Установщик проверяет размер, SHA1, SHA256, CRC, пути/типы ZIP, source.properties и фактическую версию бинарника. Есть восстановление предыдущего disposable SDK при ошибке. Гипотеза vendor SIGSEGV-fix обоснована release notes, но run8 её НЕ подтвердил.
2. Добавлен ограниченный fallback журналов ядра: только мониторируемый PID, basename исполняемого модуля и относительный offset. Без rawkernel/memory/stack; недоступность отражается честно. На фактическом CI kernel readback оказался недоступен.
3. Добавлена диагностика под GDB: регистрPC и executable mappings, без содержимого памяти и разворачивания стека. Сначала настоящий host-control; receipt связан с SHA GDB/script. GDB ставится только в diagnostic mode из подписанного Ubuntu APT; control расположен ДО emulator action. Обычный full-gate путь не использует GDB.
4. Исправлены подтверждённые ошибки самого QA-инструмента: отсутствие GDB на runner, upstream boot несмотря на ошибку pre-hook, сложный контрольный shell argv, документированная семантика noprint→nostop. Ошибки сохранены в отчётах, не превращены в приложение-PASS. RawGDB перенаправлен в /dev/null; итоговый сигнал читается из $_exitsignal.
5. Сохранены все оригинальные P0-проверки, Javafixture и последовательность кейсов; AST-тест нормализует только явно перечисленные инфраструктурные hooks/метаданные. Independent verifier требует актуальный SDK fingerprint и все четыре сочетания MASTER/CLIENT×API35/API36. Diagnostic mode не может выпускать tester artifacts.

Узкие операционные PR70–74 проходят обычный защищённый main PR-процесс с точным readback базового/итогового SHA и хэшей каждого файла. Main приложения и stack PR51/52/54/55/56/57 не объединялись. Не менялись productionGAS6, старый дневник, OAuth/ACL, signing key, видимость GitHub или реальные данные.

Публично сохраняются только санитарные отчёты, синтетические UI-скриншоты и структурированные доказательства. Raw synthetic database tar/исходные artifact ZIP сохранены локально, исключены из Git/Drive-пакета. APK не включаются в архив доказательств.

## Уточнение после реального run12

MASTER35 прошёл17/17 и независимыйrawreadback14×15таблиц; hostнаблюдательреальноработает, exit0/zeroSIG. Поэтому fullrun13 используетегоодинаковово всех4jobсдополнительнымstrictterminalgate(noSIG/noRestart/boundcontrol). Это заменяет первоначальныйрежим «GDB толькоdiagnostic»; отдельныйsingleMASTERdiagnosticфлагпо-прежнему не даётdelivery/API36. Originaldataset/assertions/renderer/APKunchanged. ПричинастарыхкрашейбезGDBUNKNOWN; никакогообъявленияобычнойhostreliabilityPASS. ПодробностиFULL_OBSERVER_REVIEW,PR75.
