'use strict';

// Task20 isolated contract, NOT installed in Router/GAS6. Storage must implement
// a durable per-scope lock, immutable put/readback, and atomic commitHeadReceipt.
// In particular, these semantics are NOT claimed for current GAS/Drive storage.
const crypto = require('node:crypto');
function canonical(value) {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).sort()
    .map(k => JSON.stringify(k) + ':' + canonical(value[k])).join(',') + '}';
  if (value === null || typeof value === 'string' || typeof value === 'boolean' ||
      Number.isSafeInteger(value)) return JSON.stringify(value);
  throw Error('NON_CANONICAL_JSON');
}
const digest = v => crypto.createHash('sha256').update(canonical(v)).digest('hex');
const copy = v => JSON.parse(JSON.stringify(v));
const exact = r => r.contentId + ':' + r.revisionId;
const defaultConfig = Object.freeze({schemaVersion:1,splashSeconds:3,entrySeconds:7,
  splashMode:'fullCycle',highWeight:1,normalWeight:1,pinnedEveryNth:3});
function config(value) {
  if (!value || value.schemaVersion !== 1 || !['fullCycle','betweenEntries'].includes(value.splashMode)) throw Error('INVALID_CONFIG');
  for (const [k,max] of [['splashSeconds',60],['entrySeconds',60],['highWeight',100],['normalWeight',100],['pinnedEveryNth',1000]]) {
    if (!Number.isSafeInteger(value[k]) || value[k] < 1 || value[k] > max) throw Error('INVALID_CONFIG');
  }
  return Object.fromEntries(Object.keys(defaultConfig).map(k => [k,value[k]]));
}
function validateSnapshot(s) {
  if (s.schemaVersion !== 1 || !s.scope || !Number.isSafeInteger(s.catalogRevision) ||
      s.catalogRevision < 1 || !Array.isArray(s.items)) throw Error('UNSUPPORTED_SNAPSHOT');
  const ids = new Set();
  for (const r of s.items) {
    if (!r.contentId || !r.revisionId || !/^[a-f0-9]{64}$/.test(r.sha256) ||
        ids.has(exact(r)) || !Array.isArray(r.dependencies)) throw Error('INVALID_ITEM');
    ids.add(exact(r));
  }
  const visiting = new Set(), seen = new Set(), items = new Map(s.items.map(r => [exact(r), r]));
  function visit(r) {
    if (visiting.has(exact(r))) throw Error('DEPENDENCY_CYCLE');
    if (seen.has(exact(r))) return;
    visiting.add(exact(r));
    for (const ref of r.dependencies) {
      const dep = items.get(exact(ref));
      if (!dep || ref.sha256 !== dep.sha256) throw Error('MISSING_EXACT_DEPENDENCY');
      visit(dep);
    }
    visiting.delete(exact(r)); seen.add(exact(r));
  }
  s.items.forEach(visit);
  config(s.vitrineConfig);
  return s;
}
function createSnapshotService({store, authorize, listCommitted, canExpose, now}) {
  // authorize returns an opaque server-owned audience scope, never a client ACL.
  async function scopeFor(actor, q, write) {
    const scope = await authorize(actor, q.scope, write);
    if (!scope || scope !== q.scope) throw Error('SCOPE_DENIED');
    return scope;
  }
  return {
    async head(actor, q) {
      const scope = await scopeFor(actor, q, false);
      return copy(await store.head(scope)); // O(1); no listCommitted / Drive scan.
    },
    async snapshot(actor, q) {
      const scope = await scopeFor(actor, q, false);
      const s = await store.snapshot(scope, q.snapshotId);
      if (!s) throw Error('SNAPSHOT_UNAVAILABLE');
      // Historical refs do not bypass current revocation / download ACL.
      if (!await store.snapshotReadable(scope, q.snapshotId)) throw Error('SNAPSHOT_REVOKED');
      return copy(s);
    },
    async publish(actor, q) {
      const scope = await scopeFor(actor, q, true);
      if (!/^[a-zA-Z0-9_-]{1,128}$/.test(q.requestId || '')) throw Error('REQUEST_ID_REQUIRED');
      const requestDigest = digest(q), receiptKey = actor.sub + ':' + q.requestId;
      return store.lock(scope, async () => {
        const prior = await store.receipt(receiptKey);
        if (prior) {
          if (prior.digest !== requestDigest) throw Error('IDEMPOTENCY_CONFLICT');
          return copy(prior.head);
        }
        const old = await store.head(scope);
        if ((old?.catalogRevision || 0) !== q.ifRevision) throw Error('REVISION_CONFLICT');
        const records = await listCommitted(scope);
        // Strict projection, no pass-through manifest/private fields or bytes.
        const items = [];
        for (const r of records) {
          if (r.state !== 'published' || !r.current || !await canExpose(r, scope)) continue;
          items.push({contentId:r.contentId, revisionId:r.revisionId, type:r.type,
            title:r.title, description:r.description || '', sha256:r.sha256,
            byteLength:r.byteLength, dependencies:(r.dependencies || []).map(d => ({
              contentId:d.contentId, revisionId:d.revisionId, sha256:d.sha256}))});
        }
        items.sort((a,b) => exact(a) < exact(b) ? -1 : exact(a) > exact(b) ? 1 : 0);
        const previous = old ? await store.snapshot(scope,old.snapshotId) : null;
        const vitrineConfig = config(q.vitrineConfig || previous?.vitrineConfig || defaultConfig);
        const snapshot = validateSnapshot({schemaVersion:1, scope,
          catalogRevision:(old?.catalogRevision || 0) + 1, createdAt:now(), items,
          vitrineConfig, configRevision:previous && digest(previous.vitrineConfig) === digest(vitrineConfig)
            ? previous.configRevision : (previous?.configRevision || 0) + 1});
        const hash = digest(snapshot), snapshotId = 'sha256-' + hash;
        await store.putImmutable(scope, snapshotId, copy(snapshot));
        if (digest(await store.snapshot(scope, snapshotId)) !== hash) throw Error('READBACK_HASH_MISMATCH');
        const head = {schemaVersion:1, scope, catalogRevision:snapshot.catalogRevision,
          snapshotId, snapshotHash:hash, createdAt:snapshot.createdAt};
        // Commit must compare old revision + head + receipt atomically. No code
        // path marks a publication successful before this adapter boundary.
        await store.commitHeadReceipt(scope, q.ifRevision, head, receiptKey,
          {digest:requestDigest, head});
        return copy(head);
      });
    },
  };
}
module.exports = {canonical, digest, validateSnapshot, createSnapshotService, config, defaultConfig};
