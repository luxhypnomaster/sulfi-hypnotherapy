import {verify,unseal,checkSession,fail} from './security.mjs';
export function createReader({kv,authority=null,sessionKey,projectionKey,clock}) {
 async function read(key) {
  let value;try {value=await kv.get(key);}catch {fail('PROJECTION_UNAVAILABLE');}
  if(value===null)return null;
  const e=unseal(value,projectionKey);
  if(e.key!==key||!Number.isSafeInteger(e.version)||!Number.isSafeInteger(e.validUntil)||e.validUntil<=clock()||e.validUntil>clock()+30)fail('PROJECTION_UNAVAILABLE');
  return e.payload;
 }
 async function authenticate(token,{sensitive=false}={}) {
  const c=verify(token,sessionKey,{issuer:'urn:alchemist:staging26',audience:'protocol22-staging',kind:'session',clock});
  let row;
  if(sensitive) {
   if(!authority)fail('AUTHORITY_UNAVAILABLE');row=await authority.session(c.sid);
  } else {
   row=await read('session:'+c.sid);
   if(row===null) {if(!authority)fail('AUTHORITY_UNAVAILABLE');row=await authority.session(c.sid);}
  }
  const actor=checkSession(row,c,clock());return {...actor,claims:c};
 }
 return {authenticate,async head(token,scope) {
  if(scope!=='client:public')fail('SCOPE_DENIED',403);
  if(!kv.capabilities?.monotonicWrite)fail('ORDERING_NOT_PROVEN');
  await authenticate(token);
  const head=await read('head:'+scope);if(!head)fail('HEAD_UNAVAILABLE');
  if(head.scope!==scope)fail('SCOPE_DENIED',403);
  return head; // Exact HEAD fields only; projection metadata stays out of wire.
 }};
}
