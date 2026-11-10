import {test} from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import vm from 'node:vm';import {createHash} from 'node:crypto';
const c=vm.createContext({});vm.runInContext(readFileSync(new URL('../src/AtomicStore.js',import.meta.url),'utf8'),c);
test('crash before atomic head publication leaves both item AND receipt invisible; commit/reopen consistent',()=>{
 let head=null,crash=false;const files=new Map();const io={head:()=>head,read:id=>structuredClone(files.get(id)),digest:s=>createHash('sha256').update(s).digest('hex'),writeVerified:o=>{const id=String(files.size+1);files.set(id,structuredClone(o));return id;},setHead:id=>{if(crash)throw Error('crash');head=id;}};
 let s=c.AlchemistAtomicStore.create(io);s.begin();s.commit({id:'a',etag:'1',title:'old'});s.saveReceipt('owner:1',{result:'old'});s.commitTransaction();const oldHead=head;
 s.begin();s.commit({id:'a',etag:'2',title:'new'});s.saveReceipt('owner:2',{result:'new'});crash=true;assert.throws(()=>s.commitTransaction(),/crash/);assert.equal(head,oldHead);
 s=c.AlchemistAtomicStore.create(io);assert.equal(s.item('a').title,'old');assert.equal(s.receipt('owner:2'),null);
 crash=false;s.begin();s.commit({id:'a',etag:'2',title:'new'});s.saveReceipt('owner:2',{result:'new'});s.commitTransaction();s=c.AlchemistAtomicStore.create(io);assert.equal(s.item('a').title,'new');assert.equal(s.receipt('owner:2').result,'new');assert.equal(s.items().length,1);
});
test('media/checkpoint writes do not invalidate catalog pagination revision',()=>{
 let head=null;const files=new Map(),io={head:()=>head,read:id=>structuredClone(files.get(id)),digest:s=>createHash('sha256').update(s).digest('hex'),writeVerified:o=>{const id=String(files.size+1);files.set(id,structuredClone(o));return id;},setHead:id=>head=id};
 const s=c.AlchemistAtomicStore.create(io);s.begin();s.commit({id:'card',etag:'1'});s.commitTransaction();const revision=s.indexRevision();
 s.begin();s.put('upload:session',{offset:262144});s.commitTransaction();assert.equal(s.indexRevision(),revision);
});
