'use strict';
// Disposable sandbox storage, NOT a production provider selection or GAS SQL.
const {DatabaseSync} = require('node:sqlite');
const {digest,canonical} = require('./catalog_snapshot.cjs');
function fail(status,code) {const e=new Error(code);e.status=status;e.code=code;throw e;}
class SqliteSnapshotStore {
  constructor(file,{inject=()=>{}}={}) {
    this.db=new DatabaseSync(file); this.inject=inject; this.atomicHeadReceipt=true;
    this.tail=Promise.resolve(); this.epochs=new Map();
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=1000;
      CREATE TABLE IF NOT EXISTS immutable(scope TEXT,id TEXT,payload TEXT,sha TEXT,PRIMARY KEY(scope,id));
      CREATE TRIGGER IF NOT EXISTS immutable_no_update BEFORE UPDATE ON immutable BEGIN SELECT RAISE(ABORT,'IMMUTABLE'); END;
      CREATE TRIGGER IF NOT EXISTS immutable_no_delete BEFORE DELETE ON immutable BEGIN SELECT RAISE(ABORT,'IMMUTABLE'); END;
      CREATE TABLE IF NOT EXISTS heads(scope TEXT PRIMARY KEY,revision INTEGER,payload TEXT,epoch INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS receipts(key TEXT PRIMARY KEY,payload TEXT);
      CREATE TABLE IF NOT EXISTS scope_epoch(scope TEXT PRIMARY KEY,epoch INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS prepared(id TEXT PRIMARY KEY,owner TEXT,scope TEXT,payload TEXT);
      CREATE TABLE IF NOT EXISTS records(id TEXT PRIMARY KEY,payload TEXT);`);
  }
  epoch(scope) {return this.db.prepare('SELECT epoch FROM scope_epoch WHERE scope=?').get(scope)?.epoch||0;}
  lock(scope,fn) {
    const result=this.tail.then(async()=>{this.epochs.set(scope,this.epoch(scope));try{return await fn();}finally{this.epochs.delete(scope);}});
    this.tail=result.catch(()=>{});return result;
  }
  head(scope) {const row=this.db.prepare('SELECT payload FROM heads WHERE scope=?').get(scope);return row?JSON.parse(row.payload):null;}
  receipt(key) {const row=this.db.prepare('SELECT payload FROM receipts WHERE key=?').get(key);return row?JSON.parse(row.payload):null;}
  snapshot(scope,id) {const row=this.db.prepare('SELECT payload FROM immutable WHERE scope=? AND id=?').get(scope,id);return row?JSON.parse(row.payload):null;}
  assertReadable(scope) {
    const h=this.db.prepare('SELECT epoch FROM heads WHERE scope=?').get(scope);
    if(h && h.epoch!==this.epoch(scope))fail(403,'STALE_SCOPE');
  }
  snapshotReadable(scope,id) {this.assertReadable(scope);return this.head(scope)?.snapshotId===id;}
  putImmutable(scope,id,value) {
    const hash=digest(value);
    if(id!=='sha256-'+hash)fail(422,'HASH_MISMATCH');
    const old=this.snapshot(scope,id);
    if(old && digest(old)!==hash)fail(409,'IMMUTABLE_CONFLICT');
    this.db.prepare('INSERT OR IGNORE INTO immutable VALUES(?,?,?,?)').run(scope,id,canonical(value),hash);
    this.inject('afterPreparedPersist',scope);
  }
  commitHeadReceipt(scope,expectedRevision,head,key,receipt) {
    if(!this.atomicHeadReceipt)fail(503,'ATOMIC_STORAGE_REQUIRED');
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const prior=this.receipt(key);
      if(prior) {
        if(prior.digest!==receipt.digest)fail(409,'IDEMPOTENCY_CONFLICT');
        this.db.exec('ROLLBACK');return prior;
      }
      if((this.head(scope)?.catalogRevision??this.head(scope)?.configRevision??0)!==expectedRevision)fail(409,'REVISION_CONFLICT');
      const epoch=this.epoch(scope);
      if(this.epochs.has(scope) && this.epochs.get(scope)!==epoch)fail(403,'STALE_SCOPE');
      const value=this.snapshot(scope,head.snapshotId);
      if(!value || digest(value)!==head.snapshotHash)fail(422,'READBACK_HASH_MISMATCH');
      this.inject('beforeHead',scope);
      this.db.prepare('INSERT INTO heads VALUES(?,?,?,?) ON CONFLICT(scope) DO UPDATE SET revision=excluded.revision,payload=excluded.payload,epoch=excluded.epoch')
        .run(scope,head.catalogRevision??head.configRevision,canonical(head),epoch);
      this.inject('afterHeadBeforeReceipt',scope);
      this.db.prepare('INSERT INTO receipts VALUES(?,?)').run(key,canonical(receipt));
      this.inject('beforeCommit',scope);this.db.exec('COMMIT');
    } catch(e) {try{this.db.exec('ROLLBACK');}catch(ignored){}throw e;}
    this.inject('afterCommit',scope);return receipt;
  }
  savePrepare(id,owner,scope,value) {
    const old=this.prepare(id);
    if(old && (old.owner!==owner || old.scope!==scope || canonical(old.value)!==canonical(value)))fail(409,'IDEMPOTENCY_CONFLICT');
    this.db.prepare('INSERT OR IGNORE INTO prepared VALUES(?,?,?,?)').run(id,owner,scope,canonical(value));
  }
  prepare(id) {const r=this.db.prepare('SELECT * FROM prepared WHERE id=?').get(id);return r?{owner:r.owner,scope:r.scope,value:JSON.parse(r.payload)}:null;}
  // Fixture/source adapter only. No HTTP handler can call these mutations.
  putRecord(value) {this.db.prepare('INSERT INTO records VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload').run(value.contentId,canonical(value));}
  records() {return this.db.prepare('SELECT payload FROM records ORDER BY id').all().map(r=>JSON.parse(r.payload));}
  invalidateScope(scope) {this.db.prepare('INSERT INTO scope_epoch VALUES(?,1) ON CONFLICT(scope) DO UPDATE SET epoch=epoch+1').run(scope);}
  close(){this.db.close();}
}
module.exports={SqliteSnapshotStore,fail};
