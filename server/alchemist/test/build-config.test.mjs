import {test} from 'node:test';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';import {readFileSync} from 'node:fs';
const config=JSON.parse(readFileSync('server/alchemist/android-oauth-public.json')),endpoint='https://script.google.com/macros/s/UNIT_ONLY/exec';
function run(e={},body={}){return spawnSync(process.execPath,['--input-type=module','--eval',`globalThis.fetch=async()=>({json:async()=>(${JSON.stringify(body)})});await import('./scripts/alchemist/check-build-config.mjs');`],{encoding:'utf8',env:{...process.env,ALCHEMIST_API:endpoint,GOOGLE_WEB_CLIENT_ID:config.webClientId,...e}});}
test('16-A connected APK gate rejects missing endpoint, mismatched Web audience, old or incompletely bootstrapped server',()=>{
 assert.equal(run({ALCHEMIST_API:''}).status,78);assert.equal(run({GOOGLE_WEB_CLIENT_ID:'wrong.apps.googleusercontent.com'}).status,1);
 for(const result of [{name:'Сервер Проекта Алхимик',fullSourceReady:true},{name:'Сервер Проекта Алхимик',fullSourceReady:true,authorizationPolicyVersion:2,webClientId:'wrong.apps.googleusercontent.com'}])assert.equal(run({}, {ok:true,status:200,result}).status,1);
 const ready=run({}, {ok:true,status:200,result:{name:'Сервер Проекта Алхимик',fullSourceReady:true,authorizationPolicyVersion:2,webClientId:config.webClientId}});assert.equal(ready.status,0);assert.match(ready.stdout,/VERIFIED_SERVER_CONFIGURATION/);
});
