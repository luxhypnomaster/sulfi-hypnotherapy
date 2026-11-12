# №16-В — пределы восстановления

- Физические SQLite/WAL/SHM/медиа владельца недоступны; ни наличие bytes, ни их удаление не подтверждено.
- Exact legacy-scope incompatibility доказана unit test, но соответствует только части дневниковых записей. Это не RCA всего инцидента.
- Google-authenticated APK24 UI diary creation и B/C account refresh сценарии требуют настоящего пользователя. Тестовые server replies не заменяют Google consent. OAuth Testing не обходится.
- Получение sandbox с единственного Android без ПК, установки новой программы или ADB-согласования пока не доказано. Способ доступа — blocker, не инструкция обещать run-as/adb backup.
- Приложение запускает существующие startup writes/collectors. Пока safety полного owner snapshot не доказана, даже diagnostic APK не распространяется.
- Настоящей destructive migration/recovery не выполнялось. Rollback данных владельца не испытывался и не обещается.
- APK24/25 и их исходники сохранены; они не резервные копии личных материалов. Новый номер сборки не подготовлен; отсутствие APK26 здесь преднамеренный STOP-SHIP.

Дополнение бинарного аудита: в обеих APK запрещены Android auto-backup/fullBackupContent и cloud/device extraction. Стандартная Google OS-копия не предполагается и не обещается; существование какого-либо внешнего/OEM архива нужно доказать отдельно.
