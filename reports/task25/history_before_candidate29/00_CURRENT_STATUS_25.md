# Задание №25 — актуальное состояние

**PARTIAL. Новых APK пока нет. Ничего устанавливать не нужно.**

[Draft PR57](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57) · [Продолжение](https://drive.google.com/file/d/1PrRDwyJIN3B0ds8sa66vUuEq7kKuqo8T/view) · [Точный запрос отдельного разрешения](https://drive.google.com/file/d/1h7ah7EqutKj10NgQcjjF-7Ex2CiUrG1A/view) · [Полный diff двух файлов](https://drive.google.com/file/d/1b-TfgutIkesEuMQ__-ReVqFNisyTf45g/view).

Код приложения сохранён: ранее574FlutterPASS/2SKIP,114NodePASS. Продолжение подготовило неактивный инструмент для проверки публичного сертификата прежнего keystore. Дополнительно23controlledPythonPASS,actionlintPASS,проверено применение/отменаdiff на отдельнойкопииmain. Настоящийkeystoreнеиспользовался,новыйсертификатнесоздавался.

Важныйфакт: GitHubmainprotected=false. Инструмент теперь явноотказывает до secretjob на такойветке. Два файла НЕ перенесены вmain, workflow НЕ запускался. Измененияmain/защиты/ACL/signing не разрешены текущейкомандой и не выполнялись.

Для продолжения нужен отдельно согласованный защищённый запуск/среда. Готовыйузкийdiff позволяетreview,нонеразрешаетизменятьнастройкизащиты. Дажеmatchingpubliccert неравен провереннойподписиAPK:посленегопотребуютсяprotectedbuild,nativeобычноеобновлениеMASTER/CLIENTибинарныйreadback. ДоэтихPASSAPKвыдачиздесьнет.

Матрица55:43PASSназаявленныхуровнях,1ALREADY_DONE,7BLOCKED,3PARTIAL,1NOT_RUN. Google/двафизическихтелефона/production22 неPASS. Main/GAS6/OAuth/данныеприложениясохранены. Старыйowner24→25UNKNOWNнеобъявленисправленным.

Источник инструмента5790139b0c2dc45363434451aa951b14b496d8fc; sourceприложения737ea741636e9abe7c20353d9d5b8301cf44a5bb. Исходные29отчётныхфайловосталисьнапреднихместах;дополнениеразмещенорядом,снеизменённымиправами.
