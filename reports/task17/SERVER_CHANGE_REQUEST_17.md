# №17 — подготовленный серверный diff, НЕ развёрнут

Действующий сервер не изменён. Контролируемый прогон точного Diary.js из source GAS6 `1a0cf8e5a60144075eec793767953586bfa319a2` отклоняет публикацию с заголовком и коротким сообщением без блоков (`EMPTY_ENTRY`). Валидация нормализатора допускает пустой список, но `entry.publish` требует блок. Это отдельная причина от Google/очереди. Оригинальный авторский текст не превращается в кнопку или фиктивный блок.

Кандидат меняет только условие EMPTY_ENTRY в `server/alchemist/src/Diary.js`: непустое `message.trim()` также считается содержимым. ACL, Google, роли, ID, документы и существующие ревизии не мигрируются. Прежний published snapshot остаётся до commit. Изменённый код проверяется локально; успешный controlled тест не означает применение к GAS6.

Для deployment требуется отдельное прямое разрешение владельца. До него короткая запись блокируется сервером; очередь/черновик сохраняются. Развёртывать всю накопленную серверную ветку автоматически нельзя: в ней также есть более ранние неопубликованные изменения GoogleJwt.js/Router.js. Безопасный план — создать проверяемый bundle ровно от deployed source + этот узкий diff, сравнить весь файловый manifest, использовать существующие Script/deployment, затем read-only health и отдельный разрешённый smoke. Не создавать второй сервер.

Rollback: переключение существующего deployment обратно на неизменяемую version6 без отката/удаления Drive-данных. Разрешение на это также не предполагается заранее. Android rollback выполняется исправленным APK с большим versionCode, без downgrade/uninstall/clear. Полный diff и проверки будут приложены перед запросом разрешения; deployment в этой работе не запускается.

## Точный план применения после разрешения (сейчас НЕ запускать)

1. Доверенный ручной workflow только на main, без PR/fork/feature доступа к CLASPRC_JSON; pinned clasp3.4.1. Действующий production workflow не запускать как есть: он собирает всю main и вызывает bootstrap, что не соответствует этому узкому изменению.
2. Google Apps Script API read-only: `projects/{existingScriptId}`, `projects/{existingScriptId}/deployments/{existingDeploymentId}`, `projects/{existingScriptId}/content?versionNumber=6`, `projects/{existingScriptId}/content`. Проверить точное имя «Сервер Проекта Алхимик», прежний pinned Script/deployment, owner и отсутствие изменений HEAD относительно version6. При любом несовпадении STOP до push; не создавать Script/Drive-папки. Никакие ACL/scopes/config свойства не менять.
3. Подготовить приватный временный bundle из ВСЕХ реально прочитанных version6 files, сохранить `InitialConfig`, manifest и vendor. Изменить только `Diary` по приложенному `SERVER_DIARY_PATCH_17.diff`, проверить SHA старого и нового файла по SERVER_DIFF_INVENTORY_17.json. Сравнить полный manifest: остальные файлы byte-identical. Не подмешивать GoogleJwt.js/Router.js из feature-ветки.
4. Существующая команда clasp, строго с прежним scriptId: `clasp push --force`, затем GET content и полная проверка SHA. `clasp create-version` создаёт новую immutable version, затем `clasp create-deployment --versionNumber NEW --deploymentId EXISTING` обновляет именно существующий endpoint. Не вызывать create-script, bootstrap/system.initialize, Drive permissions API или создание второго deployment. Исходные version6 и private data остаются.
5. Проверить GET deployment: actual numeric NEW, прежний endpoint/executeAs/access. GET runtime health. Сохранить version/manifest SHA отдельно: InitialConfig sourceSha остаётся историческим baseline, поэтому один runtime sourceSha НЕ доказывает отсутствие/наличие этого патча. Авторизованный короткий smoke только после отдельного согласия на публикацию тестовой записи либо ручная проверка владельца.
6. Rollback-script: `clasp create-deployment --versionNumber 6 --deploymentId EXISTING` с readback deployment и health. Никакого удаления новой immutable version, пользовательских записей или Drive-байтов. При неопределённом результате не повторять слепо; сначала GET deployment.

Необходимое разрешение касается именно one-condition Diary diff и строго ограниченного доверенного workflow/применения к существующему deployment. Оно не распространяется на объединение всего PR48, другие изменения main, ACL/OAuth, bootstrap, удаление данных или старый дневник. До разрешения весь production write STOP WAITING_APPROVAL.

## Подготовленный исполняемый вариант для просмотра

На feature-ветке подготовлены ровно три файла для отдельного согласования (в main НЕ копировались):

- `.github/workflows/alchemist-task17-approved-diary.yml` — manual-only, только main, default execute_approved_patch=false, repository CLASPRC_JSON после unit gate, без environment secret.
- `scripts/task17/approved_diary_patch.mjs` — immutable version6/HEAD/full23-file SHA checks, pinned Script/deployment/owner, однократное изменение Diary, version/readback и ограниченный rollback6. Ни create-script, ни bootstrap, ни Drive ACL/API, ни OAuth properties не вызываются.
- `scripts/task17/test_approved_diary_patch.mjs` —8 controlled тестов stop conditions, проверки byte-for-byte diff/readback, target и отсутствия broad deployment действий.

Дополнительный dry-run на реальных20 JS+RSA исходниках Git deployed-source1a0cf8... (InitialConfig/manifest — контролируемые fixtures, не прочитанные Google данные):23 файла, изменён только Diary, SHA совпали с утверждённым diff. `SERVER_APPROVED_DRYRUN_17.json`. Прямой запуск в текущем окружении немедленно останавливается `SEPARATE_APPROVAL_AND_TRUSTED_MAIN_REQUIRED` до чтения credentials. Ни workflow, ни Google API из этого инструмента не запускались. Это CODE/CONTROLLED доказательство, не LIVE deployment PASS.

Для применения нужно отдельное прямое разрешение: перенести только эти три проверяемых файла доверенного инструмента в main и запустить Diary-only apply на существующем Script/deployment. Это НЕ разрешение merge всего PR48/изменения Android в main. Если HEAD Script отличается от immutable version6 или любой baseline hash не совпадает, инструмент STOP до push. При неопределённом результате нужен readback, а не слепой повтор. Rollback разрешает вернуть только этот проверенный Diary-only deployment на version6, без удаления данных или восстановления чужих HEAD-правок.

InitialConfig sourceSha специально сохраняется как historical baseline: после узкого patch числовая версия deployment и SHA полного readback являются доказательством нового кода; один runtime sourceSha не используется как ложное подтверждение version6.
