# №25 — итог: APK29 собраны, выдача пары BLOCKED

Две APK0.4.21+29 реально собраны прежним ключом и независимо проверены по подписи, SHA, пакетам, версиям, SDK/ABI/правам и содержимому. Обычное обновление28→29 с сохранением данных подтвердили CLIENT наAPI34(15PASS), MASTER наAPI34 иAOSP35(по17PASS).

**Полный допуск пары не получен.** В последнем [run45166539406](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45166539406) сам QEMU уCLIENT упалSIGSEGV в паузе старойAPK28, до29. API36 и выдача корректноSKIPPED. Последняя AOSP-попытка не сняла инфраструктурный блокер; новых слепых повторов нет. **Пока не устанавливать эту пару на телефон.**

[DraftPR57](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57) · [Реальная сборка](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45103325755) · [Папка отчётов](https://drive.google.com/drive/folders/1o5g7O5jm5yw2URWVCIhEJrbP40ddMPwn).

Источник приложений737ea741636e9abe7c20353d9d5b8301cf44a5bb; код QA5977584cfeb14d3f3222d49e45729f76fff35f47. Runtime не менялся:574FlutterPASS/2SKIP,114Node;76QAtoolsPASS. Mainappstackнеmerged, productionGAS/OAuth/ACL/key/userdata не менялись. Реальные Google/телефоныNOT_RUN, установленная версияUNKNOWN, owner24→25causeUNKNOWN. APK остаютсяquarantine, наDrive не выкладывались.

Текущие RESULT,CHANGES,TESTS,ISSUES,ROOT_CAUSE,NATIVE_UPGRADE,55критериев ACCEPTANCE и binaryINFO/READBACK — отдельная датированная партия в этой папке. Исходные отчёты сохранены. Итоговые ID/размеры/SHA и независимое скачивание подтверждаются DELIVERY; текущий файл не является разрешением на установку.

Доставка проверена:17 материалов, final CSV revision,206вложений archive сSHA/CRC. 51scopedPASS,3PARTIAL,1ALREADY_DONE; fullnativepairBLOCKED.
[Итоговый RESULT](https://docs.google.com/document/d/1RKZdFGbSqEDb9eHYz0pj77UTRg8UZNZ4/edit) · [DELIVERY и контрольные суммы](https://drive.google.com/file/d/1Y6aCQSRcpjRbGYoK_ckMxagnVAleqyYE/view)
