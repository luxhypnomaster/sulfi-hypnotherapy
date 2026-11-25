# Решение владельца по STAGING на Hobby — точный предмет согласования

## Фактический блокер

ONREZA authenticated readback: Hobby, createCustomEnvironment.allowed=false, requiredPlan=PRO. Registry возвращает только Production. Explicit `nrz deploy --dry ... --environment staging --service-id <existingService>` →ENVIRONMENT_NOT_FOUND; deploy не создавался. Официальная документация допускает изоляцию разных окружений разными проектами, но общий запрет менять production не даёт автоматически считать slot типа Production разрешённым. Тариф Pro запрещён и не предлагается.

## Бесплатный в рамках текущего тарифа вариант для отдельного разрешения

Использовать стандартное окружение Production **только внутри уже созданного нового проекта `protocol22-staging`** как логический STAGING. Это не действующий GAS6, не main, не новый второй сервер и не существующий production-продукт. Отдельного Customenvironment не создавать. Не менять тариф/ACL/OAuth/ключи/пользовательские данные.

Существующий private паспорт фиксирует точные workspace/project/service/SQL-owner IDs. Цель — только этот project/service; не допускать глобальный fallback `staging -> Production`. Перед любой mutation обязательны новый readback идентичности/Hobby/паспорта, registry exact ID/type, observed serving (сейчас ни одной runtime версии не развернуто), проверка минимальных расходов/ограниченной нагрузки и официального safe-stop/scale-to-zero плана. Если параметры не совпали —STOP.

Первый допустимый scope после разрешения: health-only кандидат текущего runtime26, synthetic/auth publish по умолчанию disabled. Curated whitelist context, pinned onreza.toml, no auto-deploymain, без Google/DBcredentials. Сначала актуальный dry-run с точной целью, проверка dependency packaging и lifecycle safety; лишь затем boundedhealth/404/405. Это не разрешение снять KV ordering guard, открыть auth/publication, изменить существующие сервера или включить paidtier. ManagedSQL native binding остаётся отдельным условным шагом после проверенногоофициального binding contract; повторное бессмысленное TCPstart не выполнять.

Исходный код и фактические tests закреплены в DELIVERY_STAGING_26A.json/PR77; providerIDs только в owner-only паспорте. Изменение deployment selector с отказа на конкретный Production slot требует отдельного зафиксированного разрешения. Сейчас ничего не переключено.

## Точное разрешение, которого достаточно

«Разрешаю использовать стандартное окружение Production только в отдельном проекте protocol22-staging как логический STAGING на Hobby, с предварительными safety gates, без изменения действующих production/GAS6, тарифов, ACL и данных».

Новый токен, ПК и переход на Pro не нужны. Если такое исключение не разрешено, cloud deployment остаётся BLOCKED_BY_HOBBY_CUSTOM_ENVIRONMENT; локальныйкод/проверки/постоянные IDs сохраняются. Называть это BLOCKED_AUTH неправильно.
