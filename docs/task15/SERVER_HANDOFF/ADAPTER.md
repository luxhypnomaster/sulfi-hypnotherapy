# Логический контракт и Apps Script

API_CONTRACT.yaml — проект будущего API, не существующие endpoints. Dart DiaryContractProvider имеет только injected request(operation,headers,bytes), без HTTP default, URL и OAuth. FakePublicationServer реализует feed/publish/upload/hash/blob/hash. Истинный transport выбирается отдельным ТЗ.

HTTP backend может напрямую использовать GET /feed, POST /entries, PUT/GET /blobs/{sha}. Для Google Apps Script нельзя слепо вызывать PUT/PATCH и полагаться на response status/headers ContentService. Adapter обязан преобразовать:

- doGet e.parameter.op=feed, page/since → envelope {status,headers:{ETag},body:{entries,...}}. Все страницы имеют один snapshot revision; повтор/изменение snapshot не коммитится частично. Fake15 отдаёт один snapshot целиком; pagination multi-page проверена только прежним DiaryApi, не новым adapter.
- doPost JSON {op:'publish',ifMatch,idempotencyKey,identityToken,payload:manifest}. Авторский identity token только в body POST по HTTPS, никогда URL/query/log. Проверка внешнего issuer/audience/expiry и server-side subject grant до каждой операции. Это требование будущего backend, не готовый login.
- binary upload/download через отдельное blob storage либо base64 POST envelope для ограниченных маленьких файлов. Ограничения Apps Script runtime/response size исключают обещание прямой передачи capsule до4GiB через ContentService. Platform/storage/signed downloads ещё не выбраны.
- Возвращать logical error status в JSON envelope и ETag-поле, транспорт переводит это в ContractResponse; не принимать HTML/login/redirect как успех. Авторизацию не пересылать при произвольном redirect.

Manifest и binary uploads разделены. Временная загрузка становится доступной только после hash/size verification и атомарного publish; повтор idempotency(subject,key,operation+canonical body) возвращает сохранённую receipt. Отличающийся body с тем же key →409, новый key со старым If-Match →412. Без автоматического rebase/перезаписи чужого черновика. Receipt хранить достаточно долго для offline retry (конкретный TTL требуется утвердить).

close=publication.authorClosed, timed=validUntil UTC, reannounce=новый activationCycleId/activatedAt. Quiet edit сохраняет cycle. Все состояния остаются в архиве. Read-state хранится только локально; LocalReadState.json не является public manifest или реализованным cloud endpoint. Никаких новых полей в существующий legacy API.
