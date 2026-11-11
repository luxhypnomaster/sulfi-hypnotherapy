# Автоматическое создание и развёртывание «Сервер Проекта Алхимик»

## Что уже есть — и чего нет

Скриншот владельца от 10.11.2026: Apps Script dashboard settings показывает **«API скрипта приложений Google Apps — Включено»**. Это снимает ОДНО ограничение: управление скриптами через API разрешено на уровне аккаунта. Но Google отдельно требует, чтобы конкретное приложение получило user OAuth grant со scope для записи; Drive connector read/export уже работал, но не доказал `drive.scripts`/`script.projects`/`script.deployments`. В задаче №9 из среды Codex были 401 без credential. Никакой новый consent/credential нельзя выдумывать.

### Официальные варианты — выбрать рабочий, не плодить проекты

**РЕШЕНИЕ ВЛАДЕЛЬЦА ПОСЛЕ НАЧАЛА №16:** основной delivery path — **Codex → GitHub repository → GitHub Actions → `@google/clasp` → Google Apps Script**. Не требовать OAuth в сессии самого Codex. Подробности: `GITHUB_ACTIONS_DEPLOYMENT.md`. У пользователя на телефоне был consent Google, но `localhost:8888` callback не вставлен в Cloud Shell: **clasp login НЕ подтверждён**, а GitHub Secret `CLASPRC_JSON` ещё не подтверждён. CI и CD workflow разрабатывать уже сейчас; не обещать cloud deploy без секрета и не просить ПК.


1. **Apps Script API (предпочтительно для создания+редактирования+развёртывания)**: REST `projects.create` с точным `title="Сервер Проекта Алхимик"` требует OAuth `https://www.googleapis.com/auth/script.projects`; затем `projects.updateContent` целиком со всеми `SERVER_JS`, `HTML` и `appsscript.json`; затем `getContent` сравнить имена и SHA, `versions.create`, `deployments.create` с разрешениями и exact version; для deploy отдельные `script.deployments` scopes; доказательство `/exec`. Справка https://developers.google.com/apps-script/api/reference/rest ; https://developers.google.com/apps-script/api/how-tos/enable .
2. **Drive Apps Script source import**: для standalone source файлов при разрешенном OAuth `https://www.googleapis.com/auth/drive.scripts`, см. https://developers.google.com/apps-script/guides/import-export ; импорт source возможен, но **НЕ создаёт сам по себе version/deployment и не даёт права исполнения**. Для развертывания всё равно нужен авторизованный management API или иной законный инструмент. Нельзя путать обыкновенный Drive `update_file` для документов с гарантированным управлением `application/vnd.google-apps.script`.
3. **clasp внутри GitHub Actions — выбранный основной маршрут**: GitHub runner получает OAuth только из существующего GitHub Secret `CLASPRC_JSON`, созданного после полного `clasp login` владельца. Codex не обязан иметь OAuth. Без Secret — `GITHUB_SECRET_MISSING` и только tests/workflow/code. Не требовать отдельного компьютера, ручной вставки JS, пересылки кодов или refresh tokens в чат. Не экспортировать секреты ChatGPT Google Drive connector.

### Действия в ЭТОМ ЖЕ запуске Codex

- Сначала определить read/write capabilities конкретного executor; не повторять многократно одинаковый 401. В наличии действительный OAuth grant? Тогда создать один новый private standalone проект точного имени, проверить существование имени/ID и не плодить дубли при restart; приватные Drive-папки, Script Properties, полная загрузка кода и manifest, readback hash, version/deployment, permissions, live health. Продолжить full E2E с двумя APK.
- Если отсутствует write grant: **НЕ** создавать только пустой shell и НЕ записывать что cloud ready; написать/протестировать все файлы полного сервера в Git, Flutter transport, APK и необходимый deployment script, сохранить явные `CLOUD_WRITE_BLOCKED`+реальный HTTP error. Для возможного согласия владельца допускается только законная процедура, действительно доступная с телефона — НЕ требование ПК/Apps Script editor. Никакой insecure token workaround.
- Не трогать старый «Сульфи — дневник» с известным scriptId `10jrwAx77N3tvs7k2Vwojip5-BpK1jjQcQ2dLeMczsaQL2hV8CCRx4Va0`; владелец сам удалит его по желанию.
- Если всё удалось — развернуть реальный новый Web App проект, без отдельных test staging/PoC проектов. На живом сервере после безопасной ACL/bootstrap сделать краткие внутренние smoke с контролируемыми медиа и убрать их из видимого каталога; сразу перейти к полноценной публикации/каталогу. Никаких небезопасных публичных авторских действий ради первого успешного ответa.
- Выдать только проверенные project scriptId, deploymentId/version, рабочий `/exec`, CI build link; private folder IDs не делать публичными. Список неработающих capabilities и требуемых scopes обязателен.

## Нельзя обходить

- `enable` в Google UI ≠ OAuth access token. Без согласия пользователя приложение не может создавать/изменять скрипты от его имени.
- Apps Script сам требует авторизации на Drive scopes при первом выполнении от owner's identity. Если появляется official consent, owner может подтвердить на телефоне; если такого поддерживаемого пути в среде нет, нельзя утверждать, что он есть.
- Не делать существующий/new скрипт `anyone: writer`, и не публиковать личное медиа публично для простоты подключения.
