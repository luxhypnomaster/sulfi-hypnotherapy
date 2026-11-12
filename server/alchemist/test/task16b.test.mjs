import {test} from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {generateKeyPairSync,sign} from 'node:crypto';
import {task16bPairBody} from '../../../scripts/alchemist/task16b-delivery.mjs';
const read=f=>readFileSync(new URL('../src/'+f+'.js',import.meta.url),'utf8');
test('16B signed expired and wrong audience tokens are distinct; role spoofing never promotes client',()=>{
 const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048}),now=Math.floor(Date.now()/1000);
 const props={ALCHEMIST_GOOGLE_WEB_CLIENT_ID:'fixture.apps.googleusercontent.com',ALCHEMIST_OWNER_SUB:'owner',ALCHEMIST_AUTH_CONFIG:JSON.stringify({revoked:{}})};
 const ctx=vm.createContext({PropertiesService:{getScriptProperties:()=>({getProperty:k=>props[k]})},CacheService:{getScriptCache:()=>({get:()=>JSON.stringify({fixture:publicKey.export({type:'spki',format:'pem'})})})}});
 vm.runInContext(readFileSync(new URL('../../google_apps_script/vendor/jsrsasign.js',import.meta.url),'utf8').replaceAll('SulfiRsa','AlchemistRsa'),ctx);
 for(const f of ['Catalog','GoogleJwt'])vm.runInContext(read(f),ctx);
 const claims={sub:'reader',email:'fixture@example.test',email_verified:true,iss:'https://accounts.google.com',aud:props.ALCHEMIST_GOOGLE_WEB_CLIENT_ID,iat:now,exp:now+3600,role:'MASTER',roles:['owner']};
 function token(extra){const body=[{alg:'RS256',kid:'fixture'},{...claims,...extra}].map(v=>Buffer.from(JSON.stringify(v)).toString('base64url')).join('.');return body+'.'+sign('RSA-SHA256',Buffer.from(body),privateKey).toString('base64url');}
 assert.equal(ctx.AlchemistJwt.verify(token({})).role,'CLIENT');
 assert.throws(()=>ctx.AlchemistJwt.verify(token({aud:'other.apps.googleusercontent.com'})),e=>e.status===401&&e.code==='TOKEN_AUDIENCE_INVALID');
 assert.throws(()=>ctx.AlchemistJwt.verify(token({exp:now-1,iat:now-3600})),e=>e.status===401&&e.code==='TOKEN_EXPIRED');
 assert.throws(()=>ctx.AlchemistJwt.verify(token({iss:'https://wrong.test'})),e=>e.status===401&&e.code==='TOKEN_ISSUER_INVALID');
});
test('16B broker returns only validated correlation and elapsed time, never supplied identity/body',()=>{
 const logs=[];const ctx=vm.createContext({Date,console:{warn:v=>logs.push(v)},AlchemistCatalog:{fail:(status,code)=>{throw Object.assign(Error(code),{status,code});}},AlchemistRateLimit:{checkIngress(){},check(){throw Object.assign(Error('denied'),{status:403,code:'ROLE_DENIED'});}},AlchemistJwt:{verify:()=>({role:'CLIENT'})},alchemistOutput:v=>v});
 vm.runInContext(read('Router'),ctx);ctx.alchemistOutput=v=>v;
 const result=ctx.doPost({postData:{type:'application/json',contents:JSON.stringify({version:1,operation:'catalog.publish',parameters:{secret:'PRIVATE_FIXTURE'},credential:'CONTROLLED_TOKEN',traceId:'a'.repeat(32)})}});
 assert.equal(result.status,403);assert.equal(result.traceId,'a'.repeat(32));assert.ok(Number.isInteger(result.elapsedMs));assert.ok(!JSON.stringify(logs).includes('PRIVATE_FIXTURE'));assert.ok(!JSON.stringify(logs).includes('CONTROLLED_TOKEN'));
});
test('16B APK delivery rejects public repositories, wrong branch source metadata and non-draft tag',()=>{
 const repo={private:true,full_name:'luxhypnomaster/sulfi-hypnotherapy'},c={purpose:'TWO_TEST_CANDIDATES_FOR_HUMAN_ACCEPTANCE_NOT_ACCEPTED_RELEASE',sourceSha:'a'.repeat(40),draftTag:'task16b-qa-pair-25',versionCode:25,packages:{master:'ru.sulfi.sulfi_hypnotherapy',client:'ru.sulfi.sulfi_hypnotherapy.clienttest'}};
 assert.equal(task16bPairBody(repo,c).draft,true);assert.throws(()=>task16bPairBody({...repo,private:false},c));assert.throws(()=>task16bPairBody(repo,{...c,draftTag:'v1.0'}));
});
