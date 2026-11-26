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
 if(q.operation==='kv-versioned'){try{return reply(200,{...await versionProbe26b(q,ctx),nativeReleaseBound:typeof ctx.invocation?.releaseId==='string'});}catch(e){return reply(503,{error:e.code??'VERSION_PROBE_FAILED'});}}
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

// №26-Б: isolated synthetic experiment; not a P22 reader/publisher.
export const probe26bScope='synthetic-public-26b';
const encoder26b=new TextEncoder(),decoder26b=new TextDecoder();
function error26b(code){const e=Error(code);e.code=code;return e;}
const hex26b=b=>Array.from(new Uint8Array(b),x=>x.toString(16).padStart(2,'0')).join('');
async function digest26b(s){return hex26b(await crypto.subtle.digest('SHA-256',encoder26b.encode(s)));}
export function keys26b(runId){
 if(!/^[a-f0-9]{24}$/.test(runId??''))throw error26b('INVALID_VERSION_RUN');
 const root='synthetic26:task26:version-probe:'+runId+':',base=root+'staging:public:head:';
 return {root,base,v1:base+'000000000001',v2:base+'000000000002',v3:base+'000000000003',badHash:base+'000000000004',badScope:base+'000000000005',missing:base+'000000000006',neighbor:root+'staging:neighbor:head:000000000999',noTTL:root+'staging:diagnostic:no-ttl'};
}
const owned26b=k=>['v1','v2','v3','badHash','badScope','missing','neighbor','noTTL'].map(n=>k[n]);
export async function envelope26b(runId,revision,scope=probe26bScope){
 const body={schemaVersion:1,scope,runId,revision,snapshot:'synthetic-snapshot-'+revision};
 return JSON.stringify({...body,hash:await digest26b(JSON.stringify(body))});
}
export async function validate26b(raw,key,k,runId){
 try{
  if(!raw||raw.byteLength>512)return null;const d=JSON.parse(decoder26b.decode(raw));
  if(d.schemaVersion!==1||d.scope!==probe26bScope||d.runId!==runId||!Number.isSafeInteger(d.revision)||d.revision<1||d.revision>999999||d.snapshot!=='synthetic-snapshot-'+d.revision||key!==k.base+String(d.revision).padStart(12,'0'))return null;
  const body={schemaVersion:1,scope:d.scope,runId:d.runId,revision:d.revision,snapshot:d.snapshot};
  if(d.hash!==await digest26b(JSON.stringify(body)))return null;
  return {scope:d.scope,revision:d.revision,hash:d.hash,synthetic:true};
 }catch{return null;}
}
export async function scan26b(kv,k,runId){
 const all=[],seen=new Set(),cursors=new Set();let cursor,pages=0;
 try{
  if(typeof kv.list!=='function')return {complete:false,reason:'LIST_BINDING_MISSING',pages:0,selected:null,valid:[]};
  do{
   if(pages>=5)return {complete:false,reason:'PAGINATION_BOUND',pages,selected:null,valid:[]};
   const page=await kv.list({prefix:k.root,limit:2,...(cursor?{cursor}:{})});pages++;
   if(!page||!Array.isArray(page.keys)||page.keys.length>2||page.keys.some(x=>typeof x!=='string')||!(page.cursor==null||typeof page.cursor==='string'))return {complete:false,reason:'LIST_SCHEMA_UNCONFIRMED',pages,selected:null,valid:[]};
   for(const key of page.keys){if(!key.startsWith(k.root)||seen.has(key)||!owned26b(k).includes(key))return {complete:false,reason:'LIST_SCOPE_OR_DUPLICATE_OR_UNKNOWN',pages,selected:null,valid:[]};seen.add(key);all.push(key);}
   cursor=page.cursor||undefined;if(cursor&&cursors.has(cursor))return {complete:false,reason:'CURSOR_CYCLE',pages,selected:null,valid:[]};if(cursor)cursors.add(cursor);
  }while(cursor);
 }catch{return {complete:false,reason:'LIST_CALL_FAILED',pages,selected:null,valid:[]};}
 const valid=[];let invalid=0,ignored=0,missing=0;
 try{for(const key of all){if(!key.startsWith(k.base)){ignored++;continue;}const raw=await kv.get(key);if(!raw){missing++;continue;}const d=await validate26b(raw,key,k,runId);if(d)valid.push({...d,key});else invalid++;}}
 catch{return {complete:false,reason:'GET_CALL_FAILED',pages,selected:null,valid:[]};}
 valid.sort((a,b)=>b.revision-a.revision);
 return {complete:true,pages,keys:all.length,invalid,ignored,missing,selected:valid[0]??null,valid};
}
function public26b(s){return {complete:s.complete,reason:s.reason??null,pages:s.pages,listed:s.keys??0,invalid:s.invalid??0,ignoredNeighborOrDiagnostic:s.ignored??0,missing:s.missing??0,selected:s.selected?{scope:s.selected.scope,revision:s.selected.revision,hash:s.selected.hash,synthetic:true}:null,sqlFreshnessGuaranteed:false,globalConsistencyGuaranteed:false};}
async function immutable26b(kv,key,text,ttl=1200){
 if(encoder26b.encode(text).byteLength>512)throw error26b('OBJECT_LIMIT');
 const old=await kv.get(key);if(old){if(decoder26b.decode(old)!==text)throw error26b('IMMUTABLE_BYTES_CONFLICT');return 'IDENTICAL_REUSE';}
 if(ttl===null)await kv.set(key,text);else await kv.set(key,text,{ttl});
 const got=await kv.get(key);if(!got||decoder26b.decode(got)!==text)throw error26b('WRITE_VERIFY_FAILED');return 'WRITE_VERIFIED';
}
async function capacity26b(kv,k,adding){let count=0,extra=0;for(const key of owned26b(k))if(await kv.get(key))count++;for(const key of adding)if(!await kv.get(key))extra++;if(count+extra>5)throw error26b('FIVE_KEY_LIMIT');}
export async function sweep26b(kv,k,runId){
 const s=await scan26b(kv,k,runId);if(!s.complete||!s.selected||s.selected.revision<2)return {...public26b(s),deletedV1:false,cleanupAllowed:false};
 const old=s.valid.find(d=>d.key===k.v1);if(old){await kv.delete(k.v1);if(await kv.get(k.v1))throw error26b('DELETE_VERIFY_FAILED');}
 return {...public26b(s),deletedV1:!!old,cleanupAllowed:true,retainedSelected:true};
}
export function highWater26b(state,head){
 if(!head||!Number.isSafeInteger(head.revision)||head.revision<1||!/^[a-f0-9]{64}$/.test(head.hash??''))return {accepted:false,state,reason:'INVALID'};
 const old=state[head.scope];if(old&&(head.revision<old.revision||head.revision===old.revision&&head.hash!==old.hash))return {accepted:false,state,reason:'DOWNGRADE_OR_CONFLICT'};
 return {accepted:true,state:{...state,[head.scope]:{revision:head.revision,hash:head.hash}}};
}
export async function versionProbe26b(q,ctx){
 if(q.runId!==ctx.env.P22_VERSION_PROBE_RUN_ID||ctx.env.P22_SYNTHETIC_NAMESPACE!=='synthetic26:task26:')throw error26b('VERSION_RUN_SCOPE_MISMATCH');
 const k=keys26b(q.runId),kv=ctx.kv,steps=['capabilities','seed','select','sweep-v1','publish-v3','late-v1','invalid','no-ttl-create','no-ttl-recover','known-seed','known-read','cleanup'];
 if(!steps.includes(q.step))throw error26b('FIXED_VERSION_STEP_REQUIRED');
 const texts={v1:await envelope26b(q.runId,1),v2:await envelope26b(q.runId,2),v3:await envelope26b(q.runId,3),neighbor:await envelope26b(q.runId,999,'synthetic-neighbor-26b')};
 if(q.step==='capabilities'){const s=await scan26b(kv,k,q.runId);return {status:s.complete?'NATIVE_LIST_CALL_CONFIRMED':'NATIVE_LIST_NOT_CONFIRMED',...public26b(s),noTTLDocumentedNotYetTested:true};}
 if(q.step==='cleanup'){
  const residual=[];for(const key of owned26b(k)){try{await kv.delete(key);if(await kv.get(key))residual.push(Object.keys(k).find(n=>k[n]===key));}catch{residual.push(Object.keys(k).find(n=>k[n]===key));}}
  return {status:residual.length?'CLEANUP_PARTIAL':'CLEANUP_VERIFIED',verifiedMiss:owned26b(k).length-residual.length,residualLabels:residual,scopeOnlyCurrentRun:true};
 }
 if(q.step==='known-seed'){await capacity26b(kv,k,[k.v1]);await immutable26b(kv,k.v1,texts.v1);return {status:'KNOWN_KEY_VERIFIED',versionSelectionProven:false};}
 if(q.step==='known-read'){const d=await validate26b(await kv.get(k.v1),k.v1,k,q.runId);return {status:d?'KNOWN_KEY_READ':'KNOWN_KEY_UNAVAILABLE',selected:d,versionSelectionProven:false};}
 const current=await scan26b(kv,k,q.runId);if(!current.complete)return {status:'NO_MUTATION_INCOMPLETE_LIST',...public26b(current),cleanupAllowed:false};
 if(q.step==='select')return {status:current.selected?'MAX_VISIBLE_VALID':'NO_VALID_OBJECT',...public26b(current)};
 if(q.step==='seed'){await capacity26b(kv,k,[k.v1,k.v2,k.neighbor]);for(const n of ['v1','v2','neighbor'])await immutable26b(kv,k[n],texts[n]);}
 if(q.step==='sweep-v1')return {status:'BOUNDED_SWEEP',...await sweep26b(kv,k,q.runId)};
 if(q.step==='publish-v3'){
  if(await kv.get(k.v1)||!await validate26b(await kv.get(k.v2),k.v2,k,q.runId))throw error26b('PREPUBLICATION_INVARIANT');
  await capacity26b(kv,k,[k.v3]);await immutable26b(kv,k.v3,texts.v3);
 }
 if(q.step==='late-v1'){
  if(!await validate26b(await kv.get(k.v3),k.v3,k,q.runId))throw error26b('V3_REQUIRED');
  await capacity26b(kv,k,[k.v1]);await immutable26b(kv,k.v1,texts.v1);
 }
 if(q.step==='invalid'){
  if(!current.selected||current.selected.revision!==3)throw error26b('V3_REQUIRED');
  const bad=JSON.parse(await envelope26b(q.runId,4));bad.hash='0'.repeat(64);
  await capacity26b(kv,k,[k.badHash,k.badScope]);let tested;
  try{await immutable26b(kv,k.badHash,JSON.stringify(bad));await immutable26b(kv,k.badScope,await envelope26b(q.runId,5,'wrong-synthetic-scope'));tested=await scan26b(kv,k,q.runId);}
  finally{for(const key of [k.badHash,k.badScope]){await kv.delete(key);if(await kv.get(key))throw error26b('INVALID_FIXTURE_CLEANUP_FAILED');}}
  return {status:'INVALID_FIXTURES_CHECKED',...public26b(tested),invalidFixturesRemoved:true,missingObjectRejected:await kv.get(k.missing)===null};
 }
 if(q.step==='no-ttl-create'){
  if(!current.selected||current.selected.revision!==3||await kv.get(k.v1))throw error26b('CLEANUP_AND_V3_REQUIRED');
  await capacity26b(kv,k,[k.noTTL]);await immutable26b(kv,k.noTTL,JSON.stringify({kind:'synthetic26b-no-ttl',runId:q.runId}),null);return {status:'NO_TTL_WRITE_VERIFIED',recoveryKeyPredefined:true,indefinitePersistenceProven:false};
 }
 if(q.step==='no-ttl-recover'){const wasPresent=!!await kv.get(k.noTTL);await kv.delete(k.noTTL);return {status:await kv.get(k.noTTL)?'NO_TTL_RECOVERY_PARTIAL':'NO_TTL_RECOVERY_VERIFIED',wasPresent};}
 return {status:'STEP_VERIFIED',...public26b(await scan26b(kv,k,q.runId))};
}
