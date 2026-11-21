import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const {createSnapshotService,digest}=createRequire(import.meta.url)('../experimental/catalog_snapshot.cjs');
const owner={sub:'owner',roles:['owner']};
const sha='a'.repeat(64);
function fixture(){
 const heads=new Map(), snapshots=new Map(), receipts=new Map();
 let tail=Promise.resolve(), scans=0, fail=false, corrupt=false;
 const records=[];
 const store={lock:(_s,fn)=>{const result=tail.then(fn);tail=result.catch(()=>{});return result;},
 head:async s=>heads.get(s)||null,receipt:async k=>receipts.get(k),
 snapshot:async(s,id)=>snapshots.get(s+id),snapshotReadable:async()=>true,
 putImmutable:async(s,id,v)=>{const key=s+id;if(snapshots.has(key)&&digest(snapshots.get(key))!==digest(v))throw Error('IMMUTABLE');snapshots.set(key,corrupt?{...v,items:[]}:v);},
 commitHeadReceipt:async(s,rev,h,k,r)=>{if(fail)throw Error('STORE_FAILURE');assert.equal(heads.get(s)?.catalogRevision||0,rev);heads.set(s,h);receipts.set(k,r);}};
 const service=createSnapshotService({store,now:()=>new Date(0).toISOString(),
 authorize:async(a,s,w)=>{if(w&&!a?.roles?.includes('owner'))throw Error('AUTHOR_REQUIRED');if(s!=='public'&&a?.sub!==s)throw Error('SCOPE_DENIED');return s;},
 listCommitted:async()=>{scans++;return records;},canExpose:async(r,s)=>r.public||r.owner===s});
 return {service,store,records,heads,snapshots,receipts,get scans(){return scans;},set fail(v){fail=v;},set corrupt(v){corrupt=v;}};
}
const item=(id='track')=>({contentId:id,revisionId:'v1',sha256:sha,state:'published',current:true,public:true,type:'track',title:'Тест',byteLength:2,token:'SECRET',readers:['private'],localReadState:true});
const publish=(f,id,rev=0,scope='public')=>f.service.publish(owner,{requestId:id,scope,ifRevision:rev});
test('20: cheap equal HEAD never scans; strict public projection no reader/secret leakage',async()=>{
 const f=fixture();f.records.push(item());const h=await publish(f,'p');
 for(let i=0;i<6;i++)assert.deepEqual(await f.service.head(null,{scope:'public'}),h);
 assert.equal(f.scans,1);const s=await f.service.snapshot(null,{scope:'public',snapshotId:h.snapshotId});
 assert.equal(digest(s),h.snapshotHash);assert(!JSON.stringify(s).match(/SECRET|readers|localReadState/));
});
test('20: interrupted commit and corrupt readback leave old head and receipt unchanged',async()=>{
 const f=fixture();f.records.push(item());const old=await publish(f,'first');f.records.push(item('second'));f.fail=true;
 await assert.rejects(publish(f,'fail',1),/STORE_FAILURE/);assert.deepEqual(f.heads.get('public'),old);assert.equal(f.receipts.size,1);
 f.fail=false;f.corrupt=true;await assert.rejects(publish(f,'corrupt',1),/READBACK_HASH/);assert.deepEqual(f.heads.get('public'),old);
});
test('20: idempotent retries and concurrent writers use CAS, no lost update',async()=>{
 const f=fixture();f.records.push(item());const first=await publish(f,'one');assert.deepEqual(await publish(f,'one'),first);
 await assert.rejects(publish(f,'one',1),/IDEMPOTENCY/);
 const results=await Promise.allSettled([publish(f,'two',1),publish(f,'three',1)]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(f.heads.get('public').catalogRevision,2);
 await publish(f,'retry',2);assert.equal(f.heads.get('public').catalogRevision,3);
});
test('20: scopes, CLIENT write, unpublished/withdrawn and private dependency fail closed',async()=>{
 const f=fixture();f.records.push({...item(),public:false,owner:'A'});
 const h=await publish(f,'empty');assert.equal((await f.store.snapshot('public',h.snapshotId)).items.length,0);
 await assert.rejects(f.service.head({sub:'B'},{scope:'A'}),/SCOPE_DENIED/);
 await assert.rejects(f.service.publish({sub:'client',roles:['client']},{requestId:'x',scope:'public',ifRevision:1}),/AUTHOR_REQUIRED/);
 f.records.push({...item('module'),dependencies:[{contentId:'track',revisionId:'v1',sha256:sha}]});
 await assert.rejects(publish(f,'invalid',1),/MISSING_EXACT/);
 f.records.splice(0,2,{...item(),state:'withdrawn'});const h2=await publish(f,'withdraw',1);assert.equal((await f.store.snapshot('public',h2.snapshotId)).items.length,0);
});
test('20: 100 items / 20 shared modules, exact old snapshots immutable, one batch one head',async()=>{
 const f=fixture();for(let i=0;i<20;i++)f.records.push({...item('m'+i),type:'module'});
 for(let i=0;i<80;i++)f.records.push({...item('p'+i),type:'template',dependencies:[{contentId:'m'+(i%20),revisionId:'v1',sha256:sha}]});
 const h=await publish(f,'batch'),old=JSON.stringify(await f.store.snapshot('public',h.snapshotId));assert.equal(JSON.parse(old).items.length,100);
 f.records[0]={...f.records[0],title:'quiet change'};await publish(f,'next',1);
 assert.equal(JSON.stringify(await f.store.snapshot('public',h.snapshotId)),old);assert.equal(f.scans,2);
});
test('20: versioned vitrine settings approved defaults, 1..60 validation and CLIENT denial',async()=>{
 const f=fixture();const h=await publish(f,'default');
 const first=await f.store.snapshot('public',h.snapshotId);assert.equal(first.vitrineConfig.splashSeconds,3);assert.equal(first.configRevision,1);
 const cfg={...first.vitrineConfig,splashSeconds:60,entrySeconds:1};
 const h2=await f.service.publish(owner,{requestId:'config',scope:'public',ifRevision:1,vitrineConfig:cfg});
 const next=await f.store.snapshot('public',h2.snapshotId);assert.equal(next.vitrineConfig.entrySeconds,1);assert.equal(next.configRevision,2);
 await assert.rejects(f.service.publish(owner,{requestId:'bad',scope:'public',ifRevision:2,vitrineConfig:{...cfg,entrySeconds:61}}),/INVALID_CONFIG/);
 assert.deepEqual(f.heads.get('public'),h2);
});
test('20: conflicting current revisions cannot publish one logical ID twice',async()=>{
 const f=fixture();f.records.push(item('same'),{...item('same'),revisionId:'v2'});
 await assert.rejects(publish(f,'bad-current'),/INVALID_ITEM/);assert.equal(f.heads.size,0);
});
