import test from 'node:test';import assert from 'node:assert/strict';import fn from '../native-probe.nrz-fn.mjs';
const ctx=()=>({env:{P22_ENVIRONMENT:'staging',P22_SYNTHETIC_NAMESPACE:'synthetic26:controlled:'},invocation:{releaseId:null}});
const req=q=>new Request('https://probe.invalid/_staging/native-probe',{method:'POST',body:JSON.stringify(q)});
test('native probe rejects live releases, wrong stage, methods and arbitrary operations before bindings',async()=>{
 for(const c of [{...ctx(),invocation:{releaseId:'live-release'}},{...ctx(),env:{P22_ENVIRONMENT:'production'}},{...ctx(),invocation:{}}])assert.equal((await fn.fetch(req({operation:'sql-read'}),c)).status,403);
 assert.equal((await fn.fetch(new Request('https://probe.invalid/_staging/native-probe'),ctx())).status,405);
 assert.equal((await fn.fetch(req({operation:'arbitrary-sql',sql:'delete data'}),ctx())).status,422);
});
test('SQL probe executes only fixed read and never returns credentials or raw errors',async()=>{
 const c=ctx();let calls=0;c.sql=async(strings,...values)=>{calls++;assert.equal(strings.join(''),'SELECT 1 AS native_probe_value');assert.equal(values.length,0);return [{native_probe_value:1}];};
 assert.equal((await (await fn.fetch(req({operation:'sql-read'}),c)).json()).status,'PASS_NATIVE_SQL_READ');assert.equal(calls,1);
 c.sql=async()=>{throw Error('private-credential-in-message');};const r=await fn.fetch(req({operation:'sql-read'}),c);assert.equal(r.status,503);assert.ok(!(await r.text()).includes('private-credential'));
});
test('KV experiment demonstrates an older overwrite without granting HEAD authority; cleanup is namespace-only',async()=>{
 const c=ctx(),data=new Map(),keys=[],counter=new Map();c.kv={set:async(k,v,o)=>{assert.equal(o.ttl,60);assert.ok(k.startsWith(c.env.P22_SYNTHETIC_NAMESPACE));data.set(k,new TextEncoder().encode(v));},get:async k=>data.get(k),incr:async k=>{const n=(counter.get(k)||0)+1;counter.set(k,n);return n;},delete:async k=>{keys.push(k);data.delete(k);counter.delete(k);}};
 const r=await (await fn.fetch(req({operation:'kv-order',runId:'a1234567890123456'}),c)).json();assert.equal(r.olderOverwriteObserved,true);assert.equal(r.monotonicWriteGuaranteed,false);assert.equal(r.headPublicationEnabled,false);assert.equal(r.counterSecond,2);assert.equal(r.cleanup,true);assert.equal(keys.length,2);assert.equal(data.size,0);
});
