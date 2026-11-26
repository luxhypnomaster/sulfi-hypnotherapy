// Operator-only read-only research. No application or deploy binding.
import {pathToFileURL} from 'node:url';
import {normalizeWorkspace,normalizeForkUsage} from '../core/billing26a.mjs';
const uuid=s=>typeof s==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(s);
export async function probe({env=process.env,fetcher=fetch,clock=()=>new Date().toISOString()}={}) {
 const record={source:'ONREZA official CLI v0.54.0 OpenAPI',fetchedAt:clock(),tokenPresent:Boolean(env.NRZ_TOKEN),status:'BLOCKED_AUTH',requests:[],workspace:null,fork:null,rawIdentifiersPublished:false};
 if(!env.NRZ_TOKEN)return {...record,reason:'NRZ_TOKEN_MISSING'};
 if(!uuid(env.P22_ONREZA_WORKSPACE_ID))return {...record,status:'BLOCKED_OWNER',reason:'EXPECTED_WORKSPACE_ID_REQUIRED'};
 async function get(path,label){
  const fetchedAt=clock();let status;
  try {
   const r=await fetcher('https://api.onreza.ru'+path,{method:'GET',redirect:'error',signal:AbortSignal.timeout(10000),headers:{Authorization:'Bearer '+env.NRZ_TOKEN,Accept:'application/json'}});status=r.status;
   record.requests.push({endpoint:label,method:'GET',status,fetchedAt});
   if(!r.ok)return null;
   const text=await r.text();if(Buffer.byteLength(text)>262144)throw Error('OVERSIZED_RESPONSE');return JSON.parse(text);
  }catch{if(status===undefined)record.requests.push({endpoint:label,method:'GET',status:'NETWORK_ERROR',fetchedAt});return null;}
 }
 const workspace=await get('/v1/workspace','/v1/workspace');
 if(!workspace){const last=record.requests.at(-1)?.status;return {...record,status:[401,403].includes(last)?'BLOCKED_AUTH':'UNAVAILABLE',reason:last===403?'PERMISSION_DENIED_NO_ESCALATION':last===401?'AUTHORIZATION_REJECTED':'DOCUMENTED_WORKSPACE_READ_NOT_CONFIRMED'};}
 if(workspace.id!==env.P22_ONREZA_WORKSPACE_ID)return {...record,status:'STOP',reason:'WORKSPACE_MISMATCH'};
 record.status='WORKSPACE_READ_VERIFIED';record.workspace=normalizeWorkspace(workspace,{fetchedAt:clock(),sourceType:'PROVIDER_RESPONSE'});
 const user=await get('/v1/user','/v1/user');record.userIdentityVerified=Boolean(user&&uuid(user.id));
 const p=env.P22_ONREZA_PRODUCT_ID,f=env.P22_ONREZA_FORK_ID;
 if(p||f){
  if(!uuid(p)||!uuid(f))return {...record,fork:{status:'BLOCKED_OWNER',reason:'OBSERVED_PRODUCT_AND_FORK_IDS_REQUIRED'}};
  const project=await get('/v1/projects/'+p,'/v1/projects/{observedProductId}');
  if(project?.id!==p)return {...record,fork:{status:'UNAVAILABLE',reason:'PROJECT_READ_NOT_CONFIRMED'}};
  const usage=await get('/v1/product-forks/'+p+'/'+f+'/usage','/v1/product-forks/{observedProductId}/{observedForkId}/usage');
  record.fork=usage?normalizeForkUsage(usage,{fetchedAt:clock(),sourceType:'PROVIDER_RESPONSE'}):{status:'UNAVAILABLE',reason:'FORK_USAGE_READ_NOT_CONFIRMED'};
 }else record.fork={status:'NOT_RUN',reason:'NO_OBSERVED_FORK;_DO_NOT_CREATE_ONE_FOR_BILLING'};
 return record;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 if(!process.argv.includes('--run'))console.log(JSON.stringify({status:'PLAN_ONLY',methods:['GET'],requires:'protected NRZ_TOKEN plus expected workspace ID',createsResources:false}));
 else console.log(JSON.stringify(await probe(),null,2));
}
