'use strict';
const {createSnapshotService,digest,canonical,config}=require('./catalog_snapshot.cjs');
function fail(status,code){const e=new Error(code);e.status=status;e.code=code;throw e;}
const CONTRACT='alchemist.metadata/1',CANONICAL='sorted-json-utf8-int-v1';
const operations=['catalog.head','catalog.snapshot','vitrine.configRead','vitrine.configPrepare','vitrine.configCommit'];
const errors=new Set(['AUTH_REQUIRED','SCOPE_DENIED','AUTHOR_REQUIRED','CONFIG_WRITE_DENIED','CONFIG_SCOPE_DENIED',
  'INVALID_REQUEST','IDEMPOTENCY_CONFLICT','REVISION_CONFLICT','STALE_SCOPE','SNAPSHOT_UNAVAILABLE',
  'READBACK_HASH_MISMATCH','IMMUTABLE_CONFLICT','PREPARE_DENIED','UNSUPPORTED_SNAPSHOT','INVALID_ITEM',
  'DEPENDENCY_CYCLE','MISSING_EXACT_DEPENDENCY','INVALID_CONFIG','SNAPSHOT_REVOKED',
  'ATOMIC_STORAGE_REQUIRED','HASH_MISMATCH','INVALID_ENVELOPE','UNKNOWN_OPERATION']);
