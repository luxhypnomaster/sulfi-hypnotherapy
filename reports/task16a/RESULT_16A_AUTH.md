# №16-А — серверная авторизация, роли, экспорт и импорт

Дата: 11.11.2026 UTC. Продолжение №16 в `feat/task16-alchemist-full-server`. Первоначальный C0/PREFLIGHT, исходные 20 документов, 147 критериев, история и отчёты №16 сохранены. Это промежуточный отчёт с фактическими ограничениями, №16 не закрыто.

Источник: [утверждённое дополнение №16-А](https://docs.google.com/document/d/16hMVySJwkS1kABBDyWXTJ3kfogzNJWayCu4LcFh_224/edit). Снимок: docs/task16a/TASK_RU.md и SOURCE.json.

## Реализовано

- Exact Web audience Google, проверка подписи RS256/issuer/aud/exp/iat/nbf/email_verified/sub. Единственный MASTER по закреплённому verified Google sub; остальные валидные аккаунты автоматически CLIENT. Email/роль из JSON, тип APK и старые author grants не повышают права. Clasp identity ограничена owner-bound bootstrap/status, обычный API её отвергает.
- Единый Google SDK-вход обеих ролей. Сервер подтверждает роль; клиент в мастерской APK не получает публикацию, владелец в клиентской APK сохраняет MASTER на сервере при скрытом авторском UI. Токены только в RAM, без Drive scopes Android и client secret. Выход/смена аккаунта скрывают приватный кэш и авторские редакторы, отменяют запоздавшие ответы.
- Локальный экспорт отделён от публикации. Клиент экспортирует свою локальную библиотеку/модули/шаблоны, не получает в резервной копии приватные авторские черновики прежнего мастера. Исходные строки SQLite/файлы сохраняются. Автоматическая облачная отправка экспортов отсутствует.
- Дневник «Добавить из каталога» выбирает опубликованные exact track/module/template. Сервер повторно проверяет тип, revision/digest и публикацию. ContentLink не выдаёт независимый доступ к снятому материалу. Голосовое вложение дневника не превращается в библиотечный трек. Прежний единый проверяемый installer и SHA-зависимости сохранены.
- Официальное происхождение установки хранится отдельно в SQLite без изменения canonical revision/digest; видна метка, оригинал защищён от клиентского редактирования. Личная копия модуля сохраняется отдельно. Проверены повторная загрузка policy и неизменность SHA. Перенос этой отдельной метки через резервную капсулу/физическое обновление пока не сертифицирован.
- Экран «Дневник → Подключение и права»: реальный SDK-вход, отображение подтверждённой роли, явная серверная проверка разрешённой закрытой публикации MASTER/отказа CLIENT. Два разных subject подтверждаются только реальными Google токенами; проверка ролей отдельно от read/install и двух телефонов.

## Реальное развёртывание

Прежний единственный «Сервер Проекта Алхимик» обновлён **version4 → version5 → version6**. Script, deployment URL, private storage и 41 папка сохранены; старый «Сульфи — дневник» не менялся. Актуальный version6/source `1a0cf8e5a60144075eec793767953586bfa319a2`; промежуточный version5/source `93d0f48af832f746dbfac98a9f3cab405ea8ff88`, прежний version4/source `766f178d8c0c95a270467b0d117f77105d6eef56` сохранён в истории.

[Deploy43036540579 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43036540579): owner OAuth, exact source/version readback, health, повторный bootstrap41 без дублей, анонимная запись/поддельная подпись/неправильный CI audience отклонены. Это не вход Android-владельца с Web audience.

Дополнительная защита сохранённых индексов версии4 развёрнута в **version6 / source1a0cf8e**. Первый запуск43039898736 остановился на WEBAPP_CONFIGURATION_MISMATCH после создания версии/обновления deployment. Повтор **[43040280601 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43040280601)** подтвердил ту же версию6, source/version/readback, health,41-folder replay и все live negative checks. Дубликат Script/версии не создавался. Старые link grants проверяются против настоящего published record; настоящие voice/image/video-вложения остаются доступны, исходные данные не удалены. 42 Node + повторный локальный cross-language тест PASS.

[Read-only43040748550 SUCCESS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43040748550): policyVersion2, точный Web Client ID, source1a0cf8e, **MASTER/CLIENT Web proofs отсутствуют**, `PENDING_REAL_ACCOUNTS`. Linux Google CI identity не подменяет пользовательские аккаунты. Независимый HTTP health версии6 также сохранён в RUNTIME_HEALTH_16A.json.

Полный Drive.Permissions.list подтвердил **одну страницу / одно разрешение / только владельца**. Files.shared summary=true сам по себе не предоставляет прав; решение основано на полном ACL, как в существующем GAS runtime. Ни открытие доступа, ни смена владельца не выполнялись. От владельца не нужен шаг изменения доступа по прежнему промежуточному предупреждению.

## Публичная конфигурация

Web Client ID: `325102995568-07pk1fcqvfnkp27kkmv7ple39enin31d.apps.googleusercontent.com`.

Master: `ru.sulfi.sulfi_hypnotherapy`; Client: `ru.sulfi.sulfi_hypnotherapy.clienttest`.

SHA1 обеих регистраций: `8E:B9:95:F1:4B:65:67:6F:DF:F3:05:48:CE:36:1A:EC:1F:47:92:56`.

SHA256 подписи: `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`.

Repository variables endpoint/WebID заданы. Repository secret CLASPRC_JSON применяется только ручными workflow exact main/exact repo, не PR/fork. Никаких environment secrets, повторной авторизации clasp, чужих Google tokens, owner sub или signing key в отчётах. Создание трёх OAuth clients подтверждено владельцем; их реальная SDK-работа требует телефонов.

## Сборки и препятствия

Финальная пара подключённых APK пока **не объявляется готовой**: по этапу D сначала необходим реальный этап C (два разных Google аккаунта, master publish / client denied publish / чтение и установка клиентом).

Для получения реальных SDK токенов подготовлен **один мастерский auth-candidate23** из проверенного app source74dd63c. Это техническая проверка до финальной пары, с прежними package/подписью; **workflow43037688974 SUCCESS**. Подпись, package/version23 и скомпилированные endpoint/WebID проверены. APK независимо скачана из GitHub, SHA совпал с CI и GitHub asset digest. [Скачать APK](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-ed63b9d51286856f454f/sulfi-master-auth-23.apk) · [закрытый черновик](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/tag/untagged-ed63b9d51286856f454f). Размер193711321байт (~185MiB); SHA256 `893a83cb06e9f5baf80643fac7946d9fdcf3ebdefbb3c948ff94415087d7fcd3`. Google SDK login/установка поверх приложения остаются NOT_RUN до телефонов. Вторая финальная APK не собирается преждевременно. Старые APK22 остаются историческими неподключёнными сборками.

GitHub отказал в новых Actions artifacts: 80 артефактов / 3.5GiB. Старые артефакты не удалялись. Для одного кандидата создан закрытый draft приватного репозитория, без опубликованного релиза или массовой раздачи; APK на Google Drive не загружаются. Журналы содержат только безопасные checkpoint-поля. Предупреждение загрузки артефактов отделено от результата серверного развёртывания.

Нужны реальные два Google аккаунта и два телефона. Нельзя честно завершить C/E из Linux без этих действий. Сроки входа/публикации/скачивания/офлайн-запуска пока NOT_RUN. Полный CI43036325914/source74dd63c:422 Flutter PASS; серверные PR-проверки43039723317:42 Node PASS. Ветка приложения сохранена отдельно; main получил только серверные и операционные PR35–39. Исторические 51:42 — длительность сервисного CI, не скачивания одного модуля.

Полная инструкция с телефона — PHONE_QA_16A.md. Google Testing/External и отсутствие email whitelist проверяются реальным вторым входом. При блокировке фиксируется точное сообщение Google; обходов и автоматического добавления клиентских почт нет. Ранее показанный Web client secret рекомендуется ротировать в Console согласно дополнению; этот ID-token flow его не использует.
