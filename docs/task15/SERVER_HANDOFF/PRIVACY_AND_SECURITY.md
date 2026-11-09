# Границы доверия

SERVER_READY:NO. UI mode/shield и SULFI_EDITION не дают серверную роль. В Task15 FakeProvider авторский grant задаётся тестовой доверенной стороной, а не кнопкой клиента. Это не реализация production identity.

Будущий сервер: проверить issuer/audience/subject/expiry и revocation, затем role/entitlement на EVERY publish/upload/draft/catalog/blob. Client не может получить private draft, произвольный Drive file, личный audio/history или другой reader state. SHA проверяет целостность, не авторство/подпись/оплату. Не раскрывать permanent Drive locator. Signed blob token должен быть короткоживущим, на конкретный digest/subject/size/expiry; запретить произвольный URL fetch (SSRF), traversal и логирование токенов. Сырые owner tokens/keystore никогда не находятся в APK/репозитории/отчёте.

Public projection — whitelist; extra неизвестного частного root остаётся локальным. publicExtensions — явный public compatibility namespace; автор обязан не помещать туда частные данные, сервер должен валидировать разрешённые extensions/лимиты. Старые необязательные поля сохраняются по namespace, неизвестный required schema version отвергается. Client не может подменить author grants extension-полем. LocalReadState reader UUID — идентификатор устройства, не account/OAuth, app_settings не экспортируется в content ZIP/public manifest.

Не привязывать выдачу blob к одному знанию SHA: нужен reachable authorized reference. Retain old immutable publications/refs for archive; GC только после доказанной ownership-модели. Task15 G3 block: exact старые/новые audio bytes одного ID не поддержаны всеми readers; никакого live GC/deploy до исправления.

Авторский APK сохраняет package/CI key, клиент получает отдельный .clienttest sandbox. App allowBackup=false; APK/Git не резервная копия пользовательского аудио. Диагностика в CI содержит только public cert/package/SHA. Физическая установка и реальные Google права не проверены.
