# ЗАДАНИЕ №19 — АЛХИМИК / СУЛЬФИ — КОМПЛЕКСНОЕ ТЗ v0.3.1
Дата: 16.11.2026. СТАТУС: МАСТЕР-СПЕЦИФИКАЦИЯ / ИСПОЛНЯТЬ ПО ЭТАПАМ.
Проект: `luxhypnomaster/sulfi-hypnotherapy`. Область: MASTER28, CLIENT28, GAS + новый изолированный Supabase staging. Профессиональный отдельный «Мастер Алхимик» вне объёма.
Проверенный физический baseline: APK 0.4.20+28; код физической сборки сверить с Git и релизом до работы, исторический анализ основан на `de408f1cae08fce16069a701d147a0b1064053ba`. Нельзя считать этот коммит автоматически актуальным HEAD.

## 0. ИЕРАРХИЯ, ПРОИСХОЖДЕНИЕ И ПРАВИЛА
- Этот файл — полный реестр согласованных требований. Оперативное исполняемое поручение этапа 0–1 отдельно: `TASK_19_STAGE_0_1.md`. НЕЛЬЗЯ реализовывать все этапы за один проход.
- №18: фоновые передачи, нативная QA и часть auth-стабильности. Требования №18 не отменять, сверить фактический результат и переиспользовать уже написанный код; не переписывать с нуля. Не объявлять №18 закрытым, если owner live QA не подтверждён.
- Никаких операций с production GAS/Google OAuth ACL/подписью APK/реальными пользователями/продуктивной Supabase без отдельного явного разрешения. Работа через feature branch + изолированный тестовый контур. Не удалять существующий номерной ZIP №18 и отчёты, пока не подтверждено архивирование.
- Уровни доказательств: SOURCE/UNIT/INTEGRATION/EMULATOR/OWNER_PHONE/PROD. Не выдавать CI-мок за живой Android PASS. Регрессии и риск потери данных блокируют релиз.
- Базовая стилистика утверждена: тёмный кожаный планшет, неоновые фуксия/зелёный/жёлтый, Сульфи. Без произвольного редизайна. Новые изображения/макеты строго 9:16; экран адаптивен.

## 1. НЕПРИКОСНОВЕННЫЕ РЕГРЕССИИ (REG)
REG-01: Не удалять SQLite, аудио, дневник, шаблоны, модули, черновики, очередь, подтверждённые байты, лицензии, опубликованные реестры/ссылки. APK28 обновляется поверх предшественников без сброса.
REG-02: Зафиксированные owner PASS: облачный дневник на двух устройствах, получение изображений; публикация и установка аудио/модулей MASTER→GAS→CLIENT→локальная библиотека, offline playback, фаза/шаблон, одновременное чтение каталога разными аккаунтами. «Техника Дыхания — Вим Хоф» как полный E2E; «Индукция Элмана вар.2» скачан на втором физическом телефоне, но все варианты сквозного воспроизведения не доказаны.
REG-03: Защита авторских оригиналов, точные версионные ссылки, независимые пользовательские копии. Новые зависимости не перепривязывать задним числом.

