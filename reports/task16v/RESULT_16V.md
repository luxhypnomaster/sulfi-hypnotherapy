# №16-В P0 — BLOCKED / STOP-SHIP

**Материалы владельца не объявлены восстановленными. Новая Sulfi APK26 не построена и не выдаётся.** Подтверждён обычный MASTER24→25 без удаления приложения; состояние физических SQLite/WAL/SHM/media владельца UNKNOWN. Полный RCA исчезновения tracks+modules+drafts не установлен. Приёмка16/16-А/16-Б остаётся приостановленной.

## Выполнено

- Полностью прочитан актуальный пакет16-В, проверены8 manifest entries и ZIP SHA41a99244f4993aa63d61f24673b4984858ddc70dd5f5dff0fb1f3d2f9dae2684.
- Изолированная ветка `hotfix/task16v-p0-data-preservation` от **точного source APK25 012f7f69b7ad99c0d44f2a442d9649aa1481117e**, [draft PR46](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/46). PR45/старые APK/исторические отчёты сохранены.
- Независимый реальный readback обеих APK: одинаковые package/cert, code24→25; SHA/permissions/paths/schema/DDL/bootstrap/GC/owner filters/WAL/backend audit.17 DEX byte-identical; Flutter/SQLite .so identical; JNI только20 build-id bytes difference. Нет подтверждённой новой schema/path migration.
- Подтверждён отдельный фильтрационный дефект старых server-restored diary drafts: legacy `google:<subject>` не совпадает с новым account hash. Минимальный **source-only** patch3 Dart файлов,11 additions/3 deletions, только exact same server-verified MASTER alias, без DB/media rewriting. RED→GREEN и guest/CLIENT/other subject deny; исходные row/IDs/block order/media bytes равны. Это не объяснение всего owner incident.
- Подтверждён Android corruption-handler safety risk: в helper-only disposable DB default RW изменил corrupt bytes без exception; read-only noop сохранил SHA с ошибкой. Реальная pinned sqflite dependency24/25 использует default handler на RW. Owner corruption UNKNOWN. Безопасность нового стартапа поэтому не обещается.
- Read-only diagnostic для УЖЕ согласованной копии,10 локальных тестов WAL/rollback journal/crash/corrupt/missing/unchanged source. Он не подключается к телефону и не выполняет recovery/migration/GC.
- Настоящие Android UI attempts на immutable24/25; новые файлы реально импортировались в24, все неудачи setup сохранены. Ни fake Google role, ни SQLite INSERT в Sulfi для основного native сценария. В run43265893487 populated normal update24→25 и cold restart25 сохранили3audio/2modules/1template/1history, exact rows и media SHA/integrity. Authenticated diary/recorder24 full gate не пройден; это не опровергает owner incident. См.UPGRADE_REPRO_16V.md.
- Owner recovery plan по конкретным классам состояния, acquisition options для отдельного согласования, отсутствие auto-backup подтверждено binary manifest. Ничего на телефоне владельца не запускали/не меняли и не просили uninstall/clear/cache/downgrade/import/logout.

## Что проверено автоматически

**434 Flutter PASS /1 intentional live SKIP,3CLIENT PASS,46Alchemist Node PASS,24legacy Node PASS,analyze/format PASS.** Диагностический Python tool:10 local PASS; [последний полный CI](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43269227639) проверил9предыдущих Python cases. Exact app tree совпадает с этим CI source c73daa697433c23086ffeeced75bd14b8632da77. Native gate/Owner QA учитываются отдельно; зелёный unit CI не разрешает APK26.

## Что заблокировано

1. Полный native UI-created dataset с recorder24, двумя настоящими Google diary drafts и B/C Google lifecycle; реальные Google identities не имитируются.
2. Наличие и состояние original owner DB/WAL/media; законный phone-only способ forensic snapshot технически не доказан на его устройстве и требует отдельного согласия. Не просим ставить диагностическую APK.
3. Full root cause и доказанное восстановление СУЩЕСТВУЮЩИХ материалов. Legacy alias восстанавливает чтение определённых existing rows в controlled test, не доказывает owner recovery.
4. Permanent safe native corruption handling/review/snapshot/rollback и signed24→candidate26 полный native gate. **Не выдаём опасную APK** ради формального завершения.

## Где результат

Новые отчёты16V/матрица/evidence находятся в [прежней папке№16](https://drive.google.com/drive/folders/1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z). EVIDENCE_INDEX_16V.md и DRIVE_UPLOADS_16V.json перечисляют источники, CI и readback. Архив содержит только отчёты/синтетические evidence/source тестов, **не APK,не owner audio/SQLite/Google credentials**. Raw readback SHA проверяется отдельно. Старые отчёты не изменялись.

**Первый нужный шаг владельца после отдельного согласования — безопасно определить допустимый read-only доступ/снимок, не переустановка или импорт. Сейчас действий с телефоном не назначаем.** Владелец уточнил по памяти: пустые списки без ошибки. Это зафиксировано, но не доказывает физическое удаление или наличие данных.

Заключительный native follow-up43273089509 заблокирован неполным UI setup; не засчитан как upgrade. Последнее валидное core evidence — run43265893487. Полная матрица:35критериев,15PASS/16PARTIAL/4BLOCKED; итог задания BLOCKED, не процент готовности восстановления.
