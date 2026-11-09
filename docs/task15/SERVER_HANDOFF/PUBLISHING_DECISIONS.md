# Не закрытые решения

SERVER_READY:NO, live deployment запрещён в №15.

- P0 G3: согласованная exact audio storage/readers/export/GC миграция, доказательство v1/v2 history coexistence.
- Серверная платформа: Apps Script adapter или другой backend; owner account/grant и client authentication (анонимный public vs account) не выбраны этим кодом.
- Права публикации/материалов/отзыв/каталог/квоты, подписанные download tokens и TTL idempotency receipts требуют утверждения.
- Blob storage/CDN/Drive layout/размеры/потоковая передача; текущий capsule max4GiB не является допустимым Apps Script response.
- K008 Home media layout и K023 Home draft preview не утверждены; существующий реальный DiaryReader preview сохранён.
- Ключи author/clienttest подписи постоянны в существующих GitHub secrets; production release signing/store rollout сюда не входит.

Следующее поручение: сначала устранить G3 на копиях populated данных, затем read-only audit реально существующего script/deploy и согласование схемы авторизации/хранения. Не превращать эти пункты в автоматически выбранные продуктовые решения.