## 2. SUPABASE AUTH (AUTH)
AUTH-01: Целевая идентификация: Google — внешний provider; Supabase Auth — persistent session, access/refresh; внутренний `app_user_id` — постоянная личность и реестр прав Сульфи. Не использовать Google ID-токен как постоянную сессию.
AUTH-02: В отдельном staging прототипе сравнить официальные схемы (а) Supabase Google OAuth PKCE/deep-link; (б) `google_sign_in` v7 + Supabase `signInWithIdToken` с необходимыми ID и access токенами. Выбрать один по проверяемой совместимости MASTER/CLIENT, безопасности, времени исполнения, устойчивости. Не допускать незаметного выбора другого Google-account.
AUTH-03: Автоматическое восстановление сессии после запуска, home/recents, рестарта процесса, перезагрузки, update APK, истечения access token, временной потери сети; показать выбор Google только при реальном интерактивном re-auth. После `supabase.initialize()` не считать защищённую сессию готовой до её проверки/допустимого refresh.
AUTH-04: Нельзя независимо обновлять одноразовый refresh token из UI Flutter, headless Flutter Engine, JobScheduler, фоновой очереди/дневника. Спроектировать единый координатор, синхронизацию хранилища между изолятами/процессами, owner-bound leases и безопасный retry в случае rotation race.
AUTH-05: Единая машина состояний SIGNED_OUT, RESTORING, AUTHENTICATED, REFRESHING, OFFLINE, BACKEND_UNAVAILABLE, REAUTH_REQUIRED, REVOKED. При 401 не ставить немедленный и безусловный `_identityRejected`; 503/timeout/DNS не считать logout. Санитизированная трасса источника интерактивного picker, без токенов/email/содержимого.
AUTH-06: Проверить Google OAuth Android packages, SHA1 signers, Web Client ID, redirect, scopes и Testing/Production. Testing/refresh lifetime зависит от scopes; не делать недоказанных выводов. Поток `onAuthStateChange` обрабатывать с `onError`.
AUTH-07: Выход на одном устройстве локален; «выход со всех» — отдельное намеренное действие. При смене account запретить кросс-владельческие кэши, background transfers и утечку auth context. Никаких server role из локального `edition=master`.
AUTH-08: Ключи `service_role`, JWT signing secret, client_secret и refresh токены НЕ класть в репозиторий/лог/APK; публичный publishable/anon key разрешён при надлежащей RLS и отдельно управляемой конфигурации. Secure storage оценить по Android Keystore. Восстановление после uninstall: новый Google-вход может потребоваться, права обязаны сохраниться.

## 3. ПОСТОЯННЫЙ ЛИЧНЫЙ КАБИНЕТ И ЛИЦЕНЗИИ (USER)
USER-01: Независимый UUID `app_user_id`, таблицы `app_users`, `user_identities`, `profiles`, `user_roles`, `entitlements`, `entitlement_events`, `wallet_ledger`, `wallet_balances` (материализованный), `sync_state`, `legacy_identity_links`. Повторный вход не создаёт второй профиль.
USER-02: Исторический GAS Google `sub` участвует в ролях, owners/readers grants, upload/download session, audit и reader sync. Создать migration mapping `legacy_google_sub -> app_user_id` через доверенно доказанную идентичность; email НЕ использовать единственным идентификатором. Коллизии/неоднозначность => BLOCKED без автоматического merge.
USER-03: Сервер хранит лицензии по `app_user_id` + стабильному `catalog_item_id`, тип grant/validity/issuer/version. Повторная установка APK/смена телефона сохраняет права. Приватный файл/манифест выдаётся только после server-side authorization, не через скрытые кнопки.
USER-04: Тестовый grant/revoke, 2 разных аккаунта, uninstall/reinstall, retry/idempotency. Тестовые внутренние единицы: immutable ledger, atomic purchase+grant, уникальные requestId, запрет прямого client update. Реальные деньги/payments сейчас не внедрять.
USER-05: Минимальный профиль и get-my-entitlements APIs, не собирать чувствительные данные о терапии без отдельного согласования. RLS на всех доступных клиенту таблицах; отрицательные API-тесты на чужую лицензию/роль/баланс.

