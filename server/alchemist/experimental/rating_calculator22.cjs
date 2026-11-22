'use strict';
const {digest22,clone,fail,id}=require('./project_store22.cjs');
const TYPES=['COURSE','PROGRAM','MODULE','TRACK'];
const keyOf=t=>{if(!t||!TYPES.includes(t.type))fail(422,'RATING_TARGET');return [t.type,id(t.contentId),id(t.ratingEpochId)].join(':');};
const round=v=>Math.round(v*1000)/1000;
function keys(value,allowed){if(!value||typeof value!=='object'||Array.isArray(value)||Object.keys(value).some(k=>!allowed.includes(k)))fail(422,'UNKNOWN_RATING_FIELD');}
function validatePolicy(p){
 keys(p,['schemaVersion','policyId','configVersion','algorithmId','algorithmVersion','parameterSchemaVersion','config']);
 if(p.schemaVersion!==1||!Number.isSafeInteger(p.configVersion)||p.configVersion<1||p.parameterSchemaVersion!==1)fail(422,'RATING_POLICY_SCHEMA');id(p.policyId);
 const strategy=strategies[p.algorithmId+'@'+p.algorithmVersion];if(!strategy)fail(422,'UNKNOWN_RATING_STRATEGY');
 if(p.algorithmId==='not-calibrated'){keys(p.config,[]);return clone(p);}
 keys(p.config,['byTarget']);keys(p.config.byTarget,TYPES);
 for(const type of TYPES){const c=p.config.byTarget[type];keys(c,['sourceWeights','edgeWeights','hopWeights','partialPermille','maxIndirectPermille','minimumIndependentN','repeatedRootCap']);
  keys(c.sourceWeights,['CLIENT_DIRECT','PRO_DIRECT','COURSE_CONTEXT','PROGRAM_CONTEXT']);keys(c.edgeWeights,['SELF','COURSE_PROGRAM','COURSE_MODULE','COURSE_TRACK','PROGRAM_MODULE','PROGRAM_TRACK']);keys(c.hopWeights,['0','1','2','3']);
  const values=[...Object.values(c.sourceWeights),...Object.values(c.edgeWeights),...Object.values(c.hopWeights),c.partialPermille,c.maxIndirectPermille,c.minimumIndependentN,c.repeatedRootCap];
  if(values.some(n=>!Number.isSafeInteger(n)||n<0||n>1000000)||c.partialPermille>1000||c.maxIndirectPermille>1000||c.minimumIndependentN<1||c.repeatedRootCap<1||!(c.sourceWeights.CLIENT_DIRECT>0)||!(c.sourceWeights.PRO_DIRECT>c.sourceWeights.CLIENT_DIRECT))fail(422,'INVALID_RATING_PARAMETERS');
 }
 return clone(p);
}
function weightedRows(target,evidence,policy){const c=policy.config.byTarget[target.type],seen=new Set(),directOwners=new Set(),contextCounts=new Map(),rows=[];
 for(const e of [...evidence].sort((a,b)=>(a.kind==='direct'?0:1)-(b.kind==='direct'?0:1)||b.receivedSequence-a.receivedSequence)){if(!['CLIENT','VERIFIED_PRO'].includes(e.reviewerKind))continue;const root=e.owner+':'+e.rootFeedbackId;if(seen.has(root))continue;seen.add(root);
  if(e.kind==='direct'){if(directOwners.has(e.owner))continue;directOwners.add(e.owner);}else{const n=contextCounts.get(e.owner)||0;if(n>=c.repeatedRootCap)continue;contextCounts.set(e.owner,n+1);}
  const source=e.kind==='direct'?(e.reviewerKind==='VERIFIED_PRO'?'PRO_DIRECT':'CLIENT_DIRECT'):e.rootType+'_CONTEXT';
  const edge=e.kind==='direct'?'SELF':e.rootType+'_'+target.type;
  let weight=(c.sourceWeights[source]||0)*(c.edgeWeights[edge]||0)*(c.hopWeights[String(e.hops)]||0);
  if(e.exposure==='PARTIAL')weight*=c.partialPermille/1000;
  if(weight>0)rows.push({score:e.rating,weight,kind:e.kind});
 }
 const direct=rows.filter(r=>r.kind==='direct').reduce((n,r)=>n+r.weight,0),indirect=rows.filter(r=>r.kind!=='direct').reduce((n,r)=>n+r.weight,0);
 if(direct&&indirect&&c.maxIndirectPermille<1000){const max=direct*c.maxIndirectPermille/(1000-c.maxIndirectPermille);if(indirect>max)for(const r of rows)if(r.kind!=='direct')r.weight*=max/indirect;}
 return new Set(evidence.filter(e=>['CLIENT','VERIFIED_PRO'].includes(e.reviewerKind)).map(e=>e.owner)).size<c.minimumIndependentN?[]:rows;
}
const strategies=Object.freeze({
 'not-calibrated@1':()=>null,
 'evidence-mean-experimental@1':(t,e,p)=>{const rows=weightedRows(t,e,p),total=rows.reduce((n,r)=>n+r.weight,0);return total?round(rows.reduce((n,r)=>n+r.weight*r.score,0)/total):null;},
 'evidence-mean-experimental@2':(t,e,p)=>{const rows=weightedRows(t,e,p).sort((a,b)=>a.score-b.score),total=rows.reduce((n,r)=>n+r.weight,0);let n=0;for(const r of rows){n+=r.weight;if(n>=total/2)return r.score;}return null;},
});
function calculate(target,evidence,policy,{experimental=false}={}){validatePolicy(policy);const value=experimental?strategies[policy.algorithmId+'@'+policy.algorithmVersion](target,clone(evidence),clone(policy)):null;
 return {value,status:experimental?'EXPERIMENTAL':'NOT_CALIBRATED',algorithmId:policy.algorithmId,algorithmVersion:policy.algorithmVersion,configVersion:policy.configVersion,policyHash:digest22(policy)};
}
function cohort(evidence,kind,at){const perOwner=new Map();for(const e of evidence.filter(e=>e.kind==='direct'&&e.reviewerKind===kind)){const old=perOwner.get(e.owner);if(!old||e.receivedSequence>old.receivedSequence)perOwner.set(e.owner,e);}
 const rows=[...perOwner.values()],distribution=[0,0,0,0,0];for(const e of rows)distribution[e.rating-1]++;
 return {mean:rows.length?round(rows.reduce((n,e)=>n+e.rating,0)/rows.length):null,n:rows.length,distribution,updatedAt:at,evidenceLevel:rows.length===0?'NO_DATA':rows.length===1?'PRELIMINARY':'OBSERVED'};
}
function summary(target,evidence,policy,at){const publicEvidence=evidence.filter(e=>['CLIENT','VERIFIED_PRO'].includes(e.reviewerKind)),consumerDirect=cohort(publicEvidence,'CLIENT',at),professionalDirect=cohort(publicEvidence,'VERIFIED_PRO',at);
 const context=publicEvidence.filter(e=>e.kind==='context'),roots=new Set(context.map(e=>e.owner+':'+e.rootFeedbackId));
 return {target,consumerDirect,professionalDirect,weighted:{...calculate(target,publicEvidence,policy),computedAt:at,evidenceLevel:'NOT_CALIBRATED',sourceBreakdown:{consumerDirectN:consumerDirect.n,professionalDirectN:professionalDirect.n,contextRootN:roots.size}},
  evidenceCounts:{directConsumerN:consumerDirect.n,directProN:professionalDirect.n,contextCourseN:new Set(context.filter(e=>e.rootType==='COURSE').map(e=>e.owner+':'+e.rootFeedbackId)).size,contextProgramN:new Set(context.filter(e=>e.rootType==='PROGRAM').map(e=>e.owner+':'+e.rootFeedbackId)).size,independentN:new Set(publicEvidence.map(e=>e.owner)).size},
  context:{rootN:roots.size,partialRootN:new Set(context.filter(e=>e.exposure==='PARTIAL').map(e=>e.owner+':'+e.rootFeedbackId)).size,occurrenceN:context.reduce((n,e)=>n+e.occurrences.length,0)},computedAt:at};
}
module.exports={TYPES,keyOf,keys,validatePolicy,calculate,summary,strategies};
