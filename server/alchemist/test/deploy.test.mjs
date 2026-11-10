import {test} from 'node:test';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
test('missing OAuth and incomplete source never create cloud project or write credentials',()=>{
 const script=new URL('../../../scripts/alchemist/deploy.mjs',import.meta.url);
 const env={...process.env};delete env.CLASPRC_JSON;
 const absent=spawnSync(process.execPath,[script.pathname],{env,encoding:'utf8'});assert.equal(absent.status,78);assert.match(absent.stderr,/GITHUB_SECRET_MISSING/);
 const present=spawnSync(process.execPath,[script.pathname],{env:{...env,CLASPRC_JSON:'SYNTHETIC_NOT_A_CREDENTIAL'},encoding:'utf8'});assert.equal(present.status,78);assert.match(present.stderr,/FULL_SOURCE_NOT_VERIFIED/);assert.doesNotMatch(present.stderr,/SYNTHETIC_NOT_A_CREDENTIAL/);
});