## 4. ПЕРЕХОДНЫЙ ШЛЮЗ SUPABASE ↔ GAS (BRIDGE)
BRIDGE-01: Новый Supabase access token не может просто заменить Google JWT: GAS сейчас валидирует Google `iss/aud/sub` и хранит данные по Google sub. Подготовить доверенный verifier/JWKS либо Edge Function/API-gateway, безопасную legacy mapping и сохранение прежних разрешений; выбирать с учётом архитектуры и лимитов.
BRIDGE-02: Не принимать client-provided `app_user_id`, `role=MASTER`, `edition=master` как доказательство. Проверка подписи, issuer, aud, exp, subject, authorization policy и grants server-side. Клиентская редакция не должна выдавать авторские права по неподтверждённому флагу.
BRIDGE-03: Старый GAS, production Google OAuth ACL, реальные медиа и исходные записи не менять до отдельного approval. Развернуть отдельный staging, подготовить миграционный plan/diff/rollback. Нельзя уничтожать оригинальные owner IDs/receipts/grants.

## 5. ОЧЕРЕДЬ И ИСТОРИЯ ПЕРЕДАЧ (QUEUE)
QUEUE-01: После «Публиковать/Скачать» сохранять задачу в SQLite, автоматически запускать native worker/JobScheduler при допустимых условиях. `Ожидает отправки / попыток 0` без ясной причины — ошибка. Для CLIENT корректная терминология загрузки/скачивания.
QUEUE-02: Native background user initiated transfers (Android 14+/fallback) должны продолжаться при Home, screen lock, другой Activity; при network/system stop — durable resume, без обещания обходить Force Stop. Не терять owner/session/URI permission. Не показывать интерактивный Google chooser из фона.
QUEUE-03: Карточка с задачей: ID/номер, timestamp, направление, понятный тип `программа/модуль/трек/дневник`, title, 88x88dp cover, composition, duration, bytes/progress/status, релевантные действия. Новые задачи сверху по createdAt; активность выделять без хаотической сортировки.
QUEUE-04: Удалить одну запись/выбрать несколько/очистить завершённые и отменённые; удаление истории НЕ удаляет реальные файлы, published item, local draft, проверенные checkpoint. Отмена ещё не опубликованного черновика => «Открыть черновик». Published receipt не отменяется обычной Cancel; unpublish отдельное действие.
QUEUE-05: Раскрываемая «Техническая диагностика» для RPC, trace, codes, retries; основная карточка короткая. Правильные стадии: queued/transfer/bytes accepted/server verify/catalog publish/install/verified/offline/retry/wait_user.
QUEUE-06: После `catalog.publish` success и failed follow-up `catalog.get` не маркировать published item FAILED; статус `Опубликовано — ожидает контрольной сверки`, retry idempotent, без второй публикации.
QUEUE-07: Единая очередь как singleton navigation route; многократный tap badge не пушит 5 экранов. Back semantic по parent/launchContext; diary previous/next заменяет sibling без накопления back-chain, редактирование и unsaved draft требуют безопасного возврата, deep link/notification имеют fallback. Сохранение фильтров/прокрутки.

## 6. ANDROID УВЕДОМЛЕНИЯ (NOTIF)
NOTIF-01: В работе — понятная иконка направления (upload/download), актуальный процент и действия «Пауза/Отменить». Не отображать неопределённую анимацию в состоянии ожидания/готово.
NOTIF-02: При successful completion завершить progress: статичная галочка, «Передача завершена», действие «Готово» из шторки закрывает только уведомление. Иконка активной стрелки в status bar исчезает. Файл и история не затрагиваются.
NOTIF-03: WAITING_NETWORK/AUTH/POLICY => статичный статус с причиной; старые «Передача сохранена» и «Передачи завершены» не висят бессрочно и не противоречат друг другу. Учитывать notification permission/OS limits.

