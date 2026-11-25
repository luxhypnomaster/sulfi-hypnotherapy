import test from 'node:test';import assert from 'node:assert/strict';import {execFileSync} from 'node:child_process';import {readFile,mkdtemp,cp,rm} from 'node:fs/promises';
const root=new URL('../',import.meta.url),cli=process.env.P22_NRZ_BIN;
test('official CLI validates the frozen Compute entry and exact Function runtime', {skip:!cli},async()=>{
 const env={...process.env};delete env.NRZ_TOKEN;
 // No provider token, project context or deployment command is used by this test.
 const built=JSON.parse(execFileSync(cli,['build',root.pathname,'--json'],{env,encoding:'utf8'}));
 assert.equal(built.layers[0].entry,'onreza26/compute.mjs');assert.equal(built.layers[0].target,'COMPUTE');
 const dir=await mkdtemp('/dev/shm/task26-fn-');
 try{await cp(new URL('light.nrz-fn.mjs',root),dir+'/light.nrz-fn.mjs');const loaded=JSON.parse(execFileSync(cli,['functions','check',dir,'--json'],{env,encoding:'utf8'}));assert.equal(loaded.runtime.functionsLoaded,1);assert.equal(loaded.functions[0].name,'protocol22-light');}finally{await rm(dir,{recursive:true});}
});
