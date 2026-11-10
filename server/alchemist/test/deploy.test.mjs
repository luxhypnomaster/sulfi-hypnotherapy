import {test} from 'node:test';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
test('missing OAuth and untrusted branch never create cloud project or write credentials',()=>{
 const script=new URL('../../../scripts/alchemist/deploy.mjs',import.meta.url);
 const env={...process.env};delete env.CLASPRC_JSON;
 const absent=spawnSync(process.execPath,[script.pathname],{env,encoding:'utf8'});assert.equal(absent.status,78);assert.match(absent.stderr,/GITHUB_SECRET_MISSING/);
 const present=spawnSync(process.execPath,[script.pathname],{env:{...env,CLASPRC_JSON:'SYNTHETIC_NOT_A_CREDENTIAL',GITHUB_EVENT_NAME:'pull_request',GITHUB_REF:'refs/pull/999/merge'},encoding:'utf8'});assert.equal(present.status,78);assert.match(present.stderr,/TRUSTED_MAIN_REQUIRED/);assert.doesNotMatch(present.stderr,/SYNTHETIC_NOT_A_CREDENTIAL/);
});