function createMetadataRuntime({store,resolveCredential,now=()=>new Date().toISOString()}) {
  if(store.atomicHeadReceipt!==true)fail(503,'ATOMIC_STORAGE_REQUIRED');
  function authorize(actor,scope,write) {
    if(!actor?.sub || !Number.isSafeInteger(actor.expiresAt) || actor.expiresAt<=Date.parse(now()))fail(401,'AUTH_REQUIRED');
    if(!Array.isArray(actor.scopes) || !actor.scopes.includes(scope))fail(403,'SCOPE_DENIED');
    if(write && !(actor.roles||[]).some(r=>r==='owner'||r==='author'))fail(403,'AUTHOR_REQUIRED');
    return scope;
  }
  function configScope(scope) {
    if(!['master:public','client:public'].includes(scope))fail(403,'CONFIG_SCOPE_DENIED');
    return 'vitrine:public'; // server policy mapping, never from a client hint.
  }
  function writer(actor,scope) {
    authorize(actor,scope,false);
    if(!(actor.roles||[]).includes('owner') && !(actor.permissions||[]).includes('vitrine.write'))fail(403,'CONFIG_WRITE_DENIED');
    return configScope(scope);
  }
  const catalog=createSnapshotService({store,authorize,separateVitrineConfig:true,now,
    listCommitted:()=>store.records(),canExpose:(r,s)=>(r.public===true||r.allowedScopes?.includes(s)) &&
      (!r.validUntil || Date.parse(r.validUntil)>Date.parse(now()))});
  function currentScope(scope) {
    store.assertReadable(scope);
    const h=store.head(scope);
    if(h?.validUntil && Date.parse(h.validUntil)<=Date.parse(now()))fail(403,'STALE_SCOPE');
  }
  async function execute(op,actor,q) {
    authorize(actor,q.scope,false);
    if(op==='metadata.capabilities')return {contract:CONTRACT,schemaVersion:1,canonical:CANONICAL,hash:'sha256',
      scope:q.scope,principalBinding:actor.binding,nonce:q.nonce,atomicHeadReceipt:true,expiresAt:actor.expiresAt,
      configScope:configScope(q.scope),canWriteConfig:(actor.roles||[]).includes('owner')||(actor.permissions||[]).includes('vitrine.write'),operations};
    if(op==='catalog.head') {
      currentScope(q.scope);
      const h=await catalog.head(actor,q);
      if(!h)fail(503,'SNAPSHOT_UNAVAILABLE');
      return {...h,etag:h.snapshotHash,outcome:q.ifSnapshotHash===h.snapshotHash?'NO_CHANGE':'CURRENT',
        vitrineHead:store.head(configScope(q.scope))};
    }
    if(op==='catalog.snapshot'){currentScope(q.scope);return catalog.snapshot(actor,q);}
    if(op==='vitrine.configRead') {
      const scope=configScope(q.scope);store.assertReadable(scope);
      const head=store.head(scope);
      return {head,snapshot:head?store.snapshot(scope,head.snapshotId):null};
    }
    if(op==='vitrine.configPrepare') {
      const scope=writer(actor,q.scope);
      if(!/^[A-Za-z0-9_-]{1,128}$/.test(q.requestId||'') || !Number.isSafeInteger(q.expectedRevision)||q.expectedRevision<0)fail(422,'INVALID_REQUEST');
      const key='prepare-'+digest({sub:actor.sub,requestId:q.requestId});
      const fingerprint=digest(q),old=store.prepare(key);
      if(old) {if(old.owner!==actor.sub||old.value.fingerprint!==fingerprint)fail(409,'IDEMPOTENCY_CONFLICT');return {prepareId:key,head:old.value.head};}
      return store.lock(scope,()=>{
        if((store.head(scope)?.configRevision||0)!==q.expectedRevision)fail(409,'REVISION_CONFLICT');
        const raw=config(q.config),snapshot={schemaVersion:1,scope,configRevision:q.expectedRevision+1,createdAt:now(),config:raw};
        const hash=digest(snapshot),head={schemaVersion:1,scope,configRevision:snapshot.configRevision,createdAt:snapshot.createdAt,snapshotId:'sha256-'+hash,snapshotHash:hash};
        store.putImmutable(scope,head.snapshotId,snapshot);
        if(digest(store.snapshot(scope,head.snapshotId))!==hash)fail(422,'READBACK_HASH_MISMATCH');
        store.savePrepare(key,actor.sub,scope,{fingerprint,head,configHash:digest(raw),expectedRevision:q.expectedRevision});
        return {prepareId:key,head};
      });
    }
    if(op==='vitrine.configCommit') {
      const scope=writer(actor,q.scope);
      if(!/^[A-Za-z0-9_-]{1,128}$/.test(q.requestId||''))fail(422,'INVALID_REQUEST');
      const prepared=store.prepare(q.prepareId);
      if(!prepared||prepared.owner!==actor.sub||prepared.scope!==scope)fail(403,'PREPARE_DENIED');
      const p=prepared.value,key='config:'+actor.sub+':'+q.requestId,fingerprint=digest(q);
      return store.lock(scope,()=>{
        const prior=store.receipt(key);
        if(prior) {if(prior.digest!==fingerprint)fail(409,'IDEMPOTENCY_CONFLICT');return prior.result;}
        const result={requestId:q.requestId,outcome:'COMMITTED',configRevision:p.head.configRevision,configHash:p.configHash,snapshotHead:p.head};
        const receipt=store.commitHeadReceipt(scope,p.expectedRevision,p.head,key,{digest:fingerprint,head:p.head,result});
        return receipt.result;
      });
    }
    fail(404,'UNKNOWN_OPERATION');
  }
  return {
    catalog, // Test/publisher binding only, never exposed as a fake live publish.
    async request(envelope) {
      try {
        if(envelope?.version!==1||!envelope.parameters||typeof envelope.parameters!=='object'||Array.isArray(envelope.parameters))fail(422,'INVALID_ENVELOPE');
        const actor=await resolveCredential(envelope.credential);
        const result=await execute(envelope.operation,actor,envelope.parameters);
        return {ok:true,status:200,result};
      } catch(e) {
        const code=errors.has(e.code||e.message)?e.code||e.message:'SERVER_UNAVAILABLE';
        const status=e.status||({AUTH_REQUIRED:401,SCOPE_DENIED:403,AUTHOR_REQUIRED:403,CONFIG_WRITE_DENIED:403,
          CONFIG_SCOPE_DENIED:403,PREPARE_DENIED:403,STALE_SCOPE:403,SNAPSHOT_REVOKED:403,
          REVISION_CONFLICT:409,IDEMPOTENCY_CONFLICT:409,UNKNOWN_OPERATION:404}[code])||
          (['INVALID_REQUEST','READBACK_HASH_MISMATCH','IMMUTABLE_CONFLICT','UNSUPPORTED_SNAPSHOT','INVALID_ITEM',
            'DEPENDENCY_CYCLE','MISSING_EXACT_DEPENDENCY','INVALID_CONFIG','HASH_MISMATCH','INVALID_ENVELOPE'].includes(code)?422:503);
        return {ok:false,status,error:{code}};
      }
    },
  };
}
module.exports={CONTRACT,CANONICAL,operations,createMetadataRuntime};
