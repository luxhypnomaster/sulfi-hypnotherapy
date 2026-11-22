'use strict';
const {digest22,fail,id}=require('./project_store22.cjs');
const {TYPES,keyOf,keys,validatePolicy,calculate,summary,strategies}=require('./rating_calculator22.cjs');
class Ratings22 {
 constructor(s,iam,{resolveTarget,clock=()=>new Date().toISOString(),inject=()=>{}}){this.s=s;this.iam=iam;this.resolveTarget=resolveTarget;this.clock=clock;this.inject=inject;}
 defaultPolicy(){return {schemaVersion:1,policyId:'uncalibrated',configVersion:1,algorithmId:'not-calibrated',algorithmVersion:1,parameterSchemaVersion:1,config:{}};}
 activePolicy(){const head=this.s.get('ratings','head');return head?.policyHash?this.s.read(head.policyHash).policy:this.defaultPolicy();}
 validateTarget(actor,target){keyOf(target);id(target.revisionId);const r=this.resolveTarget(actor,target);if(!r||r.public!==true||r.ratingEpochId!==target.ratingEpochId)fail(403,'RATING_TARGET_DENIED');return r;}
 ingest(actor,q){const a=this.iam.current(actor.uid),f=q.feedback;keys(f,['schemaVersion','feedbackId','sequence','target','rating','execution','occurrences','consent','sourceApp','componentRatings']);
  if(f.schemaVersion!==1||!Number.isInteger(f.sequence)||f.sequence<1||!Number.isInteger(f.rating)||f.rating<1||f.rating>5||!['CLIENT','PRO','MASTER'].includes(f.sourceApp))fail(422,'FEEDBACK_SCHEMA');id(f.feedbackId);
  keys(f.consent,['schemaVersion','share']);if(f.consent.schemaVersion!==1||typeof f.consent.share!=='boolean')fail(422,'CONSENT_REQUIRED');
  keys(f.execution,['executionId','manifestHash','partialExecution']);id(f.execution.executionId);if(!/^[a-f0-9]{64}$/.test(f.execution.manifestHash)||typeof f.execution.partialExecution!=='boolean')fail(422,'EXECUTION_PROVENANCE_REQUIRED');
  const previous=this.s.db.prepare('SELECT payload FROM t22_feedback WHERE owner=? AND id=?').get(actor.uid,f.feedbackId);
  // Withdrawal must remain possible after the content is revoked/withdrawn.
  if(!f.consent.share&&previous){const original=this.s.read(JSON.parse(previous.payload).hash);if(keyOf(original.target)!==keyOf(f.target))fail(409,'FEEDBACK_TARGET_CONFLICT');}
  const root=f.consent.share?this.validateTarget(actor,f.target):{owner:null,exposureTargets:[]};
  if(!Array.isArray(f.occurrences)||f.occurrences.length>500||!Array.isArray(f.componentRatings||[]))fail(422,'EXPOSURE_SCHEMA');
  const reviewerKind=root.owner===actor.uid||root.owner===actor.subject?'AUTHOR_SELF_TEST':a.verifiedPro===true?'VERIFIED_PRO':a.role==='CLIENT'?'CLIENT':'UNVERIFIED';
  const contributions=new Map(),sequence=(this.s.get('ratings','inputSequence')||0)+1;
  function direct(t,rating){if(!Number.isInteger(rating)||rating<1||rating>5)fail(422,'RATING_SCALE');contributions.set(keyOf(t),{target:t,kind:'direct',rating,reviewerKind,rootFeedbackId:f.feedbackId,rootType:f.target.type,owner:actor.uid,hops:0,exposure:f.execution.partialExecution?'PARTIAL':'COMPLETED',occurrences:[],receivedSequence:sequence});}
  direct(f.target,f.rating);
  for(const c of f.consent.share?f.componentRatings||[]:[]){keys(c,['target','rating']);this.validateTarget(actor,c.target);if(!root.exposureTargets?.includes(keyOf(c.target)))fail(403,'COMPONENT_NOT_IN_EXECUTION');direct(c.target,c.rating);}
  const ids=new Set();for(const o of f.consent.share?f.occurrences:[]){keys(o,['occurrenceId','target','status','playedMs','durationMs']);id(o.occurrenceId);if(ids.has(o.occurrenceId))fail(422,'DUPLICATE_OCCURRENCE');ids.add(o.occurrenceId);
   const key=keyOf(o.target);this.validateTarget(actor,o.target);
   if(!root.exposureTargets?.includes(key)||!['NOT_EXPOSED','PARTIAL','COMPLETED','UNKNOWN'].includes(o.status)||!Number.isInteger(o.playedMs)||!Number.isInteger(o.durationMs)||o.playedMs<0||o.durationMs<0||o.playedMs>o.durationMs)fail(422,'INVALID_EXPOSURE');
   if(o.status==='COMPLETED'&&(o.durationMs===0||o.playedMs!==o.durationMs)||o.status==='NOT_EXPOSED'&&o.playedMs!==0||o.status==='PARTIAL'&&(o.playedMs===0||o.playedMs===o.durationMs))fail(422,'INCONSISTENT_EXPOSURE');
   if(!['PARTIAL','COMPLETED'].includes(o.status)||o.playedMs===0)continue;
   const hops=TYPES.indexOf(o.target.type)-TYPES.indexOf(f.target.type);if(hops<1)fail(422,'INVALID_ANCESTOR_PATH');
   const old=contributions.get(key);if(old?.kind==='direct')continue;
   if(old){old.occurrences.push(o);if(o.status==='COMPLETED')old.exposure='COMPLETED';}
   else contributions.set(key,{target:o.target,kind:'context',rating:f.rating,reviewerKind,rootFeedbackId:f.feedbackId,rootType:f.target.type,owner:actor.uid,hops,exposure:o.status,occurrences:[o],receivedSequence:sequence});
  }
  return this.s.receipt(actor.uid,q.requestId,q,()=>{
   const old=this.s.db.prepare('SELECT * FROM t22_feedback WHERE owner=? AND id=?').get(actor.uid,f.feedbackId);
   if(old&&f.sequence!==old.seq+1)fail(409,'FEEDBACK_SEQUENCE_CONFLICT');if(!old&&f.sequence!==1)fail(409,'FEEDBACK_SEQUENCE_CONFLICT');
   const oldKeys=this.s.db.prepare('SELECT target FROM t22_evidence WHERE owner=? AND feedback=?').all(actor.uid,f.feedbackId).map(r=>r.target);
   const hash=this.s.immutable({...f,reviewerKind,owner:actor.uid,receivedAt:this.clock()});
   this.s.db.prepare('INSERT INTO t22_feedback VALUES(?,?,?,?) ON CONFLICT(owner,id) DO UPDATE SET seq=excluded.seq,payload=excluded.payload').run(actor.uid,f.feedbackId,f.sequence,JSON.stringify({hash,shared:f.consent.share}));
   this.s.db.prepare('DELETE FROM t22_evidence WHERE owner=? AND feedback=?').run(actor.uid,f.feedbackId);
   if(f.consent.share)for(const [key,e]of contributions)this.s.db.prepare('INSERT INTO t22_evidence VALUES(?,?,?,?)').run(key,actor.uid,f.feedbackId,JSON.stringify(e));
   for(const k of new Set([...oldKeys,...(f.consent.share?[...contributions.keys()]:[])]))this.s.db.prepare('INSERT OR IGNORE INTO t22_dirty VALUES(?)').run(k);
   this.s.set('ratings','inputSequence',sequence);this.s.audit(actor.uid,f.consent.share?'feedback.optIn':'feedback.revoke',hash);return {feedbackId:f.feedbackId,sequence:f.sequence,accepted:true,shared:f.consent.share,receiptHash:hash};
  });
 }
 evidence(key){return this.s.db.prepare('SELECT payload FROM t22_evidence WHERE target=? ORDER BY owner,feedback').all(key).map(r=>JSON.parse(r.payload));}
 flush({limit=32,policy=this.activePolicy(),requestId='aggregate',actor=null}={}){
  if(!Number.isInteger(limit)||limit<1||limit>1000)fail(422,'INVALID_BATCH_LIMIT');validatePolicy(policy);
  return this.s.tx(()=>{
   const policyCoreHash=digest22(policy);let policyRef=this.s.get('rating-policy-documents',policyCoreHash);
   if(!policyRef){const hash=this.s.immutable({schemaVersion:1,policy,createdBy:actor?.uid||'system',status:'active',scope:'sandbox',approvedBy:null});policyRef={hash};this.s.set('rating-policy-documents',policyCoreHash,policyRef);}
   const policyHash=policyRef.hash;this.s.read(policyHash);
   const dirty=this.s.db.prepare('SELECT target FROM t22_dirty ORDER BY target LIMIT ?').all(limit);
   for(const {target:key}of dirty){const evidence=this.evidence(key);let target=evidence[0]?.target||this.s.get('rating-targets',key);
    if(target){this.s.set('rating-targets',key,target);const computed=summary(target,evidence,policy,this.clock());computed.weighted.policyHash=policyHash;this.s.set('rating-cache',key,computed);}
    this.s.db.prepare('DELETE FROM t22_dirty WHERE target=?').run(key);
   }
   const remaining=this.s.db.prepare('SELECT COUNT(*) AS n FROM t22_dirty').get().n;
   if(remaining)return {state:'RECOMPUTING',remaining,processed:dirty.length};
   const old=this.s.get('ratings','head');
   if(!dirty.length&&old&&digest22(policy)===digest22(this.activePolicy()))return {head:old,state:'NO_CHANGE'};
   const snapshot={schemaVersion:22,scope:'ratings:public',ratingsRevision:(old?.ratingsRevision||0)+1,policyHash,inputSequence:this.s.get('ratings','inputSequence')||0,computedAt:this.clock(),items:this.s.list('rating-cache').map(r=>r.value)};
   const hash=this.s.immutable(snapshot);this.s.read(hash);this.inject('beforeRatingHead');
   const head={schemaVersion:22,scope:'ratings:public',ratingsRevision:snapshot.ratingsRevision,ratingsSnapshotHash:hash,policyHash,computedAt:snapshot.computedAt};
   this.s.set('ratings','head',head);this.s.set('ratings-history',String(head.ratingsRevision),head);this.s.audit(actor?.uid||'system','ratings.commit',hash);
   return {state:'COMMITTED',head,requestId};
  });
 }
 readHead(){const h=this.s.get('ratings','head');return {head:h,dirty:this.s.db.prepare('SELECT COUNT(*) AS n FROM t22_dirty').get().n>0};}
 snapshot(hash){const head=this.s.get('ratings','head');if(head?.ratingsSnapshotHash!==hash)fail(409,'STALE_RATINGS_SNAPSHOT');return this.s.read(hash);}
 draft(actor,q){const a=this.iam.admin(actor);if(a.role!=='OWNER'&&!a.canManageSubordinateRoles)fail(403,'RATING_DRAFT_DENIED');validatePolicy(q.policy);return this.s.receipt(actor.uid,q.requestId,q,()=>{const version=digest22([q.policy.policyId,q.policy.configVersion]),coreHash=digest22(q.policy),old=this.s.get('rating-policy-versions',version);if(old&&old.coreHash!==coreHash)fail(409,'POLICY_VERSION_CONFLICT');this.s.set('rating-policy-versions',version,{coreHash});const hash=this.s.immutable({policy:q.policy,status:'draft',createdAt:this.clock(),createdBy:actor.uid,scope:'sandbox',approvedBy:null});this.s.set('rating-drafts',hash,{hash,owner:actor.uid,validated:false});this.s.audit(actor.uid,'policy.draft',hash);return {hash,status:'draft'};});}
 preview(actor,q){this.iam.admin(actor);const policy=q.policyHash?this.s.read(q.policyHash).policy:validatePolicy(q.policy);validatePolicy(policy);const target=q.target,key=keyOf(target),evidence=this.evidence(key);return {policyHash:digest22(policy),direct:summary(target,evidence,policy,this.clock()),experimental:calculate(target,evidence,policy,{experimental:true}),activeExperimental:calculate(target,evidence,this.activePolicy(),{experimental:true})};}
 validate(actor,q){this.iam.owner(actor);const d=this.s.get('rating-drafts',q.hash);if(!d)fail(404,'POLICY_DRAFT_NOT_FOUND');validatePolicy(this.s.read(q.hash).policy);this.s.set('rating-drafts',q.hash,{...d,validated:true});this.s.audit(actor.uid,'policy.validate',q.hash);return {hash:q.hash,status:'validated'};}
 activate(actor,q){this.iam.owner(actor);return this.s.receipt(actor.uid,q.requestId,q,()=>{
  const h=this.s.get('ratings','head');if((h?.ratingsRevision||0)!==q.expectedRevision)fail(409,'REVISION_CONFLICT');
  const d=this.s.get('rating-drafts',q.hash),historical=this.s.list('ratings-history').some(r=>r.value.policyHash===q.hash);
  if(!d?.validated&&!historical)fail(422,'POLICY_NOT_VALIDATED');const policy=this.s.read(q.hash).policy;validatePolicy(policy);
  // Activation stays atomic; bounded preparations may be retried separately.
  const targets=this.s.list('rating-targets');if(targets.length>1000)fail(503,'POLICY_RECOMPUTE_REQUIRES_BATCH');
  for(const r of targets)this.s.db.prepare('INSERT OR IGNORE INTO t22_dirty VALUES(?)').run(r.key);
  this.inject('policyRecompute');const result=this.flush({limit:1000,policy,requestId:q.requestId,actor});if(!['COMMITTED','NO_CHANGE'].includes(result.state))fail(503,'POLICY_RECOMPUTE_REQUIRES_BATCH');this.s.audit(actor.uid,q.rollback?'policy.rollback':'policy.activate',q.hash);return {...result,approvedProductionWeights:false};
 });}
}
module.exports={Ratings22,keyOf,validatePolicy,calculate,summary,strategies,TYPES};
