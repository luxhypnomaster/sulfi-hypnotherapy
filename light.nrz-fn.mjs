// Self-contained, handwritten HTTP Function; no local imports or npm bundle.
// CORE below receives ports. ctx occurs only in the binding at the bottom.
export const config = {name:'protocol22-light'};
const response=(status,body)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
const decode=s=>Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0));
const json=s=>JSON.parse(new TextDecoder().decode(decode(s)));
async function key(encoded) {
 if(typeof encoded!=='string'||!/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)||decode(encoded).length<32)throw Error('CONFIG');
 return crypto.subtle.importKey('raw',decode(encoded),{name:'HMAC',hash:'SHA-256'},false,['verify']);
}
async function validMac(body,signature,k){return crypto.subtle.verify('HMAC',k,decode(signature),new TextEncoder().encode(body));}
export async function light(request,{kv,env,clock=()=>Math.floor(Date.now()/1000)}) {
 const path=new URL(request.url).pathname;
 if(path==='/healthz')return request.method==='GET'?response(200,{status:'ok',environment:'staging'}):response(405,{error:'METHOD_NOT_ALLOWED'});
 if(!['/_staging/session/check','/_staging/catalog/head'].includes(path))return response(404,{error:'NOT_FOUND'});
 if(request.method!=='GET')return response(405,{error:'METHOD_NOT_ALLOWED'});
 let c;
 try {
  if(env.P22_ENVIRONMENT!=='staging')throw Error('CONFIG');
  const t=request.headers.get('Authorization')?.match(/^Bearer ([A-Za-z0-9_.-]+)$/)?.[1];
  if(!t||t.length>4096)throw Error('AUTH');
  const p=t.split('.');if(p.length!==3||p.some(x=>!x||!/^[A-Za-z0-9_-]+$/.test(x)))throw Error('AUTH');
  const h=json(p[0]);c=json(p[1]);
  if(h.alg!=='HS256'||h.typ!=='JWT'||!await validMac(p[0]+'.'+p[1],p[2],await key(env.P22_SYNTHETIC_SESSION_KEY)))throw Error('AUTH');
  if(c.iss!=='urn:alchemist:staging26'||c.aud!=='protocol22-staging'||c.kind!=='session'||!Number.isSafeInteger(c.exp)||c.exp<=clock()||!Number.isSafeInteger(c.iat)||c.iat>clock()||c.exp-c.iat>300||typeof c.sub!=='string'||!c.sub||c.sub.length>200||!/^[A-Za-z0-9_-]{1,128}$/.test(c.sid||'')||!/^[A-Za-z0-9_-]{1,128}$/.test(c.iid||'')||!Number.isSafeInteger(c.rv)||c.rv<1||!Array.isArray(c.scopes)||!c.scopes.includes('client:public')||c.scopes.some(s=>s!=='client:public'))throw Error('AUTH');
 }catch{return response(401,{error:'AUTH_REQUIRED'});}
 try {
  async function read(k){
   const raw=await kv.get(k);if(!raw)throw Error('MISS');
   if(typeof raw.body!=='string'||typeof raw.mac!=='string'||!await validMac(raw.body,raw.mac,await key(env.P22_SYNTHETIC_PROJECTION_KEY)))throw Error('MAC');
   const value=JSON.parse(raw.body);
   if(value.key!==k||!Number.isSafeInteger(value.version)||!Number.isSafeInteger(value.validUntil)||value.validUntil<=clock()||value.validUntil>clock()+30)throw Error('STALE');
   return value.payload;
  }
  const s=await read('session:'+c.sid);
  if(!s||s.sid!==c.sid||s.uid!==c.sub||s.iid!==c.iid||s.roleVersion!==c.rv||s.revoked||s.expiresAt<=clock()||!s.scopes.includes('client:public'))return response(403,{error:'SESSION_REVOKED'});
  if(path.endsWith('/check'))return response(200,{status:'valid',authority:'bounded-basic-session-only',privileged:false});
  // Real ONREZA lacks a documented version fence. No unsafe get+set HEAD.
  if(!kv.capabilities?.monotonicWrite)return response(503,{error:'ORDERING_NOT_PROVEN'});
  const head=await read('head:client:public');
  if(!head||head.scope!=='client:public')throw Error('SCOPE');
  return response(200,head);
 }catch{return response(503,{error:'PROJECTION_UNAVAILABLE'});}
}
export default {async fetch(request,ctx) {
 const ns=ctx.env.P22_SYNTHETIC_NAMESPACE;
 if(!/^synthetic26:[A-Za-z0-9_-]+:$/.test(ns||''))return response(503,{error:'STAGING_CONFIG_REQUIRED'});
 const kv={capabilities:{monotonicWrite:false},async get(k){const r=await ctx.kv.get(ns+k);return r?JSON.parse(new TextDecoder().decode(r)):null;}};
 return light(request,{kv,env:ctx.env});
}};
