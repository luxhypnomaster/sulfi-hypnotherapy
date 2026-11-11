import vm from 'node:vm';import {test} from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
const b64=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
test('verified subject grants never trust requested role; wrong audience/issuer/expiry/signature denied',()=>{
 const audience='fixture.apps.googleusercontent.com',now=Math.floor(Date.now()/1000);let signed=true;
 const props={ALCHEMIST_GOOGLE_WEB_CLIENT_ID:audience,ALCHEMIST_OWNER_SUB:'owner',ALCHEMIST_GRANTS:JSON.stringify({editor:['author']})};
 const ctx=vm.createContext({PropertiesService:{getScriptProperties:()=>({getProperty:k=>props[k]})},CacheService:{getScriptCache:()=>({get:()=>JSON.stringify({key:'CERT'})})},AlchemistRsa:{decode:s=>Buffer.from(s,'base64url').toString(),verify:()=>signed}});
 vm.runInContext(readFileSync(new URL('../src/Catalog.js',import.meta.url),'utf8'),ctx);vm.runInContext(readFileSync(new URL('../src/GoogleJwt.js',import.meta.url),'utf8'),ctx);
 const claims={aud:audience,iss:'https://accounts.google.com',sub:'reader',iat:now,exp:now+3600,email:'reader@example.invalid',email_verified:true,roles:['owner']};
 const token=c=>b64({alg:'RS256',kid:'key'})+'.'+b64(c)+'.signature';
 assert.deepEqual(JSON.parse(JSON.stringify(ctx.AlchemistJwt.verify(token(claims)).roles)),['client']);
 assert.equal(ctx.AlchemistJwt.verify(token({...claims,sub:'owner'})).roles[0],'owner');
 for(const c of [{aud:'wrong'},{iss:'evil'},{exp:now-1},{sub:''},{email_verified:false}])assert.throws(()=>ctx.AlchemistJwt.verify(token({...claims,...c})));
 signed=false;assert.throws(()=>ctx.AlchemistJwt.verify(token(claims)));
});
test('16A exact Web audience overrides legacy CI list and all non-owner grant roles',()=>{
 const web='web.apps.googleusercontent.com',ci='ci.apps.googleusercontent.com',now=Math.floor(Date.now()/1000),props={ALCHEMIST_GOOGLE_WEB_CLIENT_ID:web,ALCHEMIST_GOOGLE_AUDIENCES:JSON.stringify([ci,web]),ALCHEMIST_OWNER_SUB:'owner',ALCHEMIST_GRANTS:JSON.stringify({reader:['owner','author']})};
 const c=vm.createContext({PropertiesService:{getScriptProperties:()=>({getProperty:k=>props[k]})},CacheService:{getScriptCache:()=>({get:()=>JSON.stringify({key:'CERT'})})},AlchemistRsa:{decode:s=>Buffer.from(s,'base64url').toString(),verify:()=>true}});for(const f of ['Catalog','GoogleJwt'])vm.runInContext(readFileSync(new URL('../src/'+f+'.js',import.meta.url),'utf8'),c);
 const token=(over={})=>b64({alg:'RS256',kid:'key'})+'.'+b64({aud:web,iss:'https://accounts.google.com',sub:'reader',email:'luxhypnomaster@gmail.com',email_verified:true,iat:now,exp:now+3600,role:'MASTER',roles:['owner'],...over})+'.signature';
 assert.equal(c.AlchemistJwt.verify(token()).role,'CLIENT');assert.equal(c.AlchemistJwt.verify(token({sub:'owner'})).role,'MASTER');assert.throws(()=>c.AlchemistJwt.verify(token({aud:ci,sub:'owner'})));assert.equal(c.AlchemistJwt.verify(token({aud:ci,sub:'owner'}),{audience:ci,ownerSubject:'owner'}).roles[0],'owner');for(const changes of [{nbf:now+1},{iat:now+61},{sub:'__proto__'},{exp:now-1},{aud:['web.apps.googleusercontent.com']}])assert.throws(()=>c.AlchemistJwt.verify(token(changes)));
});