## 7. ОБЛАЧНЫЙ КАТАЛОГ И СИНХРОНИЗАЦИЯ (CAT)
CAT-01: Разделить ленту дневника/новостей (`diaryEntry`) и дистрибутивный каталог (`track/module/template` и будущие программы) на API, модели данных, индексы и экраны. Сохранять миграционные ID и ContentLink; не просто скрывать diaryEntry на UI.
CAT-02: Вкладки «Программы | Модули | Треки» в один ряд, категории dropdown, «Все категории», поиск по title/annotation; нет прямого ввода служебных идентификаторов/`diaryEntry`/«— байт». Теговый фильтр из известных данных.
CAT-03: Карточки 88x88dp квадрат cover (раньше ~56), заполнение с Crop, справа название/короткое описание/тип/состав/duration/size/version/status/licence. Placeholder по типу. Открытие подробностей — состав, автор, версия, разрешения, действия download/install/open/update.
CAT-04: Обложки автоматически из persistent local cache, не ручной tap; mini WebP/JPEG ~256px, hash-based invalidation, не скачивать полный оригинал ради thumbnail; UI refresh не сбрасывает картинки.
CAT-05: Offline-first snapshot SQLite с мгновенным списком, incremental `changes since cursor`, versions+deletions+access revocation, preserved scroll/filter; сотни-тысячи карточек без полного read на каждый вход. Метаданные, обложки и большие audio отделены.
CAT-06: Offline queue intent/download defer, entitlement check перед выдачей манифеста/asset; owner-bound cache. Тестовые лицензии отображаются как Free/Locked/Entitled/Installed/Update. Local copy policy для уже разрешённо установленного offline контента определить отдельно.
CAT-07: В CLIENT из «Программы и модули» маленькая кнопка облачного каталога, контекстная вкладка и возврат после установки; logout в настройки, большая кнопка очереди не занимает верх. MASTER каталог оригиналов показывает author edit не бессмысленную повторную установку.

## 8. ПУБЛИКАЦИИ MASTER (MASTER-CAT)
MASTER-CAT-01: Самостоятельный редактор облачных публикаций: список своих, категории/типы/статусы; название, аннотация, описание, обложка, tags, version, visibility, publish/withdraw/archive. Метаданные обновляются без повторной загрузки audio. Поддержать старые разрешения и фиксированные refs.
MASTER-CAT-02: Отличать сам факт публикации от локальной установки и авторской оригинальности; автору разрешено установить недостающий материал на другом устройстве без дублирования в каталоге.

## 9. UI / ЭСТЕТИКА (UI)
UI-01: Главный CLIENT: зелёный стикер «Дневник» поверх Сульфи и края планшета, убрать отдельную чёрную полосу. Вернуть высоту hero-изображения, сохранить рисунок.
UI-02: Верхний жёлтый transfer badge компактным OVERLAY без новой полосы и сдвига контента, соблюдая системные insets. Если нет активных операций, не занимать высоту.
UI-03: Прямая кнопка облачного каталога в локальном «Программы и модули»; при возвращении восстановить вкладку/scroll. Понятный пустой экран без «Добавь себе в библиотеку» при несоответствии контексту.
UI-04: Убрать крупные «Очередь передач/Выйти из Google» с каталога; выход в настройки аккаунта. Общая стилистика кожаного планшета/Сульфи/неоновые акценты неизменна.

## 10. ТРАНСПОРТ GAS / ANDROID (TRANS)
TRANS-01: Исходная метрика на одном 14 МБ тестовом файле: 256 KiB sequential Base64 JSON chunks; включая серверную SHA-256 проверку и GAS/Drive round-trips. Измерять wire-transfer отдельно от total wall-clock.
TRANS-02: Эксперимент **768 KiB = 786432 bytes** (3×256KiB). Примерно 54→18 RPC по данным для файла 14 MiB. Удостовериться что GAS принимает JSON с Base64 ≈1,048,576 символов + envelope; текущие router limit 500,000 chars и uploadChunk limit 349,528 chars требуют корректного согласования. Если платформа не выдерживает — BLOCKED/alternatives, не скрывать и не ломать production. Размер закреплять за сессией; старые продолжаются 256KiB.
TRANS-03: Автоматически восстанавливать transmission из фактического remote accepted offset; при lost response reconciliate before retry, не пересылать весь файл. Последовательный Google Drive resumable не поддерживает произвольное заполнение дыр; не обещать non-sequential piece repair.
TRANS-04: SHA-256 whole-object сохранять; серверную verify оптимизировать отдельно от wire transport. Разделить стадии и не объявлять publish до verification. Invalid/corrupt items не устанавливать.
TRANS-05: Диагностика RPC elapsed/Drive API/time server lock waits/byte movement SHA/commit/publish; без приватных файлов в logs. Не принимать измеренное КБ/с полного процесса за физическую скорость сети.

