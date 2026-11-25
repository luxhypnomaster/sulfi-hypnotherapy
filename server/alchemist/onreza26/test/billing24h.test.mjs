import test from 'node:test';import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';import {mkdtemp,rm} from 'node:fs/promises';
import {BillingCache,normalizeWorkspace} from '../core/billing26a.mjs';
import {PostgresBillingStore,MemoryBillingStore} from '../adapters/billing_store26.mjs';
const DAY=86400000,base={workspace:'synthetic-workspace',environment:'staging',scope:'workspace',period:'current'};
const sample=()=>normalizeWorkspace({subscription:{planSlug:'HOBBY',status:'ACTIVE',currentPeriodEnd:'2026-12-25T10:24:18Z'}},{fetchedAt:'2026-11-25T15:00:00Z'});
function setup({store=new MemoryBillingStore(),adapter,clock}={}){let time=1000,calls=0;
 const cache=new BillingCache({store,clock:clock||(()=>time),authorize:async(actor)=>{if(actor==='CLIENT')throw Error('DENIED');},adapter:adapter||{read:async()=>{calls++;return sample();}}});
 return {cache,store,setTime:v=>time=v,calls:()=>calls};}
async function sqlStore(dir){const db=new PGlite(dir);const pool={query:async(text,args)=>args===undefined?(await db.exec(text)).at(-1):db.query(text,args)};const store=new PostgresBillingStore(pool);await store.migrate();return {db,store};}

