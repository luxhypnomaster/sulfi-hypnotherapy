# Android OAuth — законная настройка, без компьютера

Текущее состояние: сервер реально исполняется и приватный bootstrap завершён. Это НЕ настраивает Android Google Sign-In. Repository variable `SULFI_GOOGLE_WEB_CLIENT_ID` отсутствует; ни clasp client ID, ни токены/secret не встраиваются в APK.

Google требует создавать OAuth clients в официальной Google Auth Platform; публичного поддерживаемого API для программного создания обычных Android/Web clients нет. В этой среде нет доступа к браузерной сессии владельца. Поэтому регистрацию клиентов пока выполнить не удалось. Повторная авторизация clasp не нужна.

## Действия в браузере телефона

1. Открыть https://console.cloud.google.com/auth/clients в аккаунте владельца. Выбрать принадлежащий владельцу Google Cloud project с настроенным OAuth consent. Предпочтительно существующий стандартный проект, связанный с новым сервером; старый «Сульфи — дневник» не менять. Создавать второй Apps Script не нужно.
2. Если Google требует Branding/Audience: указать действительные сведения владельца. Для External/Testing добавить аккаунт владельца в test users; это не открывает производственный вход всем пользователям. Для будущего общего распространения пройти требования Google к публикации. Приложению нужны openid/email/profile; выдавать Android-приложению Drive scope не требуется.
3. В Clients → Create client создать тип **Web application**. Его публичный Client ID нужен как `serverClientId` для Android и как допустимый `aud` на сервере. Для нативного ID-token flow не добавлять вымышленные redirect URI или URL `/exec`. Web client secret в APK не нужен, присылать его нельзя.
4. Создать два клиента типа **Android**, в том же Cloud project, с указанными ниже package name и SHA-1 существующей подписи. Не менять applicationId и ключ приложения.

| Редакция | Package name | SHA-1 сертификата |
|---|---|---|
| Автор | ru.sulfi.sulfi_hypnotherapy | 8E:B9:95:F1:4B:65:67:6F:DF:F3:05:48:CE:36:1A:EC:1F:47:92:56 |
| Клиент | ru.sulfi.sulfi_hypnotherapy.clienttest | 8E:B9:95:F1:4B:65:67:6F:DF:F3:05:48:CE:36:1A:EC:1F:47:92:56 |

5. Передать только публичный Web client ID вида `…apps.googleusercontent.com`. После его получения разработчик сохранит публичную repository variable, пересоберёт обе APK, обновит audience allowlist существующего сервера через проверенный manual-main workflow и выполнит серверные негативные проверки чужого audience. Клиенты Android должны быть действительно зарегистрированы, одного Web ID недостаточно.
6. Проверить на телефоне вход автора, публикацию, вход/выход клиента, отказ в чужих приватных данных. Эти аппаратные проверки пока NOT_RUN. Linux-тест с краткоживущим owner CI ID-token не доказывает Android Sign-In.

## Доказательство подписи

[Read-only CI 42875871201](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42875871201) сверил существующие APK21 diagnostics с исходным успешным run42819404870 и закреплённым SHA-256 сертификата `0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6`. Keystore и Google secrets этот workflow не читает. Публичный JSON приложен отдельно.

Google: https://developers.google.com/identity/protocols/oauth2/resources/best-practices (manual client creation); https://support.google.com/cloud/answer/15549257?hl=en (Android package и SHA-1).

Повторная проверка среды после её возобновления: executor `ccarenv_b64_Y2NhcmVudl8yNDc1NTRmMzBkNjA4MTkxYTAxOWExM2Y2N2I3MDUzMg`, connected/running/current, capabilities=[]; browser/computer-use/desktop control tool не предоставлен. Доступ к owner Console session не подтверждён. Repository vars=[]; среди имён Secrets есть только clasp и существующая APK-подпись, Android Web client config нет. Значения секретов не извлекались.
