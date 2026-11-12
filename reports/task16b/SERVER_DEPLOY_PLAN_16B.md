# №16-Б — план deployment, без исполнения

Дата: 12.11.2026. Ветка: `fix/task16b-auth-transfer-publication`. Кандидат приложения: `012f7f69b7ad99c0d44f2a442d9649aa1481117e`. Draft PR: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45 . Продолжение №16/16-А, не №17.

Действующий сервер: «Сервер Проекта Алхимик», version6, source1a0cf8e5a60144075eec793767953586bfa319a2. Новый Script/deployment не создавались. APK25 использует существующий endpoint и совместимый GAS6 envelope.

Кандидат меняет только диагностическую часть GoogleJwt.js и Router.js: разные signed-token ошибки и validated traceId/elapsedMs. Node security tests и offline GAS source assembly выполнены. Runtime adoption этих изменений BLOCKED_BY_OWNER_DEPLOY_APPROVAL; никаких попыток обойти эту границу.

После отдельного разрешения владельца на точный проверенный source SHA:
1. Повторно сверить private Script/owner, deployment ID/version6 и production target из сохранённой конфигурации. Сохранить current content + source digest и version6 rollback reference.
2. Использовать существующий trusted manual GitHub Actions + clasp путь, с repository CLASPRC_JSON только на main. Для переноса reviewed candidate в trusted workflow нужна отдельно одобренная интеграция; не исполнять feature-код с OAuth secret из PR.
3. Собрать candidate, сверить readback digest, создать только новую версию существующего Script и обновить тот же deployment; старый дневник не трогать.
4. Read-only health/negative token/role/metadata checks, затем отдельно разрешённый synthetic owner service smoke без пользовательских файлов. Новые фактические результаты записать в №16-Б.
5. При регрессии вернуть тот же deployment на version6; не удалять Drive объекты. App rollback — исправленная сборка с большим versionCode, не uninstall/downgrade, который может потерять данные.

Apps Script системный bottleneck на телефоне пока не доказан. Вариант A: текущий 256KiB JSON protocol, connection reuse и request-local metadata reuse только после отдельного измерения/ревью; запрет ослаблять ACL/SHA, межзапросный ACL cache не добавлять. Исследовательский PR42 остаётся отдельно, не merged.

Вариант B: защищённый resumable transport с owner-scoped серверными сессиями и отзывом доступа; Drive owner token не отдавать Android. Потребуется отдельный threat model, оценка лимитов/стоимости и явное решение владельца. Инфраструктура, платный сервис и прямой Android→private Drive доступ в этом задании не создавались. Прогноз ускорения не выдаётся за замер.
