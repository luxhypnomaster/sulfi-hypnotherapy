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
