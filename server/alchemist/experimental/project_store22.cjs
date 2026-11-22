'use strict';
// Local candidate only. Uses the existing sandbox SQLite connection, never GAS.
const crypto=require('node:crypto');
function fail(status,code){const e=Error(code);e.status=status;e.code=code;throw e;}
function canonical22(v){
 if(Array.isArray(v))return '['+v.map(canonical22).join(',')+']';
 if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical22(v[k])).join(',')+'}';
 if(v===null||typeof v==='string'||typeof v==='boolean'||typeof v==='number'&&Number.isFinite(v)&&Math.abs(v)<=Number.MAX_SAFE_INTEGER&&(Number.isSafeInteger(v)||Math.abs(v*1000-Math.round(v*1000))<0.000001))return JSON.stringify(v);
 fail(422,'INVALID_CANONICAL22');
}
const digest22=v=>crypto.createHash('sha256').update(canonical22(v)).digest('hex');
const clone=v=>JSON.parse(JSON.stringify(v));
function id(v){if(typeof v!=='string'||!v.length||v.length>256||/[\x00-\x1f]/.test(v))fail(422,'INVALID_ID');return v;}
class ProjectStore22 {
 constructor(db){this.db=db;this.inTx=false;db.exec(`
 CREATE TABLE IF NOT EXISTS t22_values(ns TEXT,k TEXT,payload TEXT,PRIMARY KEY(ns,k));
 CREATE TABLE IF NOT EXISTS t22_immutable(hash TEXT PRIMARY KEY,payload TEXT);
 CREATE TRIGGER IF NOT EXISTS t22_immutable_update BEFORE UPDATE ON t22_immutable BEGIN SELECT RAISE(ABORT,'IMMUTABLE');END;
 CREATE TRIGGER IF NOT EXISTS t22_immutable_delete BEFORE DELETE ON t22_immutable BEGIN SELECT RAISE(ABORT,'IMMUTABLE');END;
 CREATE TABLE IF NOT EXISTS t22_audit(seq INTEGER PRIMARY KEY AUTOINCREMENT,actor TEXT,action TEXT,object TEXT,at TEXT);
 CREATE TABLE IF NOT EXISTS t22_feedback(owner TEXT,id TEXT,seq INTEGER,payload TEXT,PRIMARY KEY(owner,id));
 CREATE TABLE IF NOT EXISTS t22_evidence(target TEXT,owner TEXT,feedback TEXT,payload TEXT,PRIMARY KEY(target,owner,feedback));
 CREATE INDEX IF NOT EXISTS t22_evidence_target ON t22_evidence(target);
 CREATE INDEX IF NOT EXISTS t22_evidence_feedback ON t22_evidence(owner,feedback);
 CREATE TABLE IF NOT EXISTS t22_dirty(target TEXT PRIMARY KEY);`);}
 tx(fn){if(this.inTx)return fn();this.db.exec('BEGIN IMMEDIATE');this.inTx=true;try{const v=fn();if(v?.then)fail(500,'ASYNC_TRANSACTION_FORBIDDEN');this.db.exec('COMMIT');return v;}catch(e){this.db.exec('ROLLBACK');throw e;}finally{this.inTx=false;}}
 get(ns,k){const r=this.db.prepare('SELECT payload FROM t22_values WHERE ns=? AND k=?').get(ns,k);return r?JSON.parse(r.payload):null;}
 set(ns,k,v){this.db.prepare('INSERT INTO t22_values VALUES(?,?,?) ON CONFLICT(ns,k) DO UPDATE SET payload=excluded.payload').run(ns,k,canonical22(v));return clone(v);}
 list(ns){return this.db.prepare('SELECT k,payload FROM t22_values WHERE ns=? ORDER BY k').all(ns).map(r=>({key:r.k,value:JSON.parse(r.payload)}));}
 immutable(v){const hash=digest22(v);this.db.prepare('INSERT OR IGNORE INTO t22_immutable VALUES(?,?)').run(hash,canonical22(v));if(digest22(this.read(hash))!==hash)fail(422,'READBACK_HASH_MISMATCH');return hash;}
 read(hash){const r=this.db.prepare('SELECT payload FROM t22_immutable WHERE hash=?').get(hash);if(!r)fail(404,'IMMUTABLE_NOT_FOUND');const v=JSON.parse(r.payload);if(digest22(v)!==hash)fail(422,'READBACK_HASH_MISMATCH');return v;}
 audit(actor,action,object,at=new Date().toISOString()){this.db.prepare('INSERT INTO t22_audit(actor,action,object,at) VALUES(?,?,?,?)').run(actor,action,object,at);}
 receipt(owner,request,payload,fn){id(request);const key=digest22([owner,request]),hash=digest22(payload);return this.tx(()=>{const old=this.get('receipts',key);if(old){if(old.hash!==hash)fail(409,'IDEMPOTENCY_CONFLICT');return old.result;}const result=fn();this.set('receipts',key,{hash,result});return result;});}
}
module.exports={ProjectStore22,digest22,canonical22,clone,fail,id};
