# №17 — безопасность, обновления, развертывание и откат

## Безопасность

- Единая Google identity/SDK integration, но раздельные server ACL для чтения приватного, чтения публичного и публикации. Верификация Google токенов не заменяется локальным UI/почтой. Обновление bearer не должно менять Google sub.
- Проверить `iss`, `aud`, `exp`, подпись/JWKS, Google `sub`, audience Android/Web по действующей конфигурации. Публичный server client ID из №16-А можно использовать как конфигурацию, секреты не добавлять в APK. CLIENT без доступа к чужому private Drive и без права publish. Никаких wildcard Drive sharing / any-reader для private media.
- `redirect` по GAS: проверять заранее разрешённые доверенные Google домены, HTTPS и contract, не ослаблять pinning/network guard и не отправлять credential в URL/лог/произвольный redirect. Если Apps Script невозможен в текущей контрактной схеме — результат BLOCKED + аргументы, а не снятие проверки.
- Авторская offline работа и сохранённые материалы доступны локально; реальная привязка account owner к сетевым персональным задачам обязательна. При logout/switch запретить silent auto-login и отправку чужого. Android encrypted platform SDK/key stores предпочтительнее самодельных хранилищ токенов. Нельзя сохранять refresh tokens в ZIP резервной копии.
- Идемпотентность и status readback важнее скорости: не допускать двойных catalog revisions и дневниковых публикаций при timeout. Withdrawal/deletion — отдельные полномочия и отдельные команды, не side-effect cancel queue.

## Сохранность и Android обновление

- Не менять package: `ru.sulfi.sulfi_hypnotherapy` MASTER, `ru.sulfi.sulfi_hypnotherapy.clienttest` CLIENT; сохранить текущий signing cert, schema9 либо доказать безопасную миграцию, старые IDs, media SHA и программы/template IDs. Не менять пользовательские «Шаблоны» обратно, это UI «Программы» с прежними внутренними моделями.
- SQLite preflight WAL/journal protection и запрет опасного orphan cleanup из №16-Г сохранить. Не делать blank DB reset, импорт поверх живой базы, автоматическую чистку спорных медиа, необратимое действие при старте. Отсутствие старых test artifacts на устройстве не заявлять как восстановленное.
- Candidate APK только при выполненном native regression gate, verified signed sha256 package/versionCode. Собирать MASTER+CLIENT из одного проверенного source snapshot; прочитать sha/provenance обратно, проверить download. При несовпадении installer versionCert остановиться и не просить uninstall.

## Сервер и доставка

- Текущий сервер — существующий GAS6 «Сервер Проекта Алхимик». Архитектура Drive private storage + catalog manifest, JS logic. Не создавать второй сервер/GAS и второй каталог по этой задаче. Legacy «Сульфи — дневник» вне границ.
- Выполнить read-only live inspection, затем локально подготовить минимальный серверный diff и доказательства. **DEPLOY = только после отдельного одобрения пользователя конкретного diff и rollback.** Если нельзя проверить live без deploy, обозначить это STOP/NEEDS_OWNER_APPROVAL, но не выпускать ложный E2E PASS.
- Не менять Google Cloud OAuth Client registrations, Google Drive owner, ACL, private folder permissions, Apps Script execution identity, CORS, payment/billing и repo permissions без явно разрешённого действия. При 401/403 не снижать защиту ради UX.
- Не объединять draft PR в main и не публиковать GitHub releases публично без разрешения. Исходные отчёты №16 и архивы должны оставаться в их папке.
- Контракт rollback включает предыдущий immutable GAS deployment, protected backups и source SHA; изменённый клиент должен ясно обрабатывать older deployed server или блокировать unsafe action без потери черновиков. При необходимости нового backend API — versioned/back-compatible, не тихое нарушение старых CLIENT.

## Разделение ответственности

Codex выполняет кодовые изменения, эмуляторы и подготовку артефактов в доступном repo окружении. Подтверждение Google входа, установка APK на реальный телефон, фактический cloud deployment, publish/ACL changes, передача личных данных и оценка слышимости требуют реальных доказательств/отдельного разрешения. Не подменять факты имитацией.
