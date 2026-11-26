import test from 'node:test';import assert from 'node:assert/strict';
import {keys26b,envelope26b,scan26b,sweep26b,highWater26b,versionProbe26b} from '../native-probe.nrz-fn.mjs';
const run='a'.repeat(24),k=keys26b(run),env={P22_VERSION_PROBE_RUN_ID:run,P22_SYNTHETIC_NAMESPACE:'synthetic26:task26:'};
function fixture(){const data=new Map(),deletes=[],writes=[];let max=0;const kv={async get(key){return data.get(key)??null;},async set(key,value,options){assert.ok(key.startsWith(k.root));assert.ok(Buffer.byteLength(value)<=512);writes.push({key,options});data.set(key,new TextEncoder().encode(value));max=Math.max(max,data.size);assert.ok(data.size<=5);},async delete(key){deletes.push(key);data.delete(key);},async list({prefix,limit,cursor}){const keys=[...data.keys()].filter(x=>x.startsWith(prefix)).sort().reverse(),offset=Number(cursor||0);return {keys:keys.slice(offset,offset+limit),cursor:offset+limit<keys.length?String(offset+limit):null};}};return {data,kv,deletes,writes,max:()=>max};}
const step=(f,name)=>versionProbe26b({runId:run,step:name},{env,kv:f.kv});
test('CONTROLLED V1/V2/V3, cursor pages, late identicalV1 and bounded sweep retain V2/V3',async()=>{
 const f=fixture();let r=await step(f,'seed');assert.equal(r.selected.revision,2);assert.equal(r.pages,2);assert.equal(r.ignoredNeighborOrDiagnostic,1);
 r=await step(f,'sweep-v1');assert.equal(r.deletedV1,true);assert.ok(f.data.has(k.v2));await step(f,'publish-v3');
 const bytes=(await f.kv.get(k.v3)).slice();r=await step(f,'late-v1');assert.equal(r.selected.revision,3);assert.ok(f.data.has(k.v1));
 await step(f,'sweep-v1');assert.ok(!f.data.has(k.v1));assert.ok(f.data.has(k.v2));assert.deepEqual(await f.kv.get(k.v3),bytes);assert.ok(f.data.has(k.neighbor));assert.ok(f.max()<=5);
});
test('CONTROLLED invalid hash/scope and missing object never replace lastGood or get deleted as lastGood',async()=>{
 const f=fixture();await step(f,'seed');await step(f,'sweep-v1');await step(f,'publish-v3');const r=await step(f,'invalid');assert.equal(r.invalid,2);assert.equal(r.selected.revision,3);assert.equal(r.missingObjectRejected,true);assert.equal(r.invalidFixturesRemoved,true);assert.ok(f.data.has(k.v2)&&f.data.has(k.v3));assert.equal(f.max(),5);
});
test('CONTROLLED incomplete/error/cyclic pagination forbids selection and cleanup',async()=>{
 for(const list of [async()=>{throw Error('provider unavailable');},async()=>({keys:[k.v1],cursor:'same'}),async()=>({keys:['foreign-key'],cursor:null})]){const f=fixture();await step(f,'seed');f.kv.list=list;const r=await sweep26b(f.kv,k,run);assert.equal(r.complete,false);assert.equal(r.cleanupAllowed,false);assert.equal(f.deletes.length,0);assert.ok(f.data.has(k.v1)&&f.data.has(k.v2));}
});
test('CONTROLLED list missing permits only known-key diagnostic and exact cleanup',async()=>{
 const f=fixture();delete f.kv.list;let r=await step(f,'capabilities');assert.equal(r.complete,false);assert.equal(f.writes.length,0);await step(f,'known-seed');r=await step(f,'known-read');assert.equal(r.selected.revision,1);assert.equal(r.versionSelectionProven,false);r=await step(f,'cleanup');assert.equal(r.status,'CLEANUP_VERIFIED');assert.equal(f.data.size,0);
});
test('CONTROLLED noTTL is one isolated fixed record; restart recovery derives keys from run journal',async()=>{
 const f=fixture();await step(f,'seed');await step(f,'sweep-v1');await step(f,'publish-v3');let r=await step(f,'no-ttl-create');assert.equal(r.status,'NO_TTL_WRITE_VERIFIED');assert.equal(f.writes.find(x=>x.key===k.noTTL).options,undefined);
 const diskJournal=JSON.stringify({runId:run,keys:k});const resumed=JSON.parse(diskJournal);r=await versionProbe26b({runId:resumed.runId,step:'no-ttl-recover'},{env:{...env},kv:f.kv});assert.equal(r.wasPresent,true);assert.equal(r.status,'NO_TTL_RECOVERY_VERIFIED');assert.ok(f.data.has(k.v2)&&f.data.has(k.v3));
});
test('CONTROLLED immutable same-key conflicting bytes abort and current-run cleanup preserves outsider',async()=>{
 const f=fixture();await step(f,'seed');const external='synthetic26:task26:version-probe:'+'b'.repeat(24)+':other';f.data.set(external,new Uint8Array([1]));f.data.set(k.v1,new TextEncoder().encode('tampered'));
 await assert.rejects(step(f,'seed'),e=>e.code==='IMMUTABLE_BYTES_CONFLICT');const r=await step(f,'cleanup');assert.equal(r.status,'CLEANUP_VERIFIED');assert.ok(f.data.has(external));assert.ok(f.deletes.every(x=>x.startsWith(k.root)));
});
test('CONTROLLED high-water rejects lower revision and equal revision/different hash per scope',()=>{
 let s={};const h={scope:'synthetic',revision:3,hash:'a'.repeat(64)};let r=highWater26b(s,h);assert.equal(r.accepted,true);s=r.state;
 for(const lower of [1,2])assert.equal(highWater26b(s,{...h,revision:lower}).accepted,false);assert.equal(highWater26b(s,{...h,hash:'b'.repeat(64)}).accepted,false);assert.equal(highWater26b(s,h).accepted,true);assert.equal(highWater26b(s,{...h,scope:'another',revision:1}).accepted,true);
});
test('CONTROLLED run binding/operation deny before KV and incomplete cleanup reports residual labels',async()=>{
 const f=fixture();await assert.rejects(versionProbe26b({runId:'b'.repeat(24),step:'seed'},{env,kv:f.kv}),e=>e.code==='VERSION_RUN_SCOPE_MISMATCH');await assert.rejects(step(f,'arbitrary-delete'),e=>e.code==='FIXED_VERSION_STEP_REQUIRED');assert.equal(f.writes.length,0);
 f.kv.delete=async()=>{throw Error('offline');};const r=await step(f,'cleanup');assert.equal(r.status,'CLEANUP_PARTIAL');assert.equal(r.residualLabels.length,8);
});
