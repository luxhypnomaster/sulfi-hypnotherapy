import test from 'node:test';import assert from 'node:assert/strict';import {randomBytes} from 'node:crypto';
import {verify,sign,seal} from '../core/security.mjs';import {createReader} from '../core/reader.mjs';import {MemoryKV} from '../adapters/kv.mjs';import {fixture} from './support.mjs';
const denied=code=>e=>e.code===code;
test('signed JWT with missing scope must not authenticate',()=>{
 const k=randomBytes(32),c={iss:'i',aud:'a',kind:'session',sub:'u',sid:'s',iid:'d',rv:1,scopes:[],iat:10,exp:100};
 assert.throws(()=>verify(sign(c,k),k,{issuer:'i',audience:'a',kind:'session',clock:()=>20}),denied('AUTH_REQUIRED'));
});
test('HEAD reader must refuse adapter lacking version fence even with injected projection',async()=>{
 const k=randomBytes(32),kv=new MemoryKV({namespace:'synthetic26:boundary:',clock:()=>20,monotonicWrite:false});
 const reader=createReader({kv,sessionKey:k,projectionKey:k,clock:()=>20});
 const c={iss:'urn:alchemist:staging26',aud:'protocol22-staging',kind:'session',sub:'u',sid:'s',iid:'d',rv:1,scopes:['client:public'],iat:10,exp:100};
 await kv.put('session:s',seal({version:1,key:'session:s',validUntil:50,payload:{sid:'s',uid:'u',iid:'d',roleVersion:1,expiresAt:100,revoked:false,scopes:['client:public']}},k),30);
 await kv.put('head:client:public',seal({version:1,key:'head:client:public',validUntil:50,payload:{scope:'client:public',catalogRevision:1}},k),30);
 await assert.rejects(reader.head(sign(c,k),'client:public'),denied('ORDERING_NOT_PROVEN'));
});
test('public synthetic snapshot rejects hidden draft/private fields and non-synthetic IDs',async()=>{
 const f=await fixture();try{
  await f.owner();
  for(const patch of [{private:true},{state:'draft'},{contentId:'real-user-record'},{therapy:'private text'}]){
   const s=f.snapshot();Object.assign(s.items[0],patch);
   await assert.rejects(f.repo.publish(f.claims(f.session),{requestId:'test',snapshot:s,expectedRevision:0}),denied('SYNTHETIC_PUBLIC_SCHEMA_REQUIRED'));
  }
 }finally{await f.close();}
});