## 11. СЕРВЕРНЫЕ LOCKS (LOCK)
LOCK-01: Сейчас ScriptLock удерживается в media.upload/commit while Drive IO, plus RateLimit uses global ScriptLock, audit тоже проходит через lock; из-за этого возможны BUSY на unrelated read/auth.
LOCK-02: Атомарная RESERVE под коротким lock → Drive IO без глобального lock → атомарная COMMIT с revision check; per-session mutual exclusion/lease expiry; recovery after crash between phases. Не удалять lock без гарантий консистентности.
LOCK-03: Изолировать RateLimit от долгой upload/verify операции, не отключать rate limits/authorization. Audit may be delayed/outbox but не превращать уже verified publish в FAILED.
LOCK-04: Независимые switches: 256/768 KiB and old/new locking; последовательные A/B experiments with confidence intervals/retries, rollback independently; two-account concurrency/regression.

## 12. БУДУЩИЙ SUPABASE STORAGE (STORAGE)
STORAGE-01: Статус: только отдельный future prototype, не мигрировать реальный audio/Diary. TUS resumable based on Supabase-supported chunk size and configuration, не переносить 768KiB GAS blindly.
STORAGE-02: Защищённое хранилище, verified entitlements before manifest/object; no permanent public URL to paid assets; short-lived server-mediated access; storage usage/cost model and data residency.
STORAGE-03: Separate migration plan preserves item IDs, SHA, owner/reader grants, revision dependency refs, ContentLink, legacy media receipts, rollback.

## 13. ПОЭТАПНЫЕ GATES
G0: read-only audit of current branch/APK/GAS/Google OAuth and alternative Supabase auth flow; isolated test infrastructure; no production writes.
G1: demo Supabase Auth staging, Google first login and persistent silent restore, token coordinator and 2 APK package IDs. Physical owner proof required.
G2: `app_user_id`, safe Google sub linkage, RLS, test entitlement/ledger, reinstall cross-device.
G3: secure Supabase↔GAS gateway and old assets/roles tests, no production cutover until approved.
G4: queue/background/native Android notification/UX fixes (respect №18 existing work).
G5: offline-first catalog, publication editor, diary separation.
G6: 768KiB GAS experiment, lock optimization, isolated performance/rollback.
G7: storage TUS prototype and migration proposal ONLY.
No next gate without prior safety proof and owner approval for production migrations.

## 14. ПРИЁМКА И ОТЧЁТЫ
All acceptance in `ACCEPTANCE_19.csv`. Reports: RESULT_19, ARCHITECTURE_19, ROOT_CAUSE_AUTH_19, LEGACY_IDENTITY_MAP_19 (schema-only, no personal data), TESTS_19, SECURITY_19, MIGRATION_19, PERFORMANCE_19, ISSUES_19, PHONE_QA_19 (owner-run unverified if pending), APK_PAIR_19 only when safe. Include commit SHA, branch, CI logs, exact tests, rollback steps, source diff; update Google Drive according to project routine only after approval. Preserve original №18 and previous work.

## 15. НЕ ДОПУСКАТЬ РАСШИРЕНИЯ ОБЪЁМА
No real billing, no automatic cloud upload of private therapeutic data, no public beta, no redesign entire artwork, no STT/AI analytics, no rewriting professional Master Alchemist, no migration entire media library, no user-account merge by email, no credential secrets in Git/logs/phone screenshots. Infeasible platform constraints => report BLOCKED with evidence, proposed safe alternative.
