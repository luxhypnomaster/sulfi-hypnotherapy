import test from 'node:test';import assert from 'node:assert/strict';
import {unavailableBilling,normalizeWorkspace,normalizeForkUsage,deriveRemainingCredit,BillingCache} from '../core/billing26a.mjs';
import {probe} from '../research/billing_probe26a.mjs';
const now='2026-11-25T14:00:00Z',later='2026-12-20T00:00:00Z';
const wid='00000000-0000-4000-8000-000000000001',pid='00000000-0000-4000-8000-000000000002',fid='00000000-0000-4000-8000-000000000003';
const workspace={id:wid,subscription:{planSlug:'HOBBY',status:'ACTIVE',currentPeriodEnd:later}};
test('billing absence is not zero; plan summary cannot fabricate credit, start, timezone or usage',()=>{
 const empty=unavailableBilling();assert.equal(empty.fields.remainingCredit.value,null);
 const r=normalizeWorkspace(workspace,{fetchedAt:now});assert.equal(r.fields.plan.value,'HOBBY');assert.equal(r.fields.periodEnd.value,later);
 for(const name of ['includedCredit','appliedCredit','remainingCredit','periodStart','periodTimeZone','grossCharges','invoices']){assert.equal(r.fields[name].value,null);assert.equal(r.fields[name].status,'UNAVAILABLE');}
 assert.equal(normalizeWorkspace({subscription:null},{fetchedAt:now}).fields.plan.reason,'FIELD_NOT_PROVIDED');assert.equal(normalizeWorkspace({subscription:{planSlug:'HOBBY',status:'unknown'}},{fetchedAt:now}).fields.subscription.value,null);
 assert.equal(r.fields.plan.measuredAt,null);assert.equal(r.fields.plan.fetchedAt,now);
});
test('partial fork usage retains exact decimal strings, no fake freshness, IDs or workspace balance',()=>{
 const raw={coverage:'PARTIAL',currency:'RUB',knownGrossCostCents:'900719925474099312345',lastReconciledAt:now,freshness:'arbitrary-string',period:{id:wid,start:now,end:later},items:[{resourceId:pid,resourceType:'compute',moduleKey:'compute',meterKey:'cu',quantity:'0.000000000000000001',unit:'CU-hour',grossAmountCents:'17'}],limitations:['private identifier '+fid]};
 const r=normalizeForkUsage(raw,{fetchedAt:now});assert.equal(r.knownGross.value,raw.knownGrossCostCents);assert.equal(r.knownGross.status,'PENDING');assert.equal(r.knownGross.measuredAt,null);assert.equal(r.knownGross.reconciledAt,now);assert.equal(r.breakdown[0].quantity,raw.items[0].quantity);assert.equal(r.remainingCredit.value,null);
 for(const id of [wid,pid,fid])assert.ok(!JSON.stringify(r).includes(id));
 assert.equal(normalizeForkUsage({coverage:'UNAVAILABLE'},{fetchedAt:now}).knownGross.value,null);
});
const cell=value=>({value,currency:'RUB',unit:'kopeck',status:'ACTUAL',authoritative:true,scopeBinding:'same',periodBinding:'same-period',measuredAt:now,fetchedAt:now});
test('derived remainder uses authoritative applied credit plus explicit grant adjustments with exact integers',()=>{
 const r=deriveRemainingCredit({grant:{...cell('90071992547409930000'),hiddenProviderId:wid},grantAdjustments:cell('-5'),applied:cell('10')});assert.equal(r.value,'90071992547409929985');assert.equal(r.derived,true);assert.ok(!JSON.stringify(r).includes(wid));
});
test('derived remainder refuses missing, estimate, mixed period/currency/as-of or inconsistent totals',()=>{
 for(const patch of [undefined,{...cell('1'),status:'ESTIMATE'},{...cell('1'),periodBinding:'other'},{...cell('1'),currency:'USD'},{...cell('1'),measuredAt:later},cell('999')]){
 const r=deriveRemainingCredit({grant:cell('10'),grantAdjustments:cell('0'),applied:patch});assert.equal(r.value,null);assert.ok(['UNAVAILABLE','PENDING'].includes(r.status));}
});
test('cache authorization occurs before cached read, manual refresh coalesces and no polling',async()=>{
 let n=0,time=0;const value=normalizeWorkspace(workspace,{fetchedAt:now}),binding={workspace:'opaque',period:'period'};
 const cache=new BillingCache({authorize:async a=>{if(a!=='verified-admin')throw Error('DENIED');},adapter:{read:async()=>{n++;return value;}},clock:()=>time});
 await Promise.all([cache.read('verified-admin',binding),cache.read('verified-admin',binding)]);assert.equal(n,1);
 await assert.rejects(cache.read('client',binding),/DENIED/);await cache.read('verified-admin',binding,{manual:true});assert.equal(n,1);
 time=31000;await Promise.all([cache.read('verified-admin',binding,{manual:true}),cache.read('verified-admin',binding,{manual:true})]);assert.equal(n,2);
});
test('provider failure marks cached values stale; denied credentials never return old financial data',async()=>{
 let time=0,deny=false,down=false;const binding={workspace:'opaque',period:'p'};
 const cache=new BillingCache({clock:()=>time,authorize:async()=>{},adapter:{read:async()=>{if(down){const e=Error('no details');e.status=deny?403:503;throw e;}return normalizeWorkspace(workspace,{fetchedAt:now});}}});
 await cache.read('admin',binding);time=400000;down=true;const stale=await cache.read('admin',binding);assert.equal(stale.fields.plan.status,'STALE');deny=true;const denied=await cache.read('admin',binding);assert.equal(denied.fields.plan.value,null);assert.equal(denied.fields.plan.reason,'PROVIDER_ACCESS_DENIED');
});
test('missing protected token or expected workspace causes zero HTTP calls',async()=>{
 let calls=0;const fetcher=()=>{calls++;};assert.equal((await probe({env:{},fetcher})).status,'BLOCKED_AUTH');assert.equal((await probe({env:{NRZ_TOKEN:'controlled-fixture'},fetcher})).status,'BLOCKED_OWNER');assert.equal(calls,0);
});
test('read-only probe checks observed workspace then user, emits no raw credentials or IDs',async()=>{
 const calls=[];const env={NRZ_TOKEN:'controlled-fixture',P22_ONREZA_WORKSPACE_ID:wid};
 const r=await probe({env,clock:()=>now,fetcher:async(url,options)=>{calls.push({url,options});return Response.json(url.endsWith('/workspace')?workspace:{id:wid,email:'not-a-real-user@example.invalid'});}});
 assert.equal(r.status,'WORKSPACE_READ_VERIFIED');assert.equal(r.userIdentityVerified,true);assert.equal(calls.length,2);assert.ok(calls.every(c=>c.options.method==='GET'&&c.options.redirect==='error'));
 const output=JSON.stringify(r);for(const secret of [wid,env.NRZ_TOKEN,'not-a-real-user'])assert.ok(!output.includes(secret));assert.equal(r.fork.status,'NOT_RUN');
});
test('workspace mismatch, permission denied, network outage are distinct and never create resources',async()=>{
 const env={NRZ_TOKEN:'controlled-fixture',P22_ONREZA_WORKSPACE_ID:wid};
 const mismatch=await probe({env,fetcher:async()=>Response.json({...workspace,id:pid})});assert.equal(mismatch.status,'STOP');assert.equal(mismatch.requests.length,1);
 const denied=await probe({env,fetcher:async()=>new Response('',{status:403})});assert.equal(denied.status,'BLOCKED_AUTH');assert.equal(denied.reason,'PERMISSION_DENIED_NO_ESCALATION');
 const offline=await probe({env,fetcher:async()=>{throw Error('do not echo details');}});assert.equal(offline.status,'UNAVAILABLE');assert.equal(offline.requests.length,1);
});
test('fork probe reads existing exact product/fork only, with no mutation or general usage claim',async()=>{
 const calls=[],env={NRZ_TOKEN:'controlled-fixture',P22_ONREZA_WORKSPACE_ID:wid,P22_ONREZA_PRODUCT_ID:pid,P22_ONREZA_FORK_ID:fid};
 const r=await probe({env,clock:()=>now,fetcher:async(url,opt)=>{calls.push([url,opt.method]);return Response.json(url.endsWith('/workspace')?workspace:url.endsWith('/user')?{id:wid}:url.includes('/product-forks/')?{coverage:'PARTIAL',currency:'RUB',knownGrossCostCents:'1',lastReconciledAt:now,freshness:'unknown',items:[]}:{id:pid});}});
 assert.equal(calls.length,4);assert.ok(calls.every(c=>c[1]==='GET'));assert.equal(r.fork.scope,'fork');assert.equal(r.fork.remainingCredit.value,null);assert.equal(r.fork.knownGross.status,'PENDING');
 for(const id of [wid,pid,fid])assert.ok(!JSON.stringify(r).includes(id));
});
test('credit derivation rejects Number amounts before precision is lost',()=>{
 const r=deriveRemainingCredit({grant:{...cell('20'),value:9007199254740992},grantAdjustments:cell('0'),applied:cell('10')});assert.equal(r.value,null);assert.equal(r.status,'UNAVAILABLE');
});