test('reading saved summary never performs automatic network request; only entry may refresh',async()=>{
 const f=setup();const empty=await f.cache.read('ADMIN',base);assert.equal(f.calls(),0);assert.equal(empty.fields.plan.value,null);
 const fresh=await f.cache.read('ADMIN',base,{entry:true});assert.equal(f.calls(),1);assert.equal(fresh.cache.lastAttemptAt,1000);assert.equal(fresh.cache.lastSuccessAt,1000);
 f.setTime(DAY*3);const old=await f.cache.read('ADMIN',base);assert.equal(f.calls(),1);assert.equal(old.fields.plan.status,'STALE');
});
test('automatic entry uses a rolling24h boundary, not midnight/calendar-day resets',async()=>{
 const f=setup();await f.cache.read('ADMIN',base,{entry:true});f.setTime(DAY);await f.cache.read('ADMIN',base,{entry:true});assert.equal(f.calls(),1);
 f.setTime(DAY+1000);await f.cache.read('ADMIN',base,{entry:true});assert.equal(f.calls(),2);
});
test('manual refresh bypasses24h and resets next automatic window; provider limits still apply',async()=>{
 const f=setup();await f.cache.read('ADMIN',base,{entry:true});f.setTime(32000);await f.cache.read('ADMIN',base,{manual:true});assert.equal(f.calls(),2);
 f.setTime(DAY+1000);await f.cache.read('ADMIN',base,{entry:true});assert.equal(f.calls(),2);
 f.setTime(DAY+32000);await f.cache.read('ADMIN',base,{entry:true});assert.equal(f.calls(),3);
});
test('failed attempts persist and suppress automatic retry; last successful summary is retained',async()=>{
 let time=1000,n=0;const store=new MemoryBillingStore(),adapter={read:async()=>{n++;if(n>1)throw Error('OFFLINE');return sample();}};
 const make=()=>new BillingCache({store,adapter,authorize:async()=>{},clock:()=>time});
 let c=make();await c.read('ADMIN',base,{entry:true});time+=31000;const failed=await c.read('ADMIN',base,{manual:true});assert.equal(failed.cache.lastSuccessAt,1000);assert.equal(failed.cache.lastAttemptAt,32000);assert.equal(failed.fields.plan.status,'STALE');
 c=make();time+=60000;await c.read('ADMIN',base,{entry:true});assert.equal(n,2);
});
test('separate workspace/environment/scope never share summary or refresh gates',async()=>{
 const f=setup();for(const b of [base,{...base,workspace:'another'},{...base,environment:'production-fixture-only'},{...base,scope:'fork'}])await f.cache.read('ADMIN',b,{entry:true});assert.equal(f.calls(),4);
});
test('period rollover cannot bypass24h and never returns previous period as requested-period data',async()=>{
 const f=setup();await f.cache.read('ADMIN',base,{entry:true});const next=await f.cache.read('ADMIN',{...base,period:'next'},{entry:true});assert.equal(f.calls(),1);assert.equal(next.fields.plan.value,null);
 f.setTime(32000);await f.cache.read('ADMIN',{...base,period:'next'},{manual:true});assert.equal(f.calls(),2);
 const previous=await f.cache.read('ADMIN',base);assert.equal(previous.fields.plan.value,'HOBBY');
});
test('same-process administrators single-flight across periods without cross-period leakage',async()=>{
 let release,calls=0;const wait=new Promise(r=>release=r);const f=setup({adapter:{read:async()=>{calls++;await wait;return sample();}}});
 const first=f.cache.read('ADMIN_A',base,{entry:true});const other=f.cache.read('ADMIN_B',{...base,period:'other'},{entry:true});release();
 const [a,b]=await Promise.all([first,other]);assert.equal(calls,1);assert.equal(a.fields.plan.value,'HOBBY');assert.equal(b.fields.plan.value,null);
});
test('provider429 Retry-After applies to manual requests without infinite retries',async()=>{
 let time=1000,n=0;const cache=new BillingCache({store:new MemoryBillingStore(),authorize:async()=>{},clock:()=>time,adapter:{read:async()=>{n++;const e=Error('RATE');e.status=429;e.retryAfterMs=120000;throw e;}}});
 const r=await cache.read('ADMIN',base,{manual:true});assert.equal(r.cache.lastErrorCode,'PROVIDER_RATE_LIMIT');time+=31000;await cache.read('ADMIN',base,{manual:true});assert.equal(n,1);time+=120000;await cache.read('ADMIN',base,{manual:true});assert.equal(n,2);
});
test('provider timeout cannot pin single-flight forever and late data cannot overwrite cache',async()=>{
 let time=1000,release;const late=new Promise(r=>release=r);const cache=new BillingCache({store:new MemoryBillingStore(),authorize:async()=>{},clock:()=>time,providerTimeoutMs:15,leaseMs:1000,adapter:{read:()=>late}});
 const r=await cache.read('ADMIN',base,{entry:true});assert.equal(r.cache.lastErrorCode,'REFRESH_FAILED');release(sample());await Promise.resolve();const after=await cache.read('ADMIN',base);assert.equal(after.fields.plan.value,null);assert.equal(after.cache.lastSuccessAt,null);
});
test('cache metadata and lastGood survive actual PostgreSQL-engine close/reopen',async()=>{
 const dir=await mkdtemp('/dev/shm/billing24-');let sql=await sqlStore(dir),time=1000,n=0;const adapter={read:async()=>{n++;return sample();}};
 let c=new BillingCache({store:sql.store,authorize:async()=>{},clock:()=>time,adapter});await c.read('ADMIN',base,{entry:true});await sql.db.close();
 sql=await sqlStore(dir);try{time+=60000;c=new BillingCache({store:sql.store,authorize:async()=>{},clock:()=>time,adapter});const r=await c.read('ADMIN',base,{entry:true});assert.equal(n,1);assert.equal(r.cache.lastAttemptAt,1000);assert.equal(r.cache.lastSuccessAt,1000);assert.equal(r.fields.plan.value,'HOBBY');}finally{await sql.db.close();await rm(dir,{recursive:true});}
});
test('two server instances coalesce through an atomic PostgreSQL row claim',async()=>{
 const sql=await sqlStore();let n=0,release,started;const began=new Promise(r=>started=r),wait=new Promise(r=>release=r);
 const adapter={read:async()=>{n++;started();await wait;return sample();}},make=()=>new BillingCache({store:new PostgresBillingStore(sql.store.pool),authorize:async()=>{},clock:()=>1000,adapter});
 try{const a=make(),b=make();const first=a.read('ADMIN_A',base,{entry:true});await began;const second=await b.read('ADMIN_B',base,{entry:true});assert.equal(second.cache.refreshState,'COALESCED_IN_FLIGHT');assert.equal(n,1);release();await first;assert.equal((await b.read('ADMIN_B',base)).fields.plan.value,'HOBBY');}finally{release?.();await sql.db.close();}
});
test('new server instance cannot auto-retry persisted failure before24h',async()=>{
 const sql=await sqlStore();let time=1000,n=0;const adapter={read:async()=>{n++;throw Error('FAIL');}};
 try{let c=new BillingCache({store:sql.store,authorize:async()=>{},clock:()=>time,adapter});await c.read('ADMIN',base,{entry:true});time+=3600000;c=new BillingCache({store:new PostgresBillingStore(sql.store.pool),authorize:async()=>{},clock:()=>time,adapter});const r=await c.read('ADMIN',base,{entry:true});assert.equal(n,1);assert.equal(r.cache.lastAttemptAt,1000);assert.equal(r.cache.lastSuccessAt,null);}finally{await sql.db.close();}
});
