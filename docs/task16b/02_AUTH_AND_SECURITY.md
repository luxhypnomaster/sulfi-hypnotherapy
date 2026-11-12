# G1 — стабильная авторизация и серверное разграничение
## Наблюдаемое
Изначально MASTER/CLIENT sign-in + role checks прошли на физических телефонах, позже повторный вход в дневнике вернул `AUTHENTICATION_FAILED`; у мастерской карточки upload текст «Войдите через Google заново». У MASTER кнопка с человечком сначала `unknownError`, щит успешно авторизовал, после чего человечек показал «Выйти из Google». У CLIENT человечек работал с первого раза. Нельзя приравнивать истекший токен, реальный logout и сетевой сбой.
## Реализация
- Провести trace `GoogleSignIn`/ID-token получения/передачи/обновления в обоих входах; централизовать state and token refresh, не создавать две конкурирующие сессии. Не обходить SDK неподтверждёнными API. Silent refresh только по официально разрешённому flow; если нужна интерактивная переавторизация, сохранить все черновики и дать явную кнопку с причиной.
- Запретить трактовать `SocketException`, тайм-аут и HTTP 5xx как пользовательский logout. По auth 401/403 явно разделять invalid/expired token, audience failure, revoked/blocked, role denied, backend internal/auth service failure. Не повторять бесконечно 401.
- Учетные записи: Google verified `sub`, точный audience Web Client ID, iss/signature/exp/email_verified, server-side role; не доверять email/роль из UI или типу APK. Клиент не получает доступ к private master/other user data. При смене аккаунта сбрасывать account-scoped pending upload tokens/cache/retry; чужие задачи не отправлять под новым `sub`.
- Не кэшировать ID/access tokens в SQLite, файлах очереди, логах, URL и скриншотах. Безопасно восстанавливать identity при запуске приложения. Logout явный и корректный.
- Продемонстрировать 2-account QA на Wi-Fi и мобильной сети: launch→sign-in→whoami→role check→screen navigation→app minimize/reopen→read catalog/diary→upload continuation; повторить после token refresh и временного offline.
- Google Auth Platform Testing не пытаться обходить; тестируемые аккаунты уже прошли initial login, если появляется provider limit — достоверный raw-code в redacted trace и legal next step.
## Минимальные логи без секретов
Обезличенный requestId / traceId / phase / normalized error code / HTTP status / token expiration category / confirmed server role / retry count / elapsed ms; никакого токена, приватного Google sub, email, drive file IDs пользователей. Нужен correlation id в клиенте и GAS.
