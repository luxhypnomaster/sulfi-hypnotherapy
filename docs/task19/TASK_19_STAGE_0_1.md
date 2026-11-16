# ИСПОЛНИТЕЛЬНОЕ ПОРУЧЕНИЕ CODEX — ЗАДАНИЕ №19, ЭТАПЫ 0–1
**Выполнить только G0 и G1** из `MASTER_SPEC_19.md`. Остальное — условия совместимости и следующий бэклог, не разрешение на реализацию.

## Цель
На кодовой базе двух Flutter Android APK (MASTER/CLIENT) провести read-only аудит неустойчивой Google auth и разработать в feature branch безопасный изолированный прототип постоянной Supabase Auth с Google provider. Доказать, что нормальный cold start/recents/expiry не требует повторного выбора Google-аккаунта. Сохранить working MASTER28/CLIENT28, legacy Google sub, background transfer checkpoint и SQLite. Ни один production service / deployed GAS / Google OAuth ACL / signing key не менять.

## G0. READ-ONLY AUDIT — что сделать первым
1. Проверь текущий HEAD, ветку, commit source и provenance APK28; отличай от исторического `de408f1`. Прочитай `01 — оперативное состояние`, №18 и его PARTIAL результаты, Google auth src/tests, Android fork `google_sign_in_android`.
2. Покажи точные paths/call graph: GoogleDiaryIdentity → DiaryController → AlchemistDiaryApi → `auth.whoami`, catalog/queue and background Android worker; все источники интерактивного chooser, 401, 503, expire, session restore, cancel.
3. Сравни официальные Supabase Flutter flows OAuth PKCE/deep-link vs native `signInWithIdToken` with Google access token; проверь package IDs и SHA1, Google OAuth Testing, callback URIs. Документируй API версии и ссылку на docs.
4. Inventory use of Google `sub` in Router/GoogleJwt/Access/AtomicStore/Diary/Transfer/Operations, design immutable `app_user_id` + verified mapping. Не мигрируй живые данные.
5. Предложи безопасный session coordinator for Flutter UI + headless engine, single refresh-token owner with per-install locks/leases; secure storage, no secrets in APK.
6. Сделай threat model: replay, cross-account ownership, token rotation race, 401 invalidation, untrusted edition, malicious client calling API, privilege escalation. План rollout/rollback, staged testing.
7. Сохрани 100% compatibility with baseline; при отсутствии Supabase project/config не выдумывай «работает»: продолжи мок/локальную подготовку, выдай OWNER_SETUP с минимальными безопасными действиями без передачи секретов в чат.

## G1. ISOLATED IMPLEMENTATION — после аудита
1. Создай отдельный reusable `AuthCoordinator` и один документированный официальный Google↔Supabase вход для staging build, предпочтение после доказательств. Держи original auth functional; feature-flag default OFF in actual production APK.
2. Реализуй secure persistence, refresh lifecycle, startup ready gate, onAuthStateChange onError, transparent network unavailable state, 401 refresh before logout, one interactive prompt only when truly needed.
3. Обеспечь owner binding background transfer: workers никогда не выбирают аккаунт, не отправляют данные под другим account. Не сдвигай/открывай личные черновики чужому аккаунту.
4. Отдельный тестовый профиль+entitlement можно schema-only, но НЕ реализуй полноценную billing/entitlement schema в этом запуске (это G2). Проверь только корректную identity roundtrip with sample mock/safe staging.
5. Никаких production migrations, публичных ACL, изменений GAS6, удаления/переноса media или включения Supabase Storage.

## Test/acceptance G0–G1
- Unit: one refresh at once, 401 then refresh success, 503/timeout not logout, real revoked state, explicit logout prevents silent restore.
- Android SDK fake adapter: no unintended interactive chooser after restoring signed account; multiple accounts do not auto switch.
- Native emulator as available: first interactive Google consent (when environment permits); cold start, recent-list dismissal, app switch, background queue auth lease, invalid/rotated refresh token, two app IDs.
- Physical owner tests: 15/30/60 min, reboot, two phones/accounts; mark NOT_RUN when not actually performed. Present exact reproduction script, no false PASS.
- Security negative tests: CLIENT edition cannot grant MASTER rights; actor/role based on authenticated server identity; app user id not user-controllable.
- Preserve current working E2E: MASTER publish audio→CLIENT install/offline, diary sync; mark native-only if actually run.

## Report
`RESULT_19_STAGE01.md` with PASS/PARTIAL/BLOCKED; `AUTH_ROOT_CAUSE_19.md`, `SUPABASE_VARIANT_COMPARISON_19.md`, `SESSION_COORDINATOR_19.md`, `LEGACY_ID_MAP_PLAN_19.md`, `SECURITY_19.md`, `TESTS_19.md`, `MIGRATION_AND_ROLLBACK_19.md`, `OWNER_SETUP_19.md` if required; code links and SHA/CI. Draft PR only. Never merge main or deploy production automatically.

## Resource stewardship
Before start ask owner if wants to record 5-hour and weekly Codex limit remaining; don't invent. Prefer targeted tests after first failure; preserve high-quality security gating. Return honest evidence, and do not claim that full №19 completed when only G0–G1 executed.
