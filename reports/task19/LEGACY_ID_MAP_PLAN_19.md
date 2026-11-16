# №19 — план identity mapping, НЕ миграция G2

Google sub, Supabase auth.uid и будущий app_user_id — три разные сущности. Supabase UID не записывать вместо старого Google sub или SQLite scope. Email/имя/selected APK edition/редактируемый user_metadata — не proof и не merge key.

Инвентаризация: server/alchemist/src/GoogleJwt.js issuer/audience/sub+master/revocation; Router actor; Access grants; AtomicStore owners/registry; Diary author+reader sync; Transfer owner/session/byRequest; Operations audit/revisions/idempotency. Flutter AlchemistDiaryApi.readerScope SHA256(endpoint+verifiedsub), legacy google:sub drafts, queued owner scope/requestId/session/offset/receipt. №18 worker compares verified whoami and native epoch. IDs/references/byte SHA must remain unchanged.

Концептуальный mapping G2: server-generated immutable UUID app_user_id; identity unique(issuer,provider_subject); append-only legacy_identity_links(legacy_google_sub,app_user_id,proof_kind,verified_at,audience,issuer). Unique legacy subject, collision→BLOCKED, no email merge. Это описание, не SQL deployment/настоящая таблица/лицензия.

Доверенное связывание требует серверной проверки Supabase JWT/JWKS/issuer/aud/exp и provider-managed Google identity, полученной сервером, а не клиентского JSON/user_metadata. При необходимости свежий legacy Google proof с правильной audience; проверенный Google sub должен совпасть ровно. Повтор linking идемпотентен; неоднозначность/два UID/смена provider account — ручной разбор без удаления прежней записи. Tokens/реальные Google sub не включать в отчёт.

Dry-run до approval: обезличенные fixtures A→appA, B→appB; повторA не создаёт2профиля; тотжеemail/другойsub не merge; конфликтexistinglink блокируется; old grants/ContentLink/checkpoints остаютсяbyte-identical. Ничего из настоящей базы или Google Drive сейчас не читается/не переписывается миграцией. Schema/fixtures описаны для будущего gate, не выданы за выполненный серверный тест.

G3 bridge должен сохранить Google owner/reader grants/receipts и application roles. SupabaseJWT cannot substitute GoogleJWT in existing GAS. Владелец отдельно утверждает staging gateway, signed verification, RLS и миграционный rollback. До этого prototype uid только в своём auth19 vault; entitlements/billing/app_user_id не реализованы.
