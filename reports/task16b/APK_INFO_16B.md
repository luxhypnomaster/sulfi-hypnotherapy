# №16-Б — две подписанные APK25

Source `012f7f69b7ad99c0d44f2a442d9649aa1481117e`, версия `0.4.17+25`. [Exact-source checks433 PASS](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43162781960). [Сборка и проверка пары: success,attempt2](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43163688437).

[Закрытый GitHub draft — обе APK](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/tag/untagged-89fd5ff3b9d445c2d347). Это не публичный релиз. APK24 сохранены, Google Drive для APK не использовался.

## MASTER — мастерская

[Скачать sulfi-master-test-25.apk](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-89fd5ff3b9d445c2d347/sulfi-master-test-25.apk)

- Package: `ru.sulfi.sulfi_hypnotherapy`
- VersionCode25,versionName0.4.17; 193781457 bytes (~194MB).
- SHA256: `d0c8704673434b43fc7ceebbaceff4c3f2075a780964063c06dffeed03bc50c9`
- GitHub asset ID: 738283668.

## CLIENT — отдельный тестовый клиент

[Скачать sulfi-client-test-25.apk](https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/download/untagged-89fd5ff3b9d445c2d347/sulfi-client-test-25.apk)

- Package: `ru.sulfi.sulfi_hypnotherapy.clienttest`
- VersionCode25,versionName0.4.17; 193781493 bytes (~194MB).
- SHA256: `c42c709cce5aaf7a0354e7f86a5d908837ac07b875bfba014a9788cf6f4cbf73`
- GitHub asset ID: 738283907.

## Проверено по реальным файлам

GitHub Actions `apksigner verify --print-certs`, `aapt dump badging` и поиск compiled endpoint/WebID завершились успешно для обеих APK. Затем обе APK реально скачаны обратно через authenticated GitHub assets API; размер и SHA совпали с digest GitHub. Из V2 signing block независимо извлечён сертификат и проверены оба fingerprint:

- SHA256 `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`.
- SHA1 `8eb995f14b65676fdff30548ce361aec1f479256`.

В скачанных kernel blobs подтверждены существующий production endpoint и утверждённый Web Client ID. Сам signing key не извлекался/не менялся/не записывался в отчёты. APK_READBACK_16B.json содержит машинные результаты. APK24_MASTER_PRESERVED.json и APK24_CLIENT_PRESERVED.json подтверждают прежние файлы и digest без замены.

## Как скачать и установить с телефона

Открыть GitHub ссылку в браузере, где выполнен вход владельца в GitHub. Если получен404, проверить этот вход и доступ к private repository; Google-вход в Сульфи — отдельная авторизация. Для тестировщика без repo access владелец скачивает CLIENT APK и передаёт сам файл через Android Quick Share. Исходники/токены не передавать, репозиторий/релиз публичными не делать.

MASTER устанавливать поверх MASTER24 без удаления приложения и очистки данных. CLIENT — отдельный package/sandbox. Если Android пишет конфликт, остановиться и передать точный текст: не советуем удалять старое приложение. Приёмка APK25 реальными Google-пользователями и офлайн-звук на двух телефонах NOT_RUN. Native emulator результаты отдельно в EMULATOR_16B.md; их нельзя называть физической приёмкой владельца.
