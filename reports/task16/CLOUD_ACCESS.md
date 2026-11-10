# Фактический доступ Google

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


Существующая авторизация clasp проверена реальными main Actions. Repository secret CLASPRC_JSON содержит уже выданный grant, не environment secret. Его значение не запрашивалось у владельца и не переносилось в Flutter/отчёты. Access token и Google ID token имеют разные сроки/наличие: deploy обновляет действующий grant через SDK при отсутствии/истечении ID token и проверяет RSA/audience/email_verified/exact owner. Никакого входа по декодированным непроверенным claims.

Доказанные scopes: Script projects/deployments/webapp и Drive.file. Full Drive scope не выдан clasp; отдельный manifest runtime GAS использует Drive+external_request. Runtime consent и право писать существующий parent проверяются только настоящим bootstrap, не выводятся из переключателя Apps Script API.

Текущая стадия: VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED; точное ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`.

Script ID: 1810esAOGDfsUf6EYdT9y7uY5_v0dzBmb5YSfwPZkxtZJsKw_ByEre0Vc.

Endpoint: https://script.google.com/macros/s/AKfycbzw36cEXSHVgfRxSl7k-6c2yV4uyPapqb-zndib8AlbHxhFCstXqxoqvqTMJvlHTT5zEg/exec. Версия: 2; source/version/deployment metadata verified by run42820498828 and read-only recovery42821006643. HTTP health later returned Google HTML403 Access Denied, not application JSON. Script ACL independently read owner-only at12:54:07UTC.

Drive metadata через подключённый коннектор 10.11.2026: parent «Проект Алхимик» shared=false, permission только owner. Это наблюдение не подменяет runtime ACL/API capability. For_Codex/отчёты расшарены по ранее заданным владельцем правилам; туда не помещаются owner sub, токены, grants и закрытые source-конфигурации. Новый сервер обязан повторно проверять ACL до приватных записей.

Android web OAuth client ID отсутствует в конфигурации. CI installed-client ID не является безопасной заменой Android/web login и не внедряется в APK. Старый Apps Script не используется для обхода этого ограничения.

## Независимый runtime readback

[Deploy42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828) прошёл AUTH_VERIFIED → SOURCE_PUSHED → VERSION_VERIFIED → DEPLOYMENT_CREATED → DEPLOYED, затем CLOUD_RUNTIME_NOT_EXECUTABLE. Версия2, owner execution/ANYONE_ANONYMOUS и endpoint проверены Script API. Script private ACL прошёл actual Drive GET в CI (external fallback marker отсутствует); independent connected Drive readback также подтвердил owner-only.

[Артефакт source hashes/deployment](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828/artifacts/13766691348). [Read-only recovery42821006643](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42821006643) подтвердил те же IDs/version/URL.

Независимый HTTP из текущего окружения после задержки:403 text/html, Google Access Denied / You need access. [Диагностика42822511730](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42822511730) после обновления существующего lawful grant: anonymous403HTML; owner OAuth200HTML, marker CONSENT; JSON=NO для обоих. SyntaxError/ReferenceError/TypeError/Exception markers не найдены. SUCCESS этого read-only workflow означает, что диагностика выполнена, а не что сервер стал рабочим. Bootstrap не вызывался, private data не записывались.

Точная причина отказа анонимного frontend и законный путь завершения первого runtime consent ещё требуют подтверждения; не выдаём HTML-marker за успешно пройденное согласие. [Документация Google о разрешениях исполнения](https://developers.google.com/apps-script/guides/services/authorization). Повторять clasp login не требуется.

Повтор после возобновления лимитов10.11.2026 16:31:24UTC: anonymous health всё ещё403 text/html, JSON=NO, Google Access Denied. Простое ожидание после deploy блокер не сняло.
