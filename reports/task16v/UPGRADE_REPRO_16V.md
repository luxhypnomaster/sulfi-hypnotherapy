# №16-В — native upgrade, строгое разделение доказательств

**Полный сценарий владельца пока NOT_REPRODUCED / BLOCKED. Owner bytes UNKNOWN.** Не принимать прежний16-Б injected SQLite PASS за UI-created acceptance.

## Стенд

Existing exact signed MASTER24 asset736432720 SHA a242d8222af27c936f44c86b47e2cf674c3789072c3a7cac9aa4bba3afe3cda1 → MASTER25 asset738283668 SHA d0c8704673434b43fc7ceebbaceff4c3f2075a780964063c06dffeed03bc50c9. Package/cert identical; каждый CI скачивает старые APK read-only и проверяет hash. Никакой новой Sulfi сборки, downgrade или uninstall. Android35/x86_64/KVM, disposable GitHub runner; GMS accounts не добавлялись. Native helper/IME — отдельный ephemeral test package без Google/DB-content injection в Sulfi.

Основной сценарий использует настоящий Android DocumentsUI picker, Flutter dialogs/real IME input, module editor, approved clock gesture, structure/template, session and SAF capsule UI. Harness не делает INSERT/UPDATE в библиотеку приложения. Копии SQLite/WAL/SHM читаются для counts/IDs/full payload/media SHA/integrity. Raw owner materials отсутствуют. Если setup неполон/эмулятор теряется — native gate BLOCKED и exit2, не false PASS.

## Сохранённые попытки, почему не засчитываются

| Run | Истинный результат |
|---|---|
|43254064338|Install24 PASS, но ошибка tap Element bounds не создала данных. Empty-baseline upgrade/cold assertions INVALID. Исходный JSON сохранён; не в приёмке|
|43255433079|Полный CI регрессий PASS. Native picker/timing и editor setup BLOCKED, эмулятор отключился; нет populated upgrade. Screens preserved|
|43256990236|Invalid workflow duplicate if at registration; guard исправлен; не app failure|
|43257069432|Cancelled obsolete idle-probe diagnostic, не acceptance|
|43257458828|Compiled real UiAutomation probe. Captured media-card PREVIEW/YouTube Music instead of actual filename; setup BLOCKED, gate failure correct. CI regressions PASS|
|43259518712|Три файла действительно импортированы через UI24 (screens show1/2/3 audio), но test text action не изменяла название; assertions обнаружили mismatch. Recorder/эмулятор отключились до upgrade; no preservation proof. Отдельный helper-owned native corruption probe CONFIRMED, не Sulfi DB|

Исправления теста не объявляются исправлениями приложения. Legacy naming/real input readback, populated baseline gate и SHA-verified chunked evidence предотвращают ложный успех. Artifact quota не обходили удалением старых артефактов; evidence сохранено из private CI logs.

## Что обязательно остаётся вне доступной автоматизации

- Неизменная connected APK24 закрывает авторский diary UI до настоящего Google MASTER. Создание текстового/мультимедийного draft через UI этого APK без настоящей авторизации BLOCKED. Подставлять server role/JWT/SQLite rows нельзя, и этого не делалось.
- Нужны реальные Google B/C/refresh и чужой аккаунт, полный recorded24 dataset, candidate26 native same-cert upgrade, физический owner recovery. Их нельзя заменить434 Flutter tests или helper corruption fixture.
- Даже populated controlled update24→25 PASS не доказывает сохранность телефона и не разрешает APK26 без полного RCA/backup/review.

Актуальный последний результат и inventories дополняются отдельно ниже, без переписывания исторических неудач.

## Реально полученный populated core proof — run43265893487

Через UI **именно APK24** созданы3аудиотрека, из них2с одинаковым названием и разными ID, модуль «Индукция Элмана вариант 2» с3различными audio IDs, второй модуль с4секундной паузой,1template/current draft с фазой/модулем и1настоящий interrupted session run. Никакого SQL seeding. Реальные media paths/SHA/durations и полные payload в before/after/cold inventory.

`native_update24_to25` и `cold_restart25` PASS: normal `adb install -r` exact25 без uninstall, все указанные строки неизменны,3media SHA равны, PRAGMA integrity_check=ok/schema9. Отдельные INVENTORY_BEFORE24_UI_16V.json, INVENTORY_AFTER25_UI_16V.json, INVENTORY_COLD25_UI_16V.json, INVENTORY_DIFF_UI_16V.json; основной NATIVE_UI_UPGRADE_RUN8.json сохранён.

Не делать ложных выводов из нулей: diary_author0 помечен NOT_EXERCISED_EMPTY, а не preservation PASS. Recorder24 не создан. Экспортная капсула не сохранена из-за uppercase SAVE selector. История действительно существует и сохранилась, но её UI-case ошибочно ожидал Home вместо правильного автоматического перехода в interrupted history. Post25 module visibility-case ошибочно требовал точный label без Tab suffix. В source-harness эти ожидания исправлены, app код не менялся.

## Остальные попытки / blockers

Native9 compile-only failure второго тестового APK (aapt manifest basename), не product build/data proof; исправлено и оба helper локально пересобраны.
Native10 43268899509 с первым шагом recorder24 снова привёл к adb offline, поэтому gate BLOCKED, обновление с этой неполной базой запрещено. Это воспроизводимое ограничение данного стенда; **не** диагноз физического recorder и не сохранность записанного файла. Повторять этот недоступный аппаратный шаг бесконечно не будем; доступные core проверки выполняются независимо.

## Заключительный follow-up — run43273089509

Source7de676e, completed FAILURE: первые два UI imports24 PASS, затем CANNOT_RETURN_HOME; populated before gate не выполнен. UPDATE намеренно BLOCKED с STOP_SHIP_INVALID_UI_BASELINE_NO_UPGRADE_PROOF; cold comparison BLOCKED, поскольку не подтверждена фактическая APK25. Это сбой стенда, не app data-loss reproduction и не preservation PASS. NATIVE_UI_UPGRADE_RUN12.json + SHA-verified screenshots/XML сохранены. Повтор native-corruption probe на helper-only DB вновь подтвердил default-handler risk.

Run11 43271209292 импортировал файлы, но fallback ввод добавлял имя к исходному; его import flags не засчитываются как требуемое совпадение названий. Strict visible-field assertion исправлен в driver. Ни run11, ни run12 не заменяют валидный populated core run8. Больше повторов недоступного recorder/нестабильного стенда не назначаем.

**Итог:** NATIVE_UI_UPGRADE_CURRENT.json остаётся run8. Контролируемые3audio/2modules/template/current/history сохранены при exact24→25 и cold restart; полный authenticated diary/recorder/capsule/native candidate26/owner recovery НЕ пройдены. Новая Sulfi APK26 не построена.
