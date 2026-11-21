import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {SqliteSnapshotStore}=require('../experimental/sqlite_snapshot_store.cjs');
const {createMetadataRuntime}=require('../experimental/metadata_runtime.cjs');
const {digest,defaultConfig}=require('../experimental/catalog_snapshot.cjs');
const now=()=> '2026-11-21T00:00:00.000Z';
const owner={sub:'synthetic-owner',binding:'owner-binding',roles:['owner'],scopes:['master:public','client:public'],expiresAt:Date.parse(now())+100000};
const client={sub:'synthetic-client',binding:'client-binding',roles:['client'],scopes:['client:public'],expiresAt:owner.expiresAt};
function fixture(){
 const root=mkdtempSync(join(tmpdir(),'sulfi21-')),file=join(root,'sandbox.sqlite');
 const store=new SqliteSnapshotStore(file),runtime=createMetadataRuntime({store,now,resolveCredential:t=>t==='owner-fixture'?owner:t==='client-fixture'?client:null});
 const request=(operation,parameters={},credential='owner-fixture')=>runtime.request({version:1,operation,credential,parameters:{scope:'master:public',...parameters}});
 const record={catalogItemId:'card1',contentId:'module1',revisionId:'v1',type:'module',state:'published',current:true,public:true,title:'Синтетический модуль',sha256:'a'.repeat(64),byteLength:0,dependencies:[]};
 store.putRecord(record);
 return {root,file,store,runtime,request,record,close(){store.close();rmSync(root,{recursive:true,force:true});}};
}
test('21 genuine SQLite immutable persistence, cold reopening and readback guards',async()=>{
 const f=fixture();try{
 const head=await f.runtime.catalog.publish(owner,{scope:'master:public',requestId:'p',ifRevision:0});
 const s=f.store.snapshot('master:public',head.snapshotId);assert.equal(digest(s),head.snapshotHash);assert.equal(s.vitrineConfig,undefined);
 assert.throws(()=>f.store.db.prepare('UPDATE immutable SET payload=?').run('{}'),/IMMUTABLE/);
 const cold=new SqliteSnapshotStore(f.file);assert.deepEqual(cold.head('master:public'),head);cold.close();
 assert.throws(()=>f.store.putImmutable('master:public',head.snapshotId,{broken:true}),/HASH_MISMATCH/);
 }finally{f.close();}
});
test('21 actual SQLite rollback between pointer update and receipt, SIGKILL recovery',async()=>{
 const f=fixture();try{
 const old=await f.runtime.catalog.publish(owner,{scope:'master:public',requestId:'first',ifRevision:0});
 f.store.putRecord({...f.record,title:'next'});f.store.inject=phase=>{if(phase==='afterHeadBeforeReceipt')throw Error('INJECTED_IO');};
 await assert.rejects(f.runtime.catalog.publish(owner,{scope:'master:public',requestId:'fail',ifRevision:1}));assert.deepEqual(f.store.head('master:public'),old);assert.equal(f.store.receipt('synthetic-owner:fail'),null);
 f.store.inject=()=>{};
 const snapshot={...f.store.snapshot('master:public',old.snapshotId),catalogRevision:2};
 const h={...old,catalogRevision:2,snapshotHash:digest(snapshot),snapshotId:'sha256-'+digest(snapshot)};f.store.putImmutable('master:public',h.snapshotId,snapshot);
 const script=`const {SqliteSnapshotStore}=require(${JSON.stringify(resolve('server/alchemist/experimental/sqlite_snapshot_store.cjs'))});const s=new SqliteSnapshotStore(process.argv[1],{inject:p=>{if(p==='afterHeadBeforeReceipt')process.kill(process.pid,'SIGKILL')}});s.commitHeadReceipt('master:public',1,JSON.parse(process.argv[2]),'crash',{digest:'x',head:JSON.parse(process.argv[2])});`;
 const killed=spawnSync(process.execPath,['-e',script,f.file,JSON.stringify(h)],{timeout:10000});assert.equal(killed.signal,'SIGKILL');
 const cold=new SqliteSnapshotStore(f.file);assert.deepEqual(cold.head('master:public'),old);assert.equal(cold.receipt('crash'),null);cold.close();
 }finally{f.close();}
});
test('21 lost response after durable COMMIT replays same receipt; cross-connection writers CAS',async()=>{
 const f=fixture();try{
 let lost=true;f.store.inject=p=>{if(p==='afterCommit'&&lost){lost=false;throw Error('LOST_RESPONSE');}};
 const q={scope:'master:public',requestId:'lost',ifRevision:0};await assert.rejects(f.runtime.catalog.publish(owner,q));
 const retry=await f.runtime.catalog.publish(owner,q);assert.deepEqual(retry,f.store.head('master:public'));assert.equal(retry.catalogRevision,1);
 const other=new SqliteSnapshotStore(f.file),r=createMetadataRuntime({store:other,now,resolveCredential:()=>owner});
 const both=await Promise.allSettled([f.runtime.catalog.publish(owner,{scope:'master:public',requestId:'a',ifRevision:1}),r.catalog.publish(owner,{scope:'master:public',requestId:'b',ifRevision:1})]);
 assert.equal(both.filter(x=>x.status==='fulfilled').length,1);assert.equal(f.store.head('master:public').catalogRevision,2);other.close();
 }finally{f.close();}
});
test('21 null/expired principal, scope switch, CLIENT write, role hints deny; errors redact secrets',async()=>{
 const f=fixture();try{
 assert.equal((await f.request('metadata.capabilities',{roles:['owner']},'wrong-secret')).status,401);
 assert.equal((await f.request('metadata.capabilities',{},'client-fixture')).status,403);
 assert.equal((await f.request('vitrine.configPrepare',{scope:'client:public',role:'owner',requestId:'bad',config:defaultConfig,expectedRevision:0},'client-fixture')).status,403);
 const cap=await f.request('metadata.capabilities',{scope:'client:public',nonce:'n'},'client-fixture');assert.equal(cap.result.principalBinding,'client-binding');assert.equal(cap.result.nonce,'n');assert.equal(cap.result.canWriteConfig,false);
 const revoked=createMetadataRuntime({store:f.store,now,resolveCredential:()=>({...client,expiresAt:0})});assert.equal((await revoked.request({version:1,operation:'metadata.capabilities',parameters:{scope:'client:public'}})).status,401);
 const error=createMetadataRuntime({store:f.store,now,resolveCredential:()=>{throw Error('PRIVATE_TOKEN_PATH');}});assert.equal(JSON.stringify(await error.request({version:1,operation:'metadata.capabilities',parameters:{scope:'client:public'}})).includes('PRIVATE_TOKEN_PATH'),false);
 }finally{f.close();}
});
test('21 separate config prepare/commit -> CLIENT, no unrelated catalog revision bump',async()=>{
 const f=fixture();try{
 const catalog=await f.runtime.catalog.publish(owner,{scope:'client:public',requestId:'catalog',ifRevision:0});
 const prepared=await f.request('vitrine.configPrepare',{requestId:'cfg_p',expectedRevision:0,config:{...defaultConfig,entrySeconds:11}});
 assert.equal(prepared.status,200);assert.equal(f.store.head('vitrine:public'),null);
 const q={requestId:'cfg',prepareId:prepared.result.prepareId};const receipt=await f.request('vitrine.configCommit',q);assert.equal(receipt.result.configRevision,1);assert.deepEqual(await f.request('vitrine.configCommit',q),receipt);
 const view=await f.request('vitrine.configRead',{scope:'client:public'},'client-fixture');assert.equal(digest(view.result.snapshot),view.result.head.snapshotHash);assert.equal(view.result.snapshot.config.entrySeconds,11);
 assert.deepEqual(f.store.head('client:public'),catalog);
 const head=await f.request('catalog.head',{scope:'client:public',ifSnapshotHash:catalog.snapshotHash},'client-fixture');assert.equal(head.result.outcome,'NO_CHANGE');assert.equal(head.result.vitrineHead.configRevision,1);
 }finally{f.close();}
});
test('21 withdrawal/epoch invalidates stale scope, partial/non-atomic storage fail closed',async()=>{
 const f=fixture();try{
 await f.runtime.catalog.publish(owner,{scope:'client:public',requestId:'before',ifRevision:0});f.store.putRecord({...f.record,state:'withdrawn'});f.store.invalidateScope('client:public');
 assert.equal((await f.request('catalog.head',{scope:'client:public'},'client-fixture')).status,403);
 await f.runtime.catalog.publish(owner,{scope:'client:public',requestId:'after',ifRevision:1});const h=f.store.head('client:public');assert.equal(f.store.snapshot('client:public',h.snapshotId).items.length,0);
 f.store.atomicHeadReceipt=false;assert.throws(()=>createMetadataRuntime({store:f.store,now,resolveCredential:()=>owner}),/ATOMIC_STORAGE_REQUIRED/);
 }finally{f.close();}
});
test('21 expiry rejects stale HEAD and snapshot without scan or mutation of prior immutable bytes',async()=>{
 const f=fixture();try{
 let clock=now();const runtime=createMetadataRuntime({store:f.store,now:()=>clock,resolveCredential:()=>owner});
 f.store.putRecord({...f.record,validUntil:'2026-11-21T00:00:01.000Z'});
 const h=await runtime.catalog.publish(owner,{scope:'client:public',requestId:'exp',ifRevision:0});
 const bytes=JSON.stringify(f.store.snapshot('client:public',h.snapshotId));clock='2026-11-21T00:00:02.000Z';
 const q=operation=>runtime.request({version:1,operation,parameters:{scope:'client:public',snapshotId:h.snapshotId}});
 assert.equal((await q('catalog.head')).status,403);assert.equal((await q('catalog.snapshot')).status,403);
 assert.equal(JSON.stringify(f.store.snapshot('client:public',h.snapshotId)),bytes);
 await runtime.catalog.publish(owner,{scope:'client:public',requestId:'exp-next',ifRevision:1});
 assert.equal((await q('catalog.head')).status,200);
 }finally{f.close();}
});
