import test from 'node:test';import assert from 'node:assert/strict';import {execFileSync} from 'node:child_process';import {readFile,readdir} from 'node:fs/promises';import {createHash} from 'node:crypto';import {createServer} from 'node:http';
const root=new URL('../',import.meta.url);
async function tree(url,prefix='') {const out=[];for(const d of await readdir(url,{withFileTypes:true})){if(d.isDirectory())out.push(...await tree(new URL(d.name+'/',url),prefix+d.name+'/'));else out.push(prefix+d.name);}return out.sort();}
async function hashes(){const files=await tree(new URL('dist/',root));return Promise.all(files.map(async n=>[n,createHash('sha256').update(await readFile(new URL('dist/'+n,root))).digest('hex')]));}
test('curated build is reproducible, excludes Android/GAS/tests/secrets and serves health',async()=>{
 execFileSync(process.execPath,['build.mjs'],{cwd:root});const a=await hashes();execFileSync(process.execPath,['build.mjs'],{cwd:root});assert.deepEqual(await hashes(),a);
 const files=a.map(([n])=>n);assert.ok(files.includes('.onreza/manifest.json'));assert.ok(files.includes('onreza.rules.toml'));
 assert.ok(files.every(n=>!/(\.apk$|\.env|node_modules|test\/|src\/|android|production-target)/.test(n)));
 const {handler}=await import('../dist/onreza26/compute.mjs');const server=createServer(handler());await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try{const res=await fetch('http://127.0.0.1:'+server.address().port+'/healthz');assert.equal(res.status,200);assert.deepEqual(await res.json(),{status:'ok',environment:'staging'});}finally{await new Promise(r=>server.close(r));}
});
test('CORE is free of provider ctx and environment binding dependencies',async()=>{
 for(const file of await readdir(new URL('core/',root))){const s=await readFile(new URL('core/'+file,root),'utf8');assert.ok(!/ctx\.(kv|sql|env)|process\.env|https:\/\/api\.onreza/.test(s),file);}
});
