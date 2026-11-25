// Bounded STAGING diagnostic. A separate random capability is required before bindings.
// Only its SHA256 is configured; the capability is never the provider admin token.
export const config={name:'protocol22-native-probe'};
const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
export default {async fetch(request,ctx){
 if(ctx.env.P22_ENVIRONMENT!=='staging')return reply(403,{error:'STAGING_ONLY'});
 const now=Math.floor(Date.now()/1000),until=Number(ctx.env.P22_NATIVE_PROBE_UNTIL),expected=ctx.env.P22_NATIVE_PROBE_SHA256;
 if(ctx.env.P22_NATIVE_PROBE_MODE!=='diagnostic-window'||!Number.isSafeInteger(until)||until<=now||until>now+1200||!/^[a-f0-9]{64}$/.test(expected??''))return reply(403,{error:'DIAGNOSTIC_WINDOW_CLOSED'});
 const capability=request.headers.get('Authorization')?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
 if(!capability)return reply(401,{error:'DIAGNOSTIC_AUTH_REQUIRED'});
 const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(capability)));
 const wanted=Uint8Array.from(expected.match(/../g),h=>parseInt(h,16));let difference=0;for(let i=0;i<32;i++)difference|=digest[i]^wanted[i];
 if(difference!==0)return reply(401,{error:'DIAGNOSTIC_AUTH_REQUIRED'});
 if(request.method!=='POST')return reply(405,{error:'METHOD_NOT_ALLOWED'});
 const path=new URL(request.url).pathname;
 if(path!=='/_staging/native-probe')return reply(404,{error:'NOT_FOUND'});
 let text='',bytes=0;
 try{for await(const b of request.body??[]){bytes+=b.byteLength;if(bytes>512)return reply(413,{error:'BODY_TOO_LARGE'});text+=new TextDecoder().decode(b);if(text.length>512)return reply(413,{error:'BODY_TOO_LARGE'});}}catch{return reply(400,{error:'INVALID_BODY'});}
 let q;try{q=JSON.parse(text);}catch{return reply(400,{error:'INVALID_JSON'});}
 if(q.operation==='sql-read'){
  try{
   const result=await ctx.sql`SELECT 1 AS native_probe_value`;
   const rows=Array.isArray(result)?result:result?.rows;
   return reply(rows?.[0]?.native_probe_value===1?200:503,{status:rows?.[0]?.native_probe_value===1?'PASS_NATIVE_SQL_READ':'UNEXPECTED_SQL_RESULT',writes:0,nativeReleaseBound:typeof ctx.invocation?.releaseId==='string'});
  }catch(e){return reply(503,{status:'BLOCKED_NATIVE_SQL',code:typeof e?.code==='string'&&/^[A-Z0-9_]{1,60}$/.test(e.code)?e.code:'SQL_BINDING_FAILED',writes:0,nativeReleaseBound:typeof ctx.invocation?.releaseId==='string'});}
 }
 if(q.operation==='kv-order'){
  if(!/^[a-z0-9]{16,32}$/.test(q.runId??''))return reply(422,{error:'INVALID_PROBE_ID'});
  const ns=ctx.env.P22_SYNTHETIC_NAMESPACE;
  if(!/^synthetic26:[A-Za-z0-9_-]+:$/.test(ns??''))return reply(503,{error:'STAGING_NAMESPACE_REQUIRED'});
  const k=ns+'native-order:'+q.runId,c=k+':counter';let observation,cleanup=true;
  try{
   await ctx.kv.set(k,JSON.stringify({revision:2}),{ttl:60});
   const first=await ctx.kv.get(k);
   await ctx.kv.set(k,JSON.stringify({revision:1}),{ttl:60});
   const second=await ctx.kv.get(k);
   const a=await ctx.kv.incr(c,{ttl:60}),b=await ctx.kv.incr(c,{ttl:60});
   const decode=raw=>raw?JSON.parse(new TextDecoder().decode(raw)).revision:null;
   observation={status:'OBSERVATION_ONLY',readAfterNewer:decode(first),readAfterOlder:decode(second),olderOverwriteObserved:decode(second)===1,counterFirst:a,counterSecond:b,monotonicWriteGuaranteed:false,headPublicationEnabled:false};
  }catch{observation={status:'BLOCKED_NATIVE_KV',monotonicWriteGuaranteed:false,headPublicationEnabled:false};}
  finally{for(const key of [k,c])try{await ctx.kv.delete(key);}catch{cleanup=false;}}
  return reply(observation.status==='OBSERVATION_ONLY'?200:503,{...observation,cleanup,ttlSeconds:60,nativeReleaseBound:typeof ctx.invocation?.releaseId==='string'});
 }
 return reply(422,{error:'FIXED_DIAGNOSTIC_OPERATION_REQUIRED'});
}};
