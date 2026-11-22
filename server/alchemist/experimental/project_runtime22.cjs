'use strict';
const {ProjectStore22,digest22,fail}=require('./project_store22.cjs');
const {ServerJobs22}=require('./server_jobs22.cjs');
const {IdentityRoles22}=require('./identity_roles22.cjs');
const {Ratings22}=require('./ratings22.cjs');
const {Catalog22}=require('./catalog22.cjs');
const SECTION_IDS=['publications','catalog','statistics','operations','server','users','backups'];
function createProjectRuntime22({baseStore,resolveCredential,legacy,clock=()=>new Date().toISOString(),backupAdapter=null}){
 const store=new ProjectStore22(baseStore.db),iam=new IdentityRoles22(store),jobs=new ServerJobs22(store),catalog=new Catalog22(baseStore,store,iam,{clock});
 const ratings=new Ratings22(store,iam,{resolveTarget:(a,t)=>catalog.target(a,t),clock});
 function overview(actor){iam.admin(actor);const all=baseStore.records(),at=clock(),metric=(value,source='sqlite-sandbox',state='verified')=>({value,source,updatedAt:at,state});
  const jobRows=store.list('jobs').map(r=>r.value),errors=jobRows.filter(j=>j.state==='QUARANTINED').length;
  const sections=[{id:'publications',metrics:{published:metric(all.filter(r=>r.type==='diaryEntry'&&r.state==='published').length),drafts:metric(all.filter(r=>r.type==='diaryEntry'&&r.state!=='published').length)}},
   {id:'catalog',metrics:{published:metric(all.filter(r=>r.type!=='diaryEntry'&&r.state==='published').length),pending:metric(jobRows.filter(r=>r.kind==='catalog'&&r.state!=='SUCCEEDED').length),errors:metric(jobRows.filter(r=>r.kind==='catalog'&&r.state==='QUARANTINED').length,'server-jobs',jobRows.some(r=>r.kind==='catalog'&&r.state==='QUARANTINED')?'problem':'verified')}},
   {id:'statistics',metrics:{installs:metric(null,'no-install-telemetry','unknown'),downloads:metric(null,'no-download-telemetry','unknown'),consentedFeedback:metric(store.db.prepare('SELECT COUNT(*) AS n FROM t22_feedback WHERE json_extract(payload,\'$.shared\')=1').get().n),ratingTargets:metric(store.list('rating-cache').length)}},
   {id:'operations',metrics:{queued:metric(jobRows.filter(j=>['QUEUED','WAITING'].includes(j.state)).length),errors:metric(errors,'server-jobs',errors?'problem':'verified'),incidents:metric(store.list('incidents').length)}},
   {id:'server',metrics:{metadata:metric('available'),storageQuota:metric(null,'provider-unavailable','unknown'),databaseQuota:metric(null,'provider-unavailable','unknown'),outbound:metric(null,'provider-unavailable','unknown'),apiQuota:metric(null,'provider-unavailable','unknown')}},
   {id:'users',metrics:{verifiedIdentities:metric(store.list('identities').length),roleAssignments:metric(store.list('roles').length)}},
   {id:'backups',metrics:{lastUploaded:metric(store.get('backups','lastUploaded')?.at||null,'backup-receipt',store.get('backups','lastUploaded')?'verified':'unknown'),restoreVerified:metric(store.get('backups','lastVerified')?.at||null,'restore-receipt',store.get('backups','lastVerified')?'verified':'unknown')}}];
  for(const section of sections){const states=Object.values(section.metrics).map(m=>m.state);section.state=states.includes('problem')?'problem':states.some(s=>s!=='verified')?'unknown':'healthy';}
  const value={schemaVersion:22,scope:'admin:'+actor.uid,source:'sqlite-sandbox',updatedAt:at,sections};return {...value,revision:digest22(sections.map(s=>({id:s.id,state:s.state,metrics:Object.fromEntries(Object.entries(s.metrics).map(([k,v])=>[k,{value:v.value,state:v.state,source:v.source}]))})))};
 }
 const handlers={
  catalog:{prepare:(input,j)=>catalog.prepare({uid:j.owner,...iam.current(j.owner)},input),commit:(prepared,j)=>catalog.commit({uid:j.owner,...iam.current(j.owner)},j.input,prepared)},
  ratingPolicy:{prepare:q=>q,commit:(q,j)=>ratings.activate({uid:j.owner},q)},
  ratings:{prepare:q=>q,commit:q=>ratings.flush(q)},
  backup:{prepare:async(q,j)=>{iam.owner({uid:j.owner});if(!backupAdapter)fail(503,'BACKUP_ADAPTER_UNAVAILABLE');return backupAdapter(q);},commit:(receipt,j)=>{
   iam.owner({uid:j.owner});if(receipt.uploaded!==true||!/^[a-f0-9]{64}$/.test(receipt.sha256||''))fail(422,'BACKUP_RECEIPT_INVALID');
   const value={...receipt,at:clock(),operationId:j.operationId};store.set('backup-history',j.operationId,value);store.set('backups','lastUploaded',value);if(receipt.restoreVerified===true)store.set('backups','lastVerified',value);return value;
  }},
 };
 async function request(envelope){const op=envelope?.operation;
  if(!op?.startsWith('project.')&&!op?.startsWith('ratings.')&&!op?.startsWith('feedback.')&&!op?.startsWith('policy.'))return legacy.request(envelope);
  try{
   if(envelope.version!==1||!envelope.parameters||typeof envelope.parameters!=='object'||Array.isArray(envelope.parameters))fail(422,'INVALID_ENVELOPE');
   const v=await resolveCredential(envelope.credential),actor=iam.resolve(v),q=envelope.parameters;let result;
   if(q.scope!==undefined&&(!['client:public','master:public'].includes(q.scope)||q.scope==='master:public'&&actor.role==='CLIENT'))fail(403,'SCOPE_DENIED');
   if(op==='project.capabilities')result={contract:'alchemic.project22/1',schemaVersion:22,canonical:'sorted-json-milli-v1',nonce:q.nonce,principalBinding:v.binding,expiresAt:v.expiresAt,scope:q.scope,admin:['OWNER','ADMIN'].includes(actor.role),adminScope:'admin:'+actor.uid,canPublishPolicy:actor.role==='OWNER',canManageRoles:actor.role==='OWNER'||actor.role==='ADMIN'&&actor.canManageSubordinateRoles===true,backups:backupAdapter!==null,ratings:true,courses:true,serverJobs:true};
   else if(op==='project.overview')result=overview(actor);
   else if(op==='ratings.head')result=ratings.readHead();
   else if(op==='ratings.snapshot')result=ratings.snapshot(q.hash);
   else if(op==='feedback.ingest')result=ratings.ingest(actor,q);
   else if(op==='project.roleChange')result=iam.change(actor,q);
   else if(op==='project.roleDefinitions')result=iam.definitions(actor,q);
   else if(op==='project.users'){iam.admin(actor);result={users:store.list('roles').map(r=>({uid:r.key,...r.value}))};}
   else if(op==='project.categories'){iam.admin(actor);result={categories:store.list('categories').map(r=>r.value)};}
   else if(op==='project.categoryEdit')result=catalog.categories(actor,q);
   else if(op==='project.catalogList'){iam.admin(actor);result={records:baseStore.records().filter(r=>r.type!=='diaryEntry'&&(r.public||r.owner===actor.uid||r.owner===actor.subject||actor.role==='OWNER')).map(r=>Object.fromEntries(['catalogItemId','contentId','revisionId','type','title','description','sha256','byteLength','dependencies','state','public','current','ratingEpochId'].filter(k=>r[k]!==undefined).map(k=>[k,r[k]])))};}
   else if(op==='project.course'){
    const r=baseStore.records().find(r=>r.contentId===q.contentId&&r.type==='course'&&r.public&&r.state==='published');if(!r)fail(403,'COURSE_NOT_AVAILABLE');
    result={definition:{contentId:r.contentId,revisionId:r.revisionId,ratingEpochId:r.ratingEpochId,title:r.title,programs:r.programs},programs:r.programs.map(ref=>{const p=baseStore.records().find(p=>p.contentId===ref.contentId&&p.revisionId===ref.revisionId);return {contentId:ref.contentId,ratingEpochId:p?.ratingEpochId||null,entitled:p?.state==='published'&&p?.public===true,card:p?{catalogItemId:p.catalogItemId,immutableRevisionId:p.revisionId,logicalContentId:p.contentId,type:p.type,card:{title:p.title,shortAnnotation:p.title}}:null};})};
   }
   else if(op==='project.catalogBatch'){catalog.author(actor);result=jobs.enqueue(actor.uid,{requestId:q.requestId,kind:'catalog',input:q});}
   else if(op==='project.operations'){iam.admin(actor);result={jobs:store.list('jobs').map(r=>r.value).filter(j=>actor.role==='OWNER'||j.owner===actor.uid).map(({input,...j})=>j)};}
   else if(op==='project.incidents'){iam.admin(actor);result={incidents:store.list('incidents').map(r=>r.value),audit:store.db.prepare('SELECT actor,action,object,at FROM t22_audit ORDER BY seq DESC LIMIT 100').all()};}
   else if(op==='project.runOperation'){iam.admin(actor);const job=jobs.status(actor.uid,q.operationId);result=await jobs.run(job.operationId,handlers);}
   else if(op==='project.operationStatus')result=jobs.status(actor.uid,q.operationId);
   else if(op==='project.operationResult'){const j=jobs.status(actor.uid,q.operationId);if(j.state!=='SUCCEEDED')fail(409,'OPERATION_NOT_COMMITTED');result=store.read(j.receipt.preparedHash);}
   else if(op==='project.backups'){iam.admin(actor);result={backups:store.list('backup-history').map(r=>r.value),available:backupAdapter!==null};}
   else if(op==='project.backup'){iam.owner(actor);if(!backupAdapter)fail(503,'BACKUP_ADAPTER_UNAVAILABLE');result=jobs.enqueue(actor.uid,{requestId:q.requestId,kind:'backup',input:q});}
   else if(op==='policy.history'){iam.admin(actor);result={active:ratings.readHead().head,history:store.list('ratings-history').map(r=>r.value),drafts:store.list('rating-drafts').map(r=>({...store.read(r.key),hash:r.key,validated:r.value.validated}))};}
   else if(op==='policy.draft')result=ratings.draft(actor,q);
   else if(op==='policy.preview')result=ratings.preview(actor,q);
   else if(op==='policy.validate')result=ratings.validate(actor,q);
   else if(op==='policy.activate'||op==='policy.rollback'){iam.owner(actor);result=jobs.enqueue(actor.uid,{requestId:q.requestId,kind:'ratingPolicy',input:{...q,rollback:op==='policy.rollback'}});}
   else if(op==='ratings.recompute'){iam.admin(actor);result=jobs.enqueue(actor.uid,{requestId:q.requestId,kind:'ratings',input:{limit:q.limit||32,requestId:q.requestId}});}
   else fail(404,'UNKNOWN_OPERATION');
   return {ok:true,status:200,result};
  }catch(e){const allowed=/^[A-Z][A-Z0-9_]{1,80}$/.test(e.code||'')?e.code:'PROJECT_UNAVAILABLE';return {ok:false,status:e.status||503,error:{code:allowed}};}
 }
 return {request,store,iam,jobs,ratings,catalog,overview,handlers,SECTION_IDS};
}
module.exports={createProjectRuntime22,SECTION_IDS};
