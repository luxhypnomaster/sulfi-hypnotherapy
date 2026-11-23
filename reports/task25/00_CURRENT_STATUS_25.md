# №25 — тесты выполнены, выпуск пары APK пока BLOCKED

Обе APK0.4.21+29 собраны прежним ключом и независимо проверены по подписи, пакетам, версиям, SHA и содержимому. Это прежние неизменённые APK29; в данном продолжении пересборок и переподписей не было.

Полный допуск пары не получен. MASTER35 отдельно прошёл17/17, CLIENT35 —15/15; реальные SQLite/медиа-снимки независимо сверены. Но в последнем полном прогоне MASTER потерял эмулятор при открытии паузы в старойAPK28, до обновления. Отладчик зафиксировалSIGSEGV, затем ошибку продолжения. ОбаAPI36 и выдача пропущены обязательнымгейтом. Нельзя объединить результаты разных запусков в общийPASS.

Официальный software-Intent обход отвергнут доисполнения: actualAPK29DEX подтверждает cached AudioService engine без Activity shellargs. PR76 закрыт безmerge, run14 не запускался. Сохранены prototype/diff и доказательства; APK28 не изменяли ради теста.

115 актуальных локальных QA-проверок и actionlint PASS. Ранее574FlutterPASS/2SKIP и114Node на техже неизменных runtimebytes не повторялись ради отчёта. Физические телефоны и настоящиеGoogle-входы NOT_RUN. Установленныеверсиивладельца UNKNOWN. На основномтелефонедействийне требуется; готовыхустановщиковвэтойдоставкенет.

[Новый итоговый отчёт](https://drive.google.com/file/d/1lCv2lwtKEucuypKO-E9n_FLZBOUcwECT/view) · [Проверенная доставка и SHA](https://drive.google.com/file/d/1UjWtCbOdxjlRLHqAaWO_3wnq_3fItBYZ/view) · [55критериев](https://drive.google.com/file/d/1L6x8f3pBHMNnKRTtgNZI56uMLjvq13A2/view)

[Последний полный прогон](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45218835360) · [Draft PR57](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57) · [Папка отчётов](https://drive.google.com/drive/folders/1o5g7O5jm5yw2URWVCIhEJrbP40ddMPwn)

Доставка23.11.2026:11основныхфайлов+DELIVERY независимо скачаны обратно, SHA/размер/parent проверены; ZIPCRC и232manifestentries подтверждены. Матрица:51scopedPASS,3PARTIAL,1ALREADY_DONE, глобальноBLOCKED. Старыеотчёты сохранены. Appsource737ea741636e9abe7c20353d9d5b8301cf44a5bb,code-resultbf9818624b2a652724850d5d35d7e941ac82421f,mainQAef32862e07f5da07b610d29c721677b27ce1704e. AppPR51–57 неmerged, GAS/OAuth/ACL/ключи/личныеданные неизменны. RawDB/аудио/APK/core вархив не включены.
