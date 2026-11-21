# BASELINE №20 — 2026-11-21

Source dca81961146747adc4a3f06107012df429ed747a, PR50 draft (не merged), база PR49 363a0244ce761e317dd09a6c5cb366d1e8ba7315, PR48 506619a9aa88d47315cccf31f75f068195d3da84. Отдельная ветка feat/task20-catalog-vitrine. Исходные №18/19 сохранены по ancestry.

Архив Drive 1HIrUE_BuldbWU4zHOolE1R3RWCkRGp1J: 18949 байт; SHA acf08413f53314173f1c2f226f8b951900950ed993bded6a8b36815e04ec076f; ZIP CRC и 7/7 manifest hashes/lengths PASS. Все 8 файлов в docs/task20.

GAS Router dispatches catalog.* to Catalog.js; catalog.list собирает scoped страницы из индекса, готового HEAD/snapshot нет. AtomicStore/LockService и receipts существуют; их нельзя объявить SQL транзакцией. Новый контракт будет изолирован от Router и live deployment.

DiaryController.currentEntry использует diaryRotation без таймера; load сбрасывает rotation при новой записи. DiaryReadStore — app_settings diary_read:<reader,entry,cycle>, исторические аудио-интервалы и syncSnapshot/mergeSynced; AlchemistDiaryApi.synchronizeReads читает sync.pull и ставит sync.push в существующую очередь. Историю не удаляем. Новая локальная отметка будет отдельным совместимым namespace, без новых reader sync tasks; прежние tasks сохраняются.

AlchemistWorkQueue — единственная durable очередь app_settings, native №18 handles lease/retry. SessionController.sendCloudTask — маршрутизация; downloaded assets уже имеют SHA verification и UI resolver. SQLite schema9 сохраняется, app_settings additive records без destructive migration. HOME header height = width*185/683 capped .24 available; artwork/board/buttons сохраняются. Управление sticker в source отсутствует: добавить только утверждённый MASTER tab на существующей кромке. PreviewDiaryTransport использует общий PreviewPlayer.

APK28 source de408f1cae08fce16069a701d147a0b1064053ba остаётся прежним. Local/controlled предыдущих заданий не равны реальному Google/OEM. GAS6 по последним отчётам; live admin readback в №20 не запускался и не выдаётся за свежую проверку. Production deployment/Google/два телефона — отдельные BLOCKED/NOT_RUN.
