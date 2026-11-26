-- Additive STAGING-only cache metadata. No provider credentials or user therapy.
CREATE SCHEMA IF NOT EXISTS p22_stage26;
CREATE TABLE IF NOT EXISTS p22_stage26.billing_cache (
 binding_key text PRIMARY KEY,
 last_attempt_at bigint,
 last_success_at bigint,
 last_good jsonb,
 lease_id text,
 lease_until bigint NOT NULL DEFAULT 0,
 provider_not_before bigint NOT NULL DEFAULT 0,
 last_error_code text,
 access_denied boolean NOT NULL DEFAULT false
);
