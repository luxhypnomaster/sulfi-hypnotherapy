import test from 'node:test';import assert from 'node:assert/strict';import {execFileSync} from 'node:child_process';import {readFile,mkdtemp,cp,rm} from 'node:fs/promises';
const root=new URL('../',import.meta.url),cli=process.env.P22_NRZ_BIN;
test('official CLI validates the frozen Compute entry and exact Function runtime', {skip:!cli},async()=>{
 const env={...process.env};delete env.NRZ_TOKEN;
 // No provider token, project context or deployment command is used by this test.
 const built=JSON.parse(execFileSync(cli,['build',root.pathname,'--json'],{env,encoding:'utf8'}));
 assert.equal(built.layers[0].entry,'onreza26/compute.mjs');assert.equal(built.layers[0].target,'COMPUTE');
 const dir=await mkdtemp('/dev/shm/task26-fn-');
 try{for(const name of ['light.nrz-fn.mjs','native-probe.nrz-fn.mjs','onreza.rules.toml'])await cp(new URL(name,root),dir+'/'+name);const loaded=JSON.parse(execFileSync(cli,['functions','check',dir,'--json'],{env,encoding:'utf8'}));assert.equal(loaded.runtime.functionsLoaded,2);assert.equal(loaded.edgeRules.ruleCount,3);assert.ok(loaded.functions.some(f=>f.name==='protocol22-native-probe'));}finally{await rm(dir,{recursive:true});}
});
