# №16-В — изменения

Отдельная ветка `hotfix/task16v-p0-data-preservation` от immutable APK25 source012f7f69, draft PR46. PR45, main, server6/live deployment, старый дневник, Drive ACL/signing и APK24/25 без изменения.

1. Новый P0 packet docs/task16v, проверенный MANIFEST/ZIP digest; baseline/source/APK freeze/readback.
2. Native Android harness (manual exact-branch CI, без Google/signing secrets): реальные APK24/25, UI picker/import/recorder/module gestures, только read-only DB/media inventory. Никакого seeding SQL. Обязательная populated-baseline gate исключает ложный preservation PASS на пустой БД. Ошибка harness run1 сохранена, не засчитана в приёмку.
3. `readonly_inventory.py` анализирует только уже приобретённую согласованную копию в temp stage; 9 тестов включая WAL/rollback-journal/crash и отсутствие fallback на пустую БД.
4. Минимальный source-only патч 3 Dart файлов: DiaryApi scope predicate; AlchemistDiaryApi legacy google:<same verified sub> alias для MASTER; DiaryController использует predicate. Не меняет базу, аудио, роли, глобальные reader scopes, queue ownership, media paths или схему.
5. RED→GREEN regression с двумя subjects, CLIENT/guest, unchanged rows/media/block order; полный suite/Node/analyze/CI.

Никакая APK26 не построена/выдана; recovery пользовательской базы не выполнялся. Итог физической приёмки остаётся BLOCKED.
