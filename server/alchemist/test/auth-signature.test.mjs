import {test} from 'node:test';import assert from 'node:assert/strict';import vm from 'node:vm';import {readFileSync} from 'node:fs';import {generateKeyPairSync,sign} from 'node:crypto';
const b64=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
test('actual production RSA verifier rejects forged signature and live registry revocation',()=>{
 const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
 const props={ALCHEMIST_GOOGLE_WEB_CLIENT_ID:'test.apps.googleusercontent.com',ALCHEMIST_OWNER_SUB:'owner',ALCHEMIST_AUTH_CONFIG:JSON.stringify({grants:{editor:['author']},revoked:{},version:1})};
 const ctx=vm.createContext({PropertiesService:{getScriptProperties:()=>({getProperty:k=>props[k]})},CacheService:{getScriptCache:()=>({get:()=>JSON.stringify({fixture:publicKey.export({type:'spki',format:'pem'})})})}});
 vm.runInContext(readFileSync(new URL('../../google_apps_script/vendor/jsrsasign.js',import.meta.url),'utf8').replaceAll('SulfiRsa','AlchemistRsa'),ctx);
 for(const f of ['Catalog','GoogleJwt'])vm.runInContext(readFileSync(new URL('../src/'+f+'.js',import.meta.url),'utf8'),ctx);
 const now=Math.floor(Date.now()/1000),header=b64({alg:'RS256',kid:'fixture'}),body=b64({sub:'editor',email:'editor@example.test',email_verified:true,iss:'https://accounts.google.com',aud:props.ALCHEMIST_GOOGLE_WEB_CLIENT_ID,iat:now,exp:now+3600});
 const unsigned=header+'.'+body,token=unsigned+'.'+sign('RSA-SHA256',Buffer.from(unsigned),privateKey).toString('base64url');
 assert.deepEqual(JSON.parse(JSON.stringify(ctx.AlchemistJwt.verify(token).roles)),['client']);
 const forged=header+'.'+b64({sub:'owner',email:'owner@example.test',email_verified:true,iss:'https://accounts.google.com',aud:props.ALCHEMIST_GOOGLE_WEB_CLIENT_ID,iat:now,exp:now+3600})+'.'+token.split('.')[2];
 assert.throws(()=>ctx.AlchemistJwt.verify(forged),/AUTHENTICATION/);
 props.ALCHEMIST_AUTH_CONFIG=JSON.stringify({grants:{},revoked:{editor:true},version:2});
 assert.throws(()=>ctx.AlchemistJwt.verify(token),/IDENTITY_REVOKED/);
});
