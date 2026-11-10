# Фактический доступ Google

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Текущая контрольная точка: de27d86.

Runtime consent подтверждён фактическим JSON, а не только ответом владельца. [Deploy 42872816006](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42872816006) SUCCESS: existing Script/version4/source766f178, private bootstrap41, replay и отрицательные проверки. [Readback42876284145](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42876284145) подтверждает DEPLOYED_STORAGE_VERIFIED. Независимый anonymous HTTP200 application/json health повторно проверен; raw health.liveVerified=false — константа, не доказательство сквозной готовности. Старый «Сульфи — дневник» не изменялся.

Последние APK22: sourcee4ed74b, CI42878716769 SUCCESS,419Flutter PASS,33new/24oldNode PASS. Они пока без endpoint; подключёнными APK их не называем. Текущий Node33 PASS. [Первый live E2E42877004822](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42877004822) FAILED: media.beginUpload превысил20sec timeout. Изолированный новый transport исправлен,3regressionPASS. [Повтор42878030592](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42878030592) выполняется, результат не предполагается. Android OAuth Web client ID отсутствует; законная настройка описана в ANDROID_OAUTH_SETUP_RU.md. Физический Android NOT_RUN.


Существующая авторизация clasp проверена реальными main Actions. Repository secret CLASPRC_JSON содержит уже выданный grant, не environment secret. Его значение не запрашивалось у владельца и не переносилось в Flutter/отчёты. Access token и Google ID token имеют разные сроки/наличие: deploy обновляет действующий grant через SDK при отсутствии/истечении ID token и проверяет RSA/audience/email_verified/exact owner. Никакого входа по декодированным непроверенным claims.

Доказанные scopes: Script projects/deployments/webapp и Drive.file. Full Drive scope не выдан clasp; отдельный manifest runtime GAS использует Drive+external_request. Runtime consent и право писать существующий parent проверяются только настоящим bootstrap, не выводятся из переключателя Apps Script API.

Текущая стадия: DEPLOYED_STORAGE_VERIFIED. Версия4, source766f178, run42872816006 SUCCESS. Существующий Script ID1810esAOGDfsUf6EYdT9y7uY5_v0dzBmb5YSfwPZkxtZJsKw_ByEre0Vc и deployment не менялись. Raw HTTP health и метаданные — LIVE_HTTP_EVIDENCE.json. Private root/parent/41folders проверены через runtime и независимый Drive connector readback; не используются public Drive file ACL.

Ранние ошибки: version2 anonymous403HTML/owner consentHTML были реальны в run42820498828/42822511730, но после согласия владельца больше не являются текущим блокером. На реальном bootstrap найдены несовместимости SDK create/options и undefined pageToken; исправлены PR28, Node32PASS и повторным реальным deploy. Это не потребовало второго сервера или повторного clasp login.

Проверка реальных Flutter-сервисов42877004822 подтвердила actual owner identity/ACL/storage, затем выявила20секундный timeout первого upload. Изолированный AlchemistHttp исправлен и регрессия3PASS; повтор42878030592 выполняется. Не выдаём это за Android SDK login или завершённый E2E.

Android Google Web client ID отсутствует в публичной конфигурации. Официальная процедура и доказанные package/SHA-1 — ANDROID_OAUTH_SETUP_RU.md/ANDROID_OAUTH_PUBLIC_CONFIG.json. Нужны Web client и два Android clients в принадлежащем владельцу Cloud project. Google не разрешает программное создание обычных OAuth clients; браузерной сессии владельца здесь нет. Не извлекать credentials коннектора и не передавать clasp refresh token в APK.

For_Codex/отчёты остаются с ранее выбранным владельцем sharing; private state/SQLite/owner sub/токены/InitialConfig туда не помещаются. APK только GitHub. Старый Apps Script «Сульфи — дневник» не менялся.
