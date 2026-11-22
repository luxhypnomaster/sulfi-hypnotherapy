'use strict';
const {digest22,fail,id}=require('./project_store22.cjs');
class ServerJobs22 {
 constructor(store,{clock=()=>Date.now(),leaseMs=30000,maxAttempts=3,retryMs=1000,inject=()=>{}}={}){
  this.s=store;this.clock=clock;this.leaseMs=leaseMs;this.maxAttempts=maxAttempts;this.retryMs=retryMs;this.inject=inject;
  for(const n of [leaseMs,maxAttempts,retryMs])if(!Number.isSafeInteger(n)||n<1)fail(422,'INVALID_JOB_POLICY');
 }
 enqueue(owner,q){id(owner);id(q.requestId);id(q.kind);return this.s.tx(()=>{
  const key=digest22([owner,q.requestId]),fingerprint=digest22(q),old=this.s.get('jobs',key);
  if(old){if(old.fingerprint!==fingerprint)fail(409,'IDEMPOTENCY_CONFLICT');return old;}
  const job={operationId:key,owner,requestId:q.requestId,fingerprint,kind:q.kind,input:q.input||{},state:'QUEUED',attempts:0,nextAt:this.clock(),lease:null,receipt:null};
  this.s.set('jobs',key,job);return job;
 });}
 status(owner,operationId){const j=this.s.get('jobs',operationId);if(!j||j.owner!==owner)fail(403,'OPERATION_SCOPE_DENIED');return j;}
 claim(operationId){return this.s.tx(()=>{const j=this.s.get('jobs',operationId),now=this.clock();if(!j||j.state==='SUCCEEDED'||j.state==='QUARANTINED'||j.nextAt>now||j.lease&&j.lease.until>now)return null;
  if(j.attempts>=this.maxAttempts){j.state='QUARANTINED';j.lease=null;this.s.set('jobs',operationId,j);return null;}
  j.attempts++;j.state='RUNNING';j.lease={token:digest22([operationId,j.attempts,now]),until:now+this.leaseMs};this.s.set('jobs',operationId,j);return j;
 });}
 async run(operationId,handlers){const j=this.claim(operationId);if(!j)return this.s.get('jobs',operationId);
  try{
   const handler=handlers[j.kind];if(typeof handler!=='function'&&typeof handler?.prepare!=='function')fail(422,'UNSUPPORTED_OPERATION_KIND');
   // Long preparation is outside SQLite transaction. Handler returns data, not
   // untracked external side effects. Exact receipt+prepared head commit below.
   const prepared=await (typeof handler==='function'?handler(j.input,j):handler.prepare(j.input,j));
   const result=this.s.tx(()=>{const current=this.s.get('jobs',operationId);
    if(current.state==='SUCCEEDED')return current;
    if(current.lease?.token!==j.lease.token||current.lease.until<this.clock())fail(409,'LEASE_LOST');
    const committed=typeof handler.commit==='function'?handler.commit(prepared,j):prepared;
    const hash=this.s.immutable(committed);this.inject('beforeCommit',j);
    current.receipt={operationId,requestId:j.requestId,preparedHash:hash,outcome:'COMMITTED'};current.state='SUCCEEDED';current.lease=null;
    this.s.set('job-results',operationId,{hash});this.s.set('jobs',operationId,current);this.s.audit(j.owner,'operation.commit',operationId);return current;
   });this.inject('afterCommit',j);return result;
  }catch(e){return this.s.tx(()=>{const c=this.s.get('jobs',operationId);if(c.state==='SUCCEEDED')return c; // reconcile lost response, never replay committed work.
   if(c.lease?.token!==j.lease.token)return c;
   const code=['LEASE_LOST','UNSUPPORTED_OPERATION_KIND','REVISION_CONFLICT'].includes(e.code)?e.code:'OPERATION_UNAVAILABLE';
   c.state=c.attempts>=this.maxAttempts?'QUARANTINED':'WAITING';c.lease=null;c.nextAt=this.clock()+this.retryMs*2**(c.attempts-1);c.errorCode=code;
   this.s.set('jobs',operationId,c);this.s.set('incidents',digest22([operationId,code]),{operationId,code,attempts:c.attempts,at:this.clock()});return c;
  });}
 }
}
module.exports={ServerJobs22};
