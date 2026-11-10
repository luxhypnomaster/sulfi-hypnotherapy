import vm from 'node:vm';import {test} from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {createHash,randomBytes} from 'node:crypto';
const c=vm.createContext({});vm.runInContext(readFileSync(new URL('../src/Sha256.js',import.meta.url),'utf8'),c);
test('stream SHA equals native SHA across padding boundaries, megabytes and process checkpoint resumes',()=>{
 for(const size of [0,1,55,56,63,64,65,127,128,262144,3*1024*1024+17]){
 const bytes=randomBytes(size);let h=c.AlchemistSha256.create();
 for(let i=0;i<size;i+=8191){h.update(bytes.subarray(i,Math.min(size,i+8191)));const saved=JSON.parse(JSON.stringify(h.snapshot()));assert.ok(JSON.stringify(saved).length<1000);h=c.AlchemistSha256.create(saved);}
 const expected=createHash('sha256').update(bytes).digest('hex');assert.equal(h.hex(),expected);assert.equal(h.hex(),expected);assert.equal(h.snapshot().bytes,size);
 }
});
