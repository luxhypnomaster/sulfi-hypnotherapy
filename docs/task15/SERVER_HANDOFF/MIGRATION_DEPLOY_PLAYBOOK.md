# Следующее серверное ТЗ — сначала read-only, потом отдельное согласование

В №15 ничего на живом сервере не изменялось. Известный scriptId: 10jrwAx77N3tvs7k2Vwojip5-BpK1jjQcQ2dLeMczsaQL2hV8CCRx4Va0. Наличие edit-ссылки/включённого Apps Script API не доказывает авторизованный management API или права приложения.

1. С отдельным поручением прочитать metadata существующего «Сульфи — дневник»: owner/фактическое название, project source, deployments IDs/exec URLs/version/scopes, Drive file/folder ACL. Здесь эти неизвестные НЕ заполнены вымыслом. Не копировать bearer/secrets в отчёты.
2. Сделать частный versioned backup исходников/настроек/manifest/Drive draft/media index; записать hashes и владельца. Отдельно проверить текущие grants и открытый доступ по ссылке; изменение ACL потребует поручения. Не менять во время аудита.
3. Закрыть G3 exact audio migration на populated schema9 копии с history/audio attachments/templates/diary; crash/restart/rollback. No DROP/no data reset. Не включать live data в fixtures.
4. Утвердить platform/auth/storage, K008/K023 и endpoint adapter; сделать отдельный staging deployment/owner-only test data. Валидировать issuer/audience/roles/conditional writes/entitlement/idempotence/quotas/timezones.
5. Снять backup до переключения; проверить rollback к прежнему deployment без удаления новых blobs/новых revision rows. Forward correction вместо понижения Android versionCode.
6. Только после отдельного согласования подключать transport/config APK, затем выполнить DEVICE_PAIR_RUNBOOK. Контроль реальных записей/доступов/отзыва прав — отдельная приёмка, не результат Task15.

При 412: остановить outbox, показать конфликт, сохранить обе локальные правки; не генерировать автоматически новый If-Match. При частичной загрузке: незакреплённые blobs приватны до commit; GC после retention window и проверки refs. Падение процесса не делает частично видимую публикацию.
