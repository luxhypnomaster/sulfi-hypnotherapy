import {randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {digest,validateSnapshot} from '../core/contracts.mjs';
import {fail,checkSession} from '../core/security.mjs';
const number=v=>Number(v);
export class PostgresRepository {
 constructor(pool,{clock=()=>Math.floor(Date.now()/1000),inject=()=>{}}={}) {Object.assign(this,{pool,clock,inject});}
 async migrate(){await this.pool.query(await readFile(new URL('../sql/001_staging.sql',import.meta.url),'utf8'));}
 async transaction(fn) {
  const c=await this.pool.connect();
  try {await c.query('BEGIN ISOLATION LEVEL SERIALIZABLE');const r=await fn(c);await this.inject('beforeCommit');await c.query('COMMIT');await this.inject('afterCommit');return r;}
  catch(e){try{await c.query('ROLLBACK');}catch{}throw e;}finally{c.release();}
 }
 async event(c,key,version,payload){await c.query('INSERT INTO p22_stage26.outbox(key,version,payload) VALUES($1,$2,$3) ON CONFLICT(key,version) DO NOTHING',[key,version,payload]);}
 async restore(verified,iid,requestId,{allowNew=false}={}) {
  if(verified.kind!=='identity'||verified.iss!=='urn:alchemist:synthetic-idp'||verified.aud!=='staging26-bootstrap'||verified.exp<=this.clock()||!/^[A-Za-z0-9_-]{1,128}$/.test(iid)||!/^[A-Za-z0-9_-]{1,128}$/.test(requestId))fail('AUTH_REQUIRED',401);
  return this.transaction(async c=>{
   let u=(await c.query('SELECT uid FROM p22_stage26.identities WHERE issuer=$1 AND subject=$2',[verified.iss,verified.sub])).rows[0];
   if(!u) {
    if(!allowNew)fail('REGISTRATION_DISABLED',403);
    await c.query('INSERT INTO p22_stage26.identities VALUES($1,$2,$3) ON CONFLICT(issuer,subject) DO NOTHING',[randomUUID(),verified.iss,verified.sub]);
    u=(await c.query('SELECT uid FROM p22_stage26.identities WHERE issuer=$1 AND subject=$2',[verified.iss,verified.sub])).rows[0];
    await c.query('INSERT INTO p22_stage26.authority(uid) VALUES($1) ON CONFLICT DO NOTHING',[u.uid]);
   }
   await c.query('INSERT INTO p22_stage26.installations VALUES($1,$2) ON CONFLICT DO NOTHING',[iid,u.uid]);
   if((await c.query('SELECT uid FROM p22_stage26.installations WHERE iid=$1',[iid])).rows[0].uid!==u.uid)fail('INSTALLATION_OWNER_MISMATCH',403);
   const role=(await c.query('SELECT role_version FROM p22_stage26.authority WHERE uid=$1',[u.uid])).rows[0];
   await c.query('INSERT INTO p22_stage26.sessions(sid,uid,iid,request_id,expires_at,role_version,scopes) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(uid,iid,request_id) DO NOTHING',[randomUUID(),u.uid,iid,requestId,this.clock()+300,role.role_version,JSON.stringify(['client:public'])]);
   const r=(await c.query('SELECT sid FROM p22_stage26.sessions WHERE uid=$1 AND iid=$2 AND request_id=$3',[u.uid,iid,requestId])).rows[0];
   const session=await this.session(r.sid,c);if(session.revoked||session.expiresAt<=this.clock())fail('NEW_REQUEST_REQUIRED',409);
   await this.event(c,'session:'+session.sid,session.version,session);return session;
  });
 }
 async session(sid,c=this.pool) {
  const r=(await c.query('SELECT s.*,a.role_version AS current_role_version,a.role,a.can_manage_subordinate_roles FROM p22_stage26.sessions s JOIN p22_stage26.authority a USING(uid) WHERE sid=$1',[sid])).rows[0];
  return r?{sid:r.sid,uid:r.uid,iid:r.iid,expiresAt:number(r.expires_at),roleVersion:number(r.current_role_version),revoked:r.revoked||number(r.role_version)!==number(r.current_role_version),scopes:r.scopes,version:number(r.version),role:r.role,canManageSubordinateRoles:r.can_manage_subordinate_roles}:null;
 }
 async revoke(sid) {return this.transaction(async c=>{
  const r=(await c.query('UPDATE p22_stage26.sessions SET revoked=true,version=version+1 WHERE sid=$1 AND NOT revoked RETURNING version',[sid])).rows[0];
  if(r)await this.event(c,'session:'+sid,number(r.version),await this.session(sid,c));
 });}
 async publish(claims,{requestId,snapshot,expectedRevision,ratingsRevision=null,ratingsSnapshotHash=null}) {
  validateSnapshot(snapshot);
  const top=new Set(['schemaVersion','scope','catalogRevision','createdAt','items']),itemKeys=new Set(['contentId','revisionId','sha256','dependencies','title']);
  if(Object.keys(snapshot).some(k=>!top.has(k))||snapshot.items.some(r=>!r.contentId.startsWith('synthetic-')||Object.keys(r).some(k=>!itemKeys.has(k))||r.dependencies.some(d=>Object.keys(d).some(k=>!['contentId','revisionId','sha256'].includes(k)))))fail('SYNTHETIC_PUBLIC_SCHEMA_REQUIRED',422);
  if(snapshot.scope!=='client:public'||!/^[A-Za-z0-9_-]{1,128}$/.test(requestId)||!Number.isSafeInteger(expectedRevision)||expectedRevision<0||
   (ratingsRevision!==null&&(!Number.isSafeInteger(ratingsRevision)||ratingsRevision<1||!/^[a-f0-9]{64}$/.test(ratingsSnapshotHash||'')))||ratingsRevision===null&&ratingsSnapshotHash!==null)fail('INVALID_PUBLICATION',422);
  // A new ratings HEAD cannot be asserted by a caller without verified ratings storage.
  if(ratingsRevision!==null)fail('RATINGS_ADAPTER_REQUIRED',503);
  const fingerprint=digest({snapshot,expectedRevision}),receiptKey=claims.sub+':'+requestId;
  return this.transaction(async c=>{
   const actor=await this.session(claims.sid,c);checkSession(actor,claims,this.clock());
   if(!['OWNER','ADMIN','AUTHOR'].includes(actor.role))fail('PUBLISH_DENIED',403);
   const oldReceipt=(await c.query('SELECT fingerprint,payload FROM p22_stage26.receipts WHERE key=$1',[receiptKey])).rows[0];
   if(oldReceipt){if(oldReceipt.fingerprint!==fingerprint)fail('IDEMPOTENCY_CONFLICT',409);return oldReceipt.payload;}
   const current=(await c.query('SELECT * FROM p22_stage26.heads WHERE scope=$1 FOR UPDATE',[snapshot.scope])).rows[0];
   const contentHash=digest({schemaVersion:snapshot.schemaVersion,scope:snapshot.scope,items:snapshot.items});
   if(current?.content_hash===contentHash){await c.query('INSERT INTO p22_stage26.receipts VALUES($1,$2,$3)',[receiptKey,fingerprint,current.payload]);return current.payload;}
   if(number(current?.version||0)!==expectedRevision||snapshot.catalogRevision!==expectedRevision+1)fail('REVISION_CONFLICT',409);
   const hash=digest(snapshot),id='sha256-'+hash;
   await c.query('INSERT INTO p22_stage26.snapshots VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING',[id,snapshot.scope,hash,snapshot]);
   const readback=(await c.query('SELECT payload FROM p22_stage26.snapshots WHERE id=$1',[id])).rows[0];
   if(digest(readback.payload)!==hash)fail('HASH_MISMATCH',422);
   const head={scope:snapshot.scope,catalogRevision:snapshot.catalogRevision,snapshotId:id,snapshotHash:hash,schemaVersion:snapshot.schemaVersion,createdAt:snapshot.createdAt};
   if(!head.createdAt||!Number.isFinite(Date.parse(head.createdAt)))fail('INVALID_DATE',422);
   await c.query('INSERT INTO p22_stage26.heads VALUES($1,$2,$3,$4) ON CONFLICT(scope) DO UPDATE SET version=excluded.version,content_hash=excluded.content_hash,payload=excluded.payload',[head.scope,head.catalogRevision,contentHash,head]);
   await this.inject('afterHeadBeforeOutbox');
   await this.event(c,'head:'+head.scope,head.catalogRevision,head);
   await c.query('INSERT INTO p22_stage26.receipts VALUES($1,$2,$3)',[receiptKey,fingerprint,head]);return head;
  });
 }
 async pending(limit){return (await this.pool.query("SELECT id,key,version FROM p22_stage26.outbox WHERE state='PENDING' ORDER BY id LIMIT $1",[limit])).rows;}
 async attempt(id){await this.pool.query('UPDATE p22_stage26.outbox SET attempts=attempts+1 WHERE id=$1',[id]);}
 async ack(id){await this.pool.query("UPDATE p22_stage26.outbox SET state='DELIVERED' WHERE id=$1",[id]);}
 async latestProjection(key) {
  if(key.startsWith('session:')){const r=await this.session(key.slice(8));return r?{version:r.version,payload:{sid:r.sid,uid:r.uid,iid:r.iid,expiresAt:r.expiresAt,roleVersion:r.roleVersion,revoked:r.revoked,scopes:r.scopes}}:null;}
  if(key==='head:client:public'){const r=(await this.pool.query('SELECT version,payload FROM p22_stage26.heads WHERE scope=$1',['client:public'])).rows[0];return r?{version:number(r.version),payload:r.payload}:null;}
  fail('INVALID_PROJECTION_KEY',422);
 }
 async rebuild() {
  return this.transaction(async c=>{
   // Only this dedicated synthetic schema; no provider-wide KV list/purge.
   for(const row of (await c.query('SELECT sid,version FROM p22_stage26.sessions')).rows)
    await c.query("INSERT INTO p22_stage26.outbox(key,version,payload) VALUES($1,$2,$3) ON CONFLICT(key,version) DO UPDATE SET state='PENDING'",['session:'+row.sid,row.version,await this.session(row.sid,c)]);
   for(const row of (await c.query('SELECT scope,version,payload FROM p22_stage26.heads')).rows)
    await c.query("INSERT INTO p22_stage26.outbox(key,version,payload) VALUES($1,$2,$3) ON CONFLICT(key,version) DO UPDATE SET state='PENDING'",['head:'+row.scope,row.version,row.payload]);
  });
 }
}
