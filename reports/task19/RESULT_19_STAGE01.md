# №19, G0–G1 — PARTIAL

Архив «Задание_19.zip» проверен: SHA-256 `591271cc99ee485c2fad775b0077b756c5c37ecf7401a19f97652f7d4f913b3f`, CRC и все пять записей MANIFEST совпали; прочитаны все шесть файлов. Исполнялись только G0–G1.

## Исходная точка и сохранность

Ветка `feat/task19-auth-stage01` создана от `363a0244ce761e317dd09a6c5cb366d1e8ba7315` ветки №18. PR49 остаётся необъединённым draft, последние runs №18 завершены; общий worktree не используется. Исходник подписанных APK28 — `de408f1`, текущий Git HEAD не приравнивается к нему. Неизменность обоих asset digests сверена через GitHub API.

GAS6, main, Google OAuth ACL, signing configuration/keys, публикации и личные данные не менялись. `SOURCE_GUARDS_19.json` доказывает побайтную сохранность original main.dart, auth/services/queue, SQLite/data/models/UI, transfer native code, server, third_party, pubspec/lockfile и assets. MainActivity дополнен только ветками для package suffix `.auth19`; Back и рабочие обработчики сохранены. Никакая настоящая база не мигрировала.

## G0 — выполнен аудит

Сохранены call graph, legacy Google sub inventory, сравнение PKCE/native ID+access flows, threat model и план verified legacy mapping. Отдельный controlled test воспроизвёл `401 → rejectIdentity → forced restore возвращает тот же cached ID token → refresh=false`. Последующий успешный whoami с тем же токеном восстанавливает доверие без picker. Поэтому это подтверждённый путь в коде, **не установленная причина события на телефоне**. Google Console Testing/scopes и реальный SDK trace пока не проверены.

## G1 — реализован изолированный прототип

Официальный Supabase Auth REST PKCE/S256 flow через браузер; отдельный native broker с единым refresh ownership, Android Keystore AES-GCM, AtomicFile/fsync и межпроцессным FileLock. Restore ready gate проверяет `/user` и Google provider-managed identity; нет доверия email/user_metadata/локальному edition. Состояния offline/backend/revoked/reauth различаются; 401 сначала пытается восстановить допустимый credential, 503/timeout не logout.

UI и headless API используют один broker. Worker требует pinned UID/epoch и не может открыть chooser, сменить аккаунт или сделать logout. Обычный same-owner refresh не меняет authority epoch; logout/account switch её меняет. Callback nonce, PKCE verifier, origin/path/TTL/replay checks, локальный logout tombstone и stream `onError` реализованы.

Флаг по умолчанию OFF. При ON Gradle требует отдельный `lib/main_auth19.dart` и добавляет `.auth19` к обоим applicationId. Это отдельный диагностический профиль, а не замена рабочей APK28. Supabase SDK с независимыми auto-refresh timers не запускается; выбран native REST adapter по официальному OpenAPI.

## Фактические проверки

- Полный локальный Flutter: **493 PASS, 2 штатных opt-in SKIP**. Последний адресный прогон: **5 PASS**.
- Финальные JVM: **28 PASS** — 20 coordinator/policy/owner/epoch и 8 REST adapter negative controls.
- Node: **47 + 24 PASS**. Анализ Dart без замечаний.
- Четыре актуальных native-файла успешно скомпилированы с настоящими Android SDK36 и Flutter embedding. Это type compilation, не исполнение Android Keystore.

[CI43949403640](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43949403640) не получил runner из-за сообщения GitHub о billing/spending limit: **0 шагов, код не запускался**. Повторы и платные настройки не выполнялись. Локальная полная APK-сборка после устранения proxy/TLS setup завершилась потерей Gradle daemon; cgroup сообщил OOM. Причинная привязка всех resource events к одному процессу не заявляется. APK19 и физический Android PASS не выдаются.

## Что заблокировано и следующий шаг

Настроенная тестовая Supabase-конфигурация не предоставлена; variables API недоступен403, поэтому не утверждается, что проекта вообще нет. LIVE Google/Supabase consent, refresh/rotation, два аккаунта/телефона, 15/30/60мин и reboot — **NOT_RUN/BLOCKED**. Локально нет KVM, CI runner недоступен: native Keystore/cold-process harness подготовлен, но не исполнен.

`OWNER_SETUP_19.md` содержит шаги с телефона. Нужны только публичные ref + publishable key отдельного staging-проекта; Google client secret вводится владельцем только в provider settings, не в чат. Оригинальный OAuth не менять. После конфигурации — conformance и owner QA отдельного профиля.

Supabase JWT **не подключён к GAS/очереди №18**: это G3. Нет account/file migration, лицензий/платежей/Storage, нового сервера, каталога/UX/768KiB/lock-рефакторинга. Все 51 критерий сохранены в матрице: G0–G1 разделены по уровням доказательств, G2–G7 — DEFERRED_NOT_AUTHORIZED. Никакого автоматического merge/deploy. Отчёты возвращаются в Git/draft PR; Drive upload по §14 пакета требует отдельного согласования.
