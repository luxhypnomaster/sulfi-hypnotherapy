# CI/signing — №25

Единственный runner probe: https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45048084597 . SUCCESS, verify job9steps. Ref main `b88637a105b2182c7b836311ebb3de7ad037b08f`, это **не** CI source737ea74. Ручной workflow alchemist-server-checks имеет contents:read, не ссылается на secrets; deployment-helper тест обязан завершиться78/GITHUB_SECRET_MISSING до credentials/network/write. Реальной публикации GAS нет. Повторов dispatch0 сверх одного первоначального запуска.

На main отсутствует checks.yml из стека Flutter. В feature-стеке build_mode=dual-apk сохраняет `check-accepted-server.mjs`; gate требует реальную серверную приёмку и не менялся. Его не запускали, не отключали и не подменяли fake health.

Имеющийся main alchemist-qa-pair.yml жёстко привязан к source cbe05240d463b9dafbe9a12ee831c967bdbf6113 / APK24 и проверяет private repository. Фактически repository PUBLIC; не удалять guard и не менять приватность ради сборки. Другие pinned23/24/finalize пути не создают source25. Draft workflow из произвольной feature branch не является доверенным default-branch workflow.

Cloud secret bindings отсутствуют; локальных переменных SULFI_SIGNING_* нет. Одна попытка посмотреть только имена GitHub repository secrets получила403 Resource not accessible by integration. Это **не** доказательство отсутствия прежнего keystore в GitHub, но не позволяет подтвердить пригодность signing job. Значения секретов не запрашивались.

Не запущены старый pinned pair, dual-apk, auth/production/clasp workflows, release/event-обходы; секреты не передавались ни одному PR/fork-коду. Новых workflows в .github нет, main не изменён.
