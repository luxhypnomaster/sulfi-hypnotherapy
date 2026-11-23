# Отдельное разрешение: только read-only inspect №25

**Ожидает отдельного решения; ничего не применено к main. GitHub API подтвердил main protected=false.** Пункт8 поручения №25 запрещает изменения main. Документ04_NATIVE_CI_AND_DELIVERY.md требует: «Его изменения — в draft PR с owner review; до фактического доступного workflow_dispatch на trusted protected default branch не выдавать workflow за запущенный». Прежнее разрешение №17 касалось другого инструмента и не распространяется на этот.

Подготовлен [полный diff двух файлов](https://github.com/luxhypnomaster/sulfi-hypnotherapy/blob/5790139b0c2dc45363434451aa951b14b496d8fc/reports/task25/SIGNING_INSPECT_MAIN_PROPOSAL_25.diff). Предлагается разрешить только следующее:

1. Перенести ровно два новых файла инструмента в main: `.github/workflows/sulfi-signing-inspect25.yml` и `scripts/task25/signing_inspect.py`. Не объединять PR57 или весь стек PR51–56. Согласованный базовый main — `b88637a105b2182c7b836311ebb3de7ad037b08f`. Если main сдвинулся, целевые пути появились или diff/hash отличается — STOP и новая проверка до применения.
2. Только после подтверждения защищённой main выполнить один ручной workflow_dispatch из main с confirmation `READ_ONLY_EXISTING_CERTIFICATE`. Запуск допускается только от luxhypnomaster; повторный запуск от другого аккаунта также запрещён. Инструмент получает только три существующих repository secrets: SULFI_TEST_KEYSTORE_BASE64, SULFI_TEST_STORE_PASSWORD, SULFI_TEST_KEY_ALIAS. Google OAuth, CLASPRC_JSON и пароль приватного ключа не используются.
3. Извлечь только публичный сертификат, проверить его прежний SHA-256 и наличие PrivateKeyEntry. Удалить временный keystore. Получить небольшой public-result.json. Не подписывать и не собирать APK, не обращаться к серверу, Drive или данным приложения, не устанавливать ничего на телефон.

Проверенный SHA-256 инструмента: `510d010cd4f14e959fbcc4b30939dcf497ffa2483d01fcb24bada1546119fd9c`. Он жёстко проверяется в workflow до чтения credentials. SHA-256 полного diff: `deaeed856500d2f2f35a6ed5bd101a1364db2ff1af83e341393f06aa63d0daba`. Кодовый checkpoint: `5790139b0c2dc45363434451aa951b14b496d8fc`.

Ссылки на actions закреплены полными SHA, полученными из GitHub: checkout `11d5960a326750d5838078e36cf38b85af677262`, upload-artifact `ea165f8d65b6e75b540449e92b4886f43607fa02`. Нет mutable ref или чтения PR/fork-кода с секретами. Предложение находится вне .github/workflows, поэтому сейчас не может запускаться.

Проверено:23 controlled Python tests, actionlint1.7.12, компиляция встроенных Python-блоков, применение/обратное применение diff на отдельной копии main с сохранением всех исходных хэшей. Настоящий keystore не использовался; новые сертификаты не создавались. Ограничения тестов описаны в SIGNING_INSPECT_SECURITY_REVIEW_25.md.

Даже matching public certificate **не доказывает** правильность пароля ключа, возможность подписать APK или безопасность Android-обновления. Инструмент явно вернёт privateSigningUsable=NOT_PROVEN_BY_PUBLIC_CERTIFICATE_INSPECTION, keyPasswordValidity=NOT_TESTED, nativeUpgrade=NOT_RUN. Для двух APK после этого останутся защищённая сборочная среда и native install-r проверки.

Откат самого инструмента, также только по разрешению: отдельный corrective commit, удаляющий эти два новых файла, если их хэши всё ещё согласованы. При чужих изменениях STOP. Этот откат не касается GAS, ключа подписи или приложения.

Возможный ответ владельца: «Разрешаю только два файла инструмента №25 в main и один read-only inspect. Без сборки, signing, deploy и merge всего PR». С телефона достаточно согласования; keystore, пароли, компьютер или ручной перенос кода не нужны. До отдельного ответа main остаётся без изменений.

Дополнительный фактический блокер: MAIN_TRUST_BOUNDARY_25.json фиксирует protected=false. Предложение не включает и не даёт разрешения менять branch protection, ACL или настройки репозитория. При текущем состоянии секретный inspectjob не будет запланирован. Прежде реальногоinspect требуется отдельно согласованный защищённый запуск или защищённая managed-среда с прежними credentials. До этого шаги исполнения остаются BLOCKED, даже если разрешён перенос двух файлов.
