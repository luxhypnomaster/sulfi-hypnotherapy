// Proposal-only portable BillingAdapter contract; not mounted in P22 or Android.
export const fieldStatuses=Object.freeze(['ACTUAL','ESTIMATE','STALE','UNAVAILABLE','PENDING']);
export const discoveryStatuses=Object.freeze(['DOCUMENTED','VERIFIED_LIVE','BLOCKED_AUTH','NOT_DOCUMENTED','UNAVAILABLE','PENDING']);
export const billingCapabilities=Object.freeze(Object.fromEntries(['plan','periodStart','periodEnd','periodTimeZone','includedCredit','appliedCredit','remainingCredit','grossCharges','forecast','subscription','invoices','quotas'].map(k=>[k,{discovery:['plan','periodEnd','subscription'].includes(k)?'DOCUMENTED':'NOT_DOCUMENTED',supportedDirect:['plan','periodEnd','subscription'].includes(k),verifiedLive:false}])));
const empty=(reason,scope='workspace')=>({value:null,status:'UNAVAILABLE',reason,scope,currency:null,unit:null,measuredAt:null,reconciledAt:null,fetchedAt:null,periodStart:null,periodEnd:null,timeZone:null,derived:false});
export function unavailableBilling(reason='API_NOT_DOCUMENTED') {
 return {scope:'workspace',capabilities:structuredClone(billingCapabilities),source:{provider:'ONREZA',contract:'official-cli-openapi/0.54.0'},fields:Object.fromEntries(['plan','periodStart','periodEnd','periodTimeZone','includedCredit','appliedCredit','remainingCredit','grossCharges','forecast','subscription','invoices','quotas'].map(k=>[k,empty(reason)]))};
}
const validDate=s=>typeof s==='string'&&/T.*(?:Z|[+-]\d\d:\d\d)$/.test(s)&&Number.isFinite(Date.parse(s));
export function normalizeWorkspace(raw,{fetchedAt,sourceType='CONTROLLED_FIXTURE'}={}) {
 const result=unavailableBilling();
 result.source={...result.source,type:sourceType,fetchedAt};
 for(const k of ['plan','subscription','periodEnd'])result.fields[k]={...empty('FIELD_NOT_PROVIDED'),fetchedAt};
 const plan=raw?.subscription?.planSlug;
 if(!['HOBBY','PRO'].includes(plan)||!validDate(fetchedAt))return result;
 // The API returns subscription metadata, NOT credit or invoice amounts.
 result.fields.plan={...empty(null),value:plan,status:'ACTUAL',reason:null,fetchedAt};
 const subscriptionStatus=['ACTIVE','CANCELLED'].includes(raw.subscription.status)?raw.subscription.status:null;
 result.fields.subscription={...empty(subscriptionStatus?null:'FIELD_NOT_PROVIDED'),value:subscriptionStatus,status:subscriptionStatus?'ACTUAL':'UNAVAILABLE',fetchedAt};
 const end=raw.subscription.currentPeriodEnd;
 if(validDate(end))result.fields.periodEnd={...empty(null),value:end,status:'ACTUAL',fetchedAt};
 // Fetch time is not measurement time; do not fabricate start or billing timezone.
 return result;
}
export function normalizeForkUsage(raw,{fetchedAt,sourceType='CONTROLLED_FIXTURE'}={}) {
 const scope='fork',base={...empty('FRESHNESS_SEMANTICS_UNVERIFIED',scope),status:'PENDING',fetchedAt};
 const currency=typeof raw?.currency==='string'?raw.currency:null;
 const minor=typeof raw?.knownGrossCostCents==='string'&&/^-?\d+$/.test(raw.knownGrossCostCents)?raw.knownGrossCostCents:null;
 const period=raw?.period;
 return {scope,coverage:raw?.coverage??'UNAVAILABLE',source:{provider:'ONREZA',contract:'official-cli-openapi/0.54.0',type:sourceType},
  // knownGross is never relabelled as workspace total or applied credit.
  knownGross:{...base,value:minor,currency,unit:'provider-cent-string',reconciledAt:validDate(raw?.lastReconciledAt)?raw.lastReconciledAt:null,
   periodStart:validDate(period?.start)?period.start:null,periodEnd:validDate(period?.end)?period.end:null,
   reason:minor===null?'AMOUNT_NOT_PROVIDED':'PARTIAL_SCOPE_AND_FRESHNESS_UNVERIFIED'},
  freshness:typeof raw?.freshness==='string'?raw.freshness:'UNAVAILABLE',
  itemCount:Array.isArray(raw?.items)?raw.items.length:0,
  // Raw resource IDs, unknown limitation strings and arbitrary fields never pass through.
  breakdown:Array.isArray(raw?.items)?raw.items.map(item=>({resourceType:typeof item.resourceType==='string'?item.resourceType:'unknown',moduleKey:typeof item.moduleKey==='string'?item.moduleKey:null,meterKey:typeof item.meterKey==='string'?item.meterKey:null,quantity:typeof item.quantity==='string'?item.quantity:null,unit:typeof item.unit==='string'?item.unit:null,grossAmountCents:typeof item.grossAmountCents==='string'&&/^-?\d+$/.test(item.grossAmountCents)?item.grossAmountCents:null})):[],
  remainingCredit:empty('NOT_A_WORKSPACE_CREDIT_SOURCE')};
}
export function deriveRemainingCredit({grant,grantAdjustments,applied}) {
 const fields=[grant,grantAdjustments,applied];
 if(fields.some(f=>!f||f.status!=='ACTUAL'||f.authoritative!==true||typeof f.value!=='string'||!/^[-]?\d+$/.test(f.value)))return empty('AUTHORITATIVE_COMPONENTS_REQUIRED');
 for(const key of ['scopeBinding','periodBinding','currency','unit','measuredAt']) {
  if(!fields[0][key]||fields.some(f=>f[key]!==fields[0][key]))return {...empty('INCONSISTENT_COMPONENTS'),status:'PENDING'};
 }
 if(BigInt(grant.value)<0n||BigInt(applied.value)<0n)return {...empty('INVALID_CREDIT_COMPONENTS'),status:'PENDING'};
 const balance=BigInt(grant.value)+BigInt(grantAdjustments.value)-BigInt(applied.value);
 if(balance<0n)return {...empty('INCONSISTENT_NEGATIVE_BALANCE'),status:'PENDING'};
 const publicGrant=Object.fromEntries(['scope','currency','unit','measuredAt','reconciledAt','fetchedAt','periodStart','periodEnd','timeZone'].filter(k=>grant[k]!==undefined).map(k=>[k,grant[k]]));
 return {...publicGrant,value:balance.toString(),derived:true,formula:'periodGrant + grantSpecificAdjustments - appliedIncludedCredit',status:'ACTUAL',reason:null};
}
export class BillingCache {
 constructor({adapter,authorize,clock=()=>Date.now(),ttlMs=300000,minRefreshMs=30000}) {Object.assign(this,{adapter,authorize,clock,ttlMs,minRefreshMs});this.cache=new Map();this.pending=new Map();}
 async read(actor,binding,{manual=false}={}) {
  // Existing server IAM is injected. The cache never trusts APK edition or UI role.
  await this.authorize(actor,'billing.read',binding);
  const key=JSON.stringify([binding.workspace,binding.period]);const prior=this.cache.get(key);const age=prior?this.clock()-prior.at:Infinity;
  if(prior&&age<(manual?this.minRefreshMs:this.ttlMs))return structuredClone(prior.value);
  if(this.pending.has(key))return structuredClone(await this.pending.get(key));
  const call=(async()=>{try{const value=await this.adapter.read(binding);this.cache.set(key,{value:structuredClone(value),at:this.clock()});return value;}catch(e){
   if(e?.status===401||e?.status===403){this.cache.delete(key);return unavailableBilling('PROVIDER_ACCESS_DENIED');}
   if(!prior)return unavailableBilling('PROVIDER_UNAVAILABLE');
   const old=structuredClone(prior.value);for(const f of Object.values(old.fields??{}))if(f.value!==null){f.status='STALE';f.reason='REFRESH_FAILED';}return old;
  }})();
  this.pending.set(key,call);try{return structuredClone(await call);}finally{this.pending.delete(key);}
 }
}
