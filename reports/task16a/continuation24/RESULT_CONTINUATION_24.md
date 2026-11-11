# №16 + №16-А — результат продолжения, две тестовые APK24

11.11.2026 UTC. **Задача не закрыта: обязательная физическая приёмка и реальные Google-пользователи ожидаются.** Исходные147критериев, C0/PREFLIGHT и прежние отчёты не перезаписаны. Новая матрица — ACCEPTANCE_CURRENT_24.md/JSON.

## Выполнено самостоятельно

- Прочитаны текущие RESULT/TESTS/PHONE_QA16A и ISSUES_AND_NEXT16, сверены неизменившиеся metadata исходного ZIP и Google Doc. Успешные C0, создание сервера, private bootstrap и сервисный E2E51:42 не повторялись.
- Исправлен каталог: уже подтверждённый Google-вход отображается как вход, выход обновляет экран, неуспешная авторизация не выдаётся за успех.
- В капсулу добавлено опциональное read-only происхождение официальных материалов. Оно переносится с выбранными материалами в транзакции, не меняет canonical SHA, не переносит роли/credentials и не выдаёт MASTER. Локальный режим сохраняется. Новый unit/widget набор и старые схемы6/7/8 проверены.
- Первая полная проверка выявила сброс локального режима при обновлении меток (3регрессии). Исправлено отдельной reloadCatalogOrigins. Итоговый точный source **cbe05240d463b9dafbe9a12ee831c967bdbf6113** прошёл CI43070740850: **424Flutter/43Node/24legacyNode**, analyzer/formatter/contracts/fixedCLIENT PASS. Непроверенная промежуточная версия в APK не попала.
- Обе APK **0.4.16+24** собраны из одного source в [43072088028 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43072088028). Package/version24/прежняя подпись/скомпилированные endpoint и WebID проверены. Оба файла независимо скачаны через GitHub и проверены SHA256 и официальным apksigner.

## Две APK для человека

[Мастерская APK](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-9962b11f7ce0aa819785/sulfi-master-test-24.apk) · [Клиентская APK](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-9962b11f7ce0aa819785/sulfi-client-test-24.apk) · [Приватная страница сборок](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/tag/untagged-9962b11f7ce0aa819785). Нужен вход владельца в GitHub; тестировщику можно передать клиентский файл через Android Quick Share/«Поделиться», не открывая репозиторий и не передавая пароль. Дополнительные файлы APK доступны в рабочем пространстве этой сессии. Реальное скачивание и установка на телефон NOT_RUN до подтверждения пользователя.

| Редакция | package | SHA256 |
|---|---|---|
| Мастер | ru.sulfi.sulfi_hypnotherapy | a242d8222af27c936f44c86b47e2cf674c3789072c3a7cac9aa4bba3afe3cda1 |
| Клиент | ru.sulfi.sulfi_hypnotherapy.clienttest | 352e8d087fd6c80f632e6d150b517ff07f41f492d01322e8443ff5fa784da8f1 |

Размер каждой ~185MiB. Сертификат обеих `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`, SHA1 совпадает с регистрациями Android. Это два кандидата по прямому последнему запросу владельца, **не две принятые на устройствах APK**. Accepted-server gate не установлен. Draft не опубликован, исходники остаются приватными; APK на Drive не отправлялись. Прежний кандидат23 и старые артефакты сохранены. Квота Actions artifacts обойдена доставкой в private draft, не удалением истории/платной услугой.

## Сервер и доказательства

Сохранён существующий единственный Script/deployment: **version6/source1a0cf8e**. Код backend/старый дневник/данные не менялись и не перевыкладывались ради APK. Свежие read-only43069660391 и43079763564 подтвердили health/exactWebAudience/policy2/полный owner-only ACL. MASTER/CLIENT пользовательских proof пока нет. CI identity не считается нативным пользователем и не принимается normal API.

SERVER_LIVE=true; QA_PAIR_BUILT=true; CONFIG_AND_SIGNATURE_VERIFIED=true; REAL_GOOGLE_USER_ACCEPTANCE=false; PHYSICAL_TWO_PHONES=false; TASK16_COMPLETED=false. Статусы147 текущей матрицы: **99 PASS /46 PARTIAL /1 BLOCKED /1 NOT_RUN**; уровни PASS ограничены указанными доказательствами, не «всё готово». Остаток — ISSUES_AND_NEXT_24.md. Полная история сохраняется.

## Точная точка остановки

Нужен настоящий Google-вход владельца: мастерская APK → «Дневник» → «Подключение и права» → «Войти через Google» → аккаунт владельца → «Проверить права на сервере». Дальше другой Google-аккаунт и критический путь Элмана3треков на двух телефонах по PHONE_QA_24.md. Пароль, token, client secret, ПК и повторный clasp-login не нужны. До результатов реальных людей приёмка BLOCKED; нет фиктивных live PASS, №17 или нового сервера.
