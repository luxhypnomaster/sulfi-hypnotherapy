# №16-Г G0 — зафиксированная база

Новая ветка fix/task16g-stabilize-programs от PR46 HEAD b0cb53f374e651be70df98e479be9605280177b3. PR45 HEAD24a51c5e47140131c9e8d214a60b841fa32179b5; общий ancestor exact APK25 source012f7f69b7ad99c0d44f2a442d9649aa1481117e. PR45 после него менял только отчёты/harness: lib/android/server/pubspec diff пуст. PR46 наследует весь production код PR45 и добавляет3Dart scoped-alias patch. Runtime tree равен CI c73daa697433c23086ffeeced75bd14b8632da77. Ни один PR не merged, main не меняется.

Пакет16G SHA9b86f75f5a26927078faa56dd61977077c62bcc7186878378c8d0703f518881e;7файлов прочитаны,6manifest SHA/length проверены,33criteria сохранены. Оригиналы docs/task16g immutable.

Решение владельца13.11: старые тестовые объекты НЕ восстанавливать. Root cause телефона UNKNOWN сохраняется в16V; новое задание защищает будущие данные и требует новой controlled/owner QA.

| Компонент | Существует / подтверждённая проблема / действие |
|---|---|
| Storage | app_database.dart schema9, support/library.sqlite, audio/diary_media/history_media. Default Android sqflite RW corruption handler destructive; startup collectors слишком опасны. Narrow pinned Android backend no-delete handler + derivative-copy validation before RW; startup GC исключить. Не менять schema9/IDs/paths |
| Diary privacy | PR46 exact verified MASTER legacy-subject alias сохранить; other account/CLIENT/guest deny |
| OAuth | один DiaryController + GoogleDiaryIdentity используется shields/profile; SDK singleflight refresh и network errors PR45. Адресно проверить race/refresh, не переписывать |
| Catalog | AlchemistCatalog/Install + shared TransferQueue, author receipts/hash/revision. Переиспользовать production Dart→JS controlled tests, проверить program dependency graph |
| Terms | Только user-visible Russian labels; internal template/table/API/IDs/capsule остаются |
| Server | Единственный GAS live6/старый diary untouched. Candidate16B server patch не deploy; нужна отдельная owner approval для rollout |

MASTER ru.sulfi.sulfi_hypnotherapy;CLIENT ru.sulfi.sulfi_hypnotherapy.clienttest;current0.4.17+25;certSHA2560b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6. Baseline immutableAPK SHA/source/asset IDs повторно не скачиваем: reused verified16V evidence. Нет permission/signing changes.

План: G1 narrow native no-delete callback + preflight COPY + no startup GC/negative tests; G2 address auth/catalog regressions; G3 label-only rename+legacy roundtrip; G4 один full regression и один осмысленный native upgrade attempt после local gates. Рискованные native failures блокируют выдачу APK; не считаем UI/device/Google tests PASS по unit fixtures.
