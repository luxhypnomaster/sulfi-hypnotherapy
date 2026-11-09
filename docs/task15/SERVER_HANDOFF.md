# ГОТОВИМ ОТДЕЛЬНОЕ ТЗ НА СЕРВЕР, НО НЕ ДЕПЛОИМ ЕГО В №15

## Выход №15: папка `SERVER_HANDOFF/` в отчётах Codex
- `API_CONTRACT.yaml` (или OpenAPI3), `JSON_SCHEMAS/` для diary entries/revisions, author drafts/publications, ContentLink, asset descriptors, catalogs, selected content revision manifest, read events, signed/authorized downloads. Не выдумывать endpoint на глаз: при выборе Google Apps Script учитывать реальные `doGet/doPost` и ограничения методов (или описать подходящий backend adapter), но не пытаться живьём вызывать несовместимые endpoints.
- `FAKE_PROVIDER_CONFORMANCE`: consumer-driven contract tests: Автор создаёт→publish immutable revision (fake auth), читатель read page+media, contentLink resolve/install, metadata update, reannouncement, withdrawal/expiry, permission denied, retry/idempotent, conflict If-Match, offline queue, no-blobs reupload for metadata change.
- `PRIVACY_AND_SECURITY.md`: авторские операции только с идентификацией/серверным role grant; клиенту недоступны приватные записи, drafts, чужая история, произвольные Drive URL; SHA не доказывает права. Подписанный доступ к blob/каталогу должен быть проверен на стороне provider; локальный mode=author не authorization. No secret keys in APK.
- `MIGRATION_DEPLOY_PLAYBOOK.md`: будущий план read-only инспекции существующего проекта Apps Script «Сульфи — дневник» scriptId `10jrwAx77N3tvs7k2Vwojip5-BpK1jjQcQ2dLeMczsaQL2hV8CCRx4Va0`; map текущего live deployment IDs/URL, OAuth scopes, Drive layout, owner/write rights, backups; staged test deployment с обратимым release. **Никаких действий по реальному скрипту до отдельного разрешения владельца.**
- `DEVICE_PAIR_RUNBOOK.md`: на A авторский APK создаёт текст+картинку+аудио+ContentLink, публикует; на B клиентский APK получает manifest/media, просматривает, дослушивает, устанавливает трек, read state меняется только на B; A тихо корректирует без повторного media upload; A повторно анонсирует; B видит unread; A закрывает объявление; B больше не видит его активным. Реальное серверное выполнение — следующий этап, не тест №15.
- `PUBLISHING_DECISIONS.md`: явные НЕ закрытые решения: серверная платформа, аккаунт автора, способ authenticating клиента, модель публикационного права, access control официальных материалов, медиа CDN/Drive storage, точные UX K-008 и K-023. Не превращать эти вопросы в собственные продуктовые решения Codex без поручения.

## Граница READY
- Клиентские модели/schema/version/digests, локальные reader states, exporter/importer, два test editions и FakeProvider contract tests должны быть зелёными.
- Нет недоказанной потери старых аудиоревизий/истории.
- Если любой P0 blocker остаётся — писать `SERVER_READY: NO`, перечислять ровно что блокирует, не выдавать успешный unit test за соединение двух телефонов.
- `SERVER_READY: YES (LOCAL CONTRACT ONLY)` допустимо лишь при всех локальных P0 PASS; никогда не `LIVE READY` до настоящего сервера и физических Android-тестов.
