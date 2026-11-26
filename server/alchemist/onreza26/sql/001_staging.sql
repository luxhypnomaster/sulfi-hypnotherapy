-- STAGING synthetic identities only. Never run on GAS, device SQLite or production.
CREATE SCHEMA IF NOT EXISTS p22_stage26;
CREATE TABLE IF NOT EXISTS p22_stage26.identities (
 uid text PRIMARY KEY, issuer text NOT NULL, subject text NOT NULL,
 UNIQUE (issuer, subject));
CREATE TABLE IF NOT EXISTS p22_stage26.authority (
 uid text PRIMARY KEY REFERENCES p22_stage26.identities(uid),
 role text NOT NULL DEFAULT 'CLIENT' CHECK (role IN ('OWNER','ADMIN','AUTHOR','EDITOR','CLIENT')),
 role_version bigint NOT NULL DEFAULT 1 CHECK (role_version > 0),
 can_manage_subordinate_roles boolean NOT NULL DEFAULT false);
CREATE TABLE IF NOT EXISTS p22_stage26.installations (
 iid text PRIMARY KEY, uid text NOT NULL REFERENCES p22_stage26.identities(uid));
CREATE TABLE IF NOT EXISTS p22_stage26.sessions (
 sid text PRIMARY KEY, uid text NOT NULL REFERENCES p22_stage26.identities(uid),
 iid text NOT NULL REFERENCES p22_stage26.installations(iid), request_id text NOT NULL,
 expires_at bigint NOT NULL, role_version bigint NOT NULL,
 scopes jsonb NOT NULL, revoked boolean NOT NULL DEFAULT false,
 version bigint NOT NULL DEFAULT 1,
 UNIQUE(uid,iid,request_id));
CREATE TABLE IF NOT EXISTS p22_stage26.snapshots (
 id text PRIMARY KEY, scope text NOT NULL, sha text NOT NULL, payload jsonb NOT NULL);
CREATE OR REPLACE FUNCTION p22_stage26.prevent_snapshot_mutation() RETURNS trigger
 LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'IMMUTABLE_SNAPSHOT'; END $$;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='p22_stage26_immutable') THEN
  CREATE TRIGGER p22_stage26_immutable BEFORE UPDATE OR DELETE ON p22_stage26.snapshots
   FOR EACH ROW EXECUTE FUNCTION p22_stage26.prevent_snapshot_mutation();
 END IF;
END $$;
CREATE TABLE IF NOT EXISTS p22_stage26.heads (
 scope text PRIMARY KEY, version bigint NOT NULL, content_hash text NOT NULL, payload jsonb NOT NULL);
CREATE TABLE IF NOT EXISTS p22_stage26.receipts (
 key text PRIMARY KEY, fingerprint text NOT NULL, payload jsonb NOT NULL);
CREATE TABLE IF NOT EXISTS p22_stage26.outbox (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 key text NOT NULL, version bigint NOT NULL, payload jsonb,
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','DELIVERED')),
 attempts integer NOT NULL DEFAULT 0, UNIQUE(key,version));
