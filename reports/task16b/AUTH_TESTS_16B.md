# №16-Б — авторизация и безопасность тестов

Дата: 12.11.2026. Ветка: `fix/task16b-auth-transfer-publication`. Кандидат приложения: `012f7f69b7ad99c0d44f2a442d9649aa1481117e`. Draft PR: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45 . Продолжение №16/16-А, не №17.

Автоматически проверено в test/task16b_auth_transport_test.dart: обновление истёкшей RAM identity одним официальным restore для конкурентных вызовов; offline не вызывает SDK signOut; возвращённый другой subject не принимается как незаметный refresh; аккаунт нельзя сменить внутри retry; 401 даёт один ограниченный refresh, 403 не повторяет вход. Диагностика не содержит credential/исходного SDK/socket exception.

Production RSA verifier проверяется настоящей подписью контролируемых ключей: signed wrong audience, expired, wrong issuer, forged/unsigned и role spoof отклоняются; CLIENT не становится MASTER по claims. Это тестовые ключи/личности, не настоящий Google OAuth.

Read-only GitHub Actions 43156961962: runtimeHealthVerified=true, webAudienceConfigured=true, Script private/ownerOnly; serverTwoAccountRoleCheck=PASS, distinctAccounts=true; полный client read/install ещё не подтверждён. Никаких secret values в отчёте.

OWNER-REPORTED (из нового дополнения): APK24 initial Google MASTER и CLIENT + контрольные publish/deny — успешны. APK25 initial login, повторный запуск, официальный refresh на телефоне и Wi-Fi/mobile — ещё не проверены владельцем. Не обходили Google OAuth Testing и не просили refresh token/пароль.

Дополнительный тест проверяет 401 для ещё не истёкшего, но отвергнутого сервером токена: readerAuthenticated перестаёт утверждать успех, официальный refresh ограничен, owner scope/черновики сохраняются, SDK signOut не вызывается. Новый явный вход восстанавливает подтверждение. Сетевая ошибка сама по себе этот флаг не меняет.
