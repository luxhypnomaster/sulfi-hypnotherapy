import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const require=createRequire(import.meta.url);
const {SqliteSnapshotStore}=require('../experimental/sqlite_snapshot_store.cjs');
const {createProjectRuntime22}=require('../experimental/project_runtime22.cjs');
const {digest22}=require('../experimental/project_store22.cjs');
function fixture(){const root=mkdtempSync(join(tmpdir(),'runtime22-')),base=new SqliteSnapshotStore(join(root,'sandbox.sqlite'));const principal=token=>['owner','client','other'].includes(token)?{verified:true,issuer:'synthetic',sub:token,expiresAt:Date.now()+100000,binding:token+'-binding'}:null;
 const r=createProjectRuntime22({baseStore:base,resolveCredential:principal,legacy:{request:async q=>({ok:true,status:200,result:{legacy:q.operation}})}}),owner=r.iam.resolve(principal('owner'));r.iam.bootstrapOwner(owner.uid);
 const call=(operation,parameters={},credential='owner')=>r.request({version:1,operation,parameters,credential});
 base.putRecord({catalogItemId:'program-card',contentId:'program',revisionId:'r1',type:'template',sha256:'a'.repeat(64),byteLength:0,title:'Synthetic program',state:'published',public:true,current:true,dependencies:[],owner:owner.uid,ratingEpochId:'initial'});
 return {root,base,r,call,owner,close(){base.close();rmSync(root,{recursive:true,force:true});}};
}
test('22 existing catalog/head plus durable course publish and batch jobs commit one exact receipt, no media copy',async()=>{const f=fixture();try{
 const changes=[{contentId:'course',type:'course',action:'publish',patch:{title:'Synthetic course'},programRefs:[{contentId:'program',revisionId:'r1',sha256:'a'.repeat(64)}]}];
 const submitted=await f.call('project.catalogBatch',{requestId:'publish-course',changes});assert.equal(submitted.ok,true);
 const op=submitted.result.operationId;const done=await f.call('project.runOperation',{operationId:op});assert.equal(done.result.state,'SUCCEEDED');
 for(let i=0;i<5;i++)assert.equal((await f.call('project.catalogBatch',{requestId:'publish-course',changes})).result.operationId,op);
 assert.equal(f.base.head('client:public').catalogRevision,1);assert.equal(f.base.records().length,2);assert.equal(f.base.records().find(r=>r.contentId==='course').programs[0].contentId,'program');
 const before=f.base.head('client:public');const status=await f.call('project.runOperation',{operationId:op});assert.equal(status.result.receipt.preparedHash,done.result.receipt.preparedHash);assert.deepEqual(f.base.head('client:public'),before);
 assert.equal((await f.call('project.catalogBatch',{requestId:'bad',changes},'client')).status,403);
 assert.equal((await f.call('catalog.list')).result.legacy,'catalog.list');
}finally{f.close();}});
test('22 seven real admin summaries/unknown quotas, role denied, scoped identities and normalized categories',async()=>{const f=fixture();try{
 assert.equal((await f.call('project.overview',{},'client')).status,403);const o=(await f.call('project.overview')).result;assert.equal(o.sections.length,7);assert.equal(o.sections.find(s=>s.id==='catalog').metrics.published.value,1);assert.equal(o.sections.find(s=>s.id==='server').state,'unknown');assert.equal(o.sections.find(s=>s.id==='server').metrics.storageQuota.value,null);assert.equal(o.sections.find(s=>s.id==='backups').metrics.restoreVerified.value,null);
 assert.equal((await f.call('project.capabilities',{nonce:'n',scope:'client:public'},'client')).result.admin,false);assert.equal((await f.call('project.capabilities',{nonce:'n',scope:'master:public'},'client')).status,403);
 await f.call('project.categoryEdit',{requestId:'a',id:'a',name:'Сон'});assert.equal((await f.call('project.categoryEdit',{requestId:'b',id:'b',name:' сон '})).status,409);
 const roles=f.r.store.list('roles');assert.equal(roles.some(r=>r.value.role==='OWNER'&&r.key!==f.owner.uid),false);
 const q=await f.call('project.backup',{requestId:'x'});assert.equal(q.status,503);assert.equal(f.r.store.list('backup-history').length,0);
}finally{f.close();}});
test('22 ratings-only revision never touches catalog HEAD/media and public summary contains no raw identity',async()=>{const f=fixture();try{
 const root={type:'PROGRAM',contentId:'program',revisionId:'r1',ratingEpochId:'initial'},feedback={schemaVersion:1,feedbackId:'f1',sequence:1,target:root,rating:5,execution:{executionId:'run1',manifestHash:'a'.repeat(64),partialExecution:false},occurrences:[],consent:{schemaVersion:1,share:true},sourceApp:'CLIENT'};
 assert.equal((await f.call('feedback.ingest',{requestId:'feedback',feedback},'client')).ok,true);
 const before=digest22(f.base.records());const job=(await f.call('ratings.recompute',{requestId:'compute'})).result;await f.call('project.runOperation',{operationId:job.operationId});
 const head=(await f.call('ratings.head',{},'client')).result.head,view=(await f.call('ratings.snapshot',{hash:head.ratingsSnapshotHash},'client')).result;
 assert.equal(view.items[0].consumerDirect.mean,5);assert.equal(view.items[0].professionalDirect.mean,null);assert.equal(view.items[0].weighted.value,null);assert.equal(JSON.stringify(view).includes('usr_'),false);assert.equal(digest22(f.base.records()),before);assert.equal(f.base.head('client:public'),null);
 assert.equal((await f.call('project.users',{},'client')).status,403);
}finally{f.close();}});
test('22 private metadata does not become public and listing never includes diary/private payloads',async()=>{const f=fixture();try{
 f.base.putRecord({contentId:'private',revisionId:'r1',type:'track',sha256:'b'.repeat(64),byteLength:0,title:'Private',state:'published',public:false,current:true,dependencies:[],owner:f.owner.uid,ratingEpochId:'initial',secretPayload:'NEVER_RETURN'});
 f.base.putRecord({contentId:'diary',revisionId:'r1',type:'diaryEntry',title:'Private diary',state:'draft',public:false,owner:'other',privateBody:'NEVER_RETURN'});
 const change={requestId:'quiet',changes:[{contentId:'private',action:'quietEdit',expectedRevisionId:'r1',patch:{title:'Changed'}}]},j=(await f.call('project.catalogBatch',change)).result;
 assert.equal((await f.call('project.runOperation',{operationId:j.operationId})).result.state,'SUCCEEDED');assert.equal(f.base.records().find(r=>r.contentId==='private').public,false);
 assert.equal(f.base.snapshot('client:public',f.base.head('client:public').snapshotId).items.some(r=>r.contentId==='private'),false);
 assert.equal(JSON.stringify(await f.call('project.catalogList')).includes('NEVER_RETURN'),false);
}finally{f.close();}});
test('22 exact target type/revision and legacy author ownership persist in server jobs',async()=>{const f=fixture();try{
 const root={type:'PROGRAM',contentId:'program',revisionId:'r1',ratingEpochId:'initial'},initial=f.base.records().find(r=>r.contentId==='program');
 assert.equal(f.r.catalog.target(f.owner,{...root,type:'TRACK'}),null);f.r.store.set('catalog-revisions','program:r1',initial);f.base.putRecord({...initial,revisionId:'r2'});assert.equal(f.r.catalog.target(f.owner,root).revisionId,'r1');assert.equal(f.r.catalog.target(f.owner,{...root,revisionId:'forged'}),null);
 const identity=f.r.iam.resolve({verified:true,issuer:'synthetic',sub:'other',expiresAt:Date.now()+100000});f.r.iam.change(f.owner,{requestId:'grant',uid:identity.uid,role:'AUTHOR'});f.base.putRecord({...initial,contentId:'authored',owner:'other'});
 const job=(await f.call('project.catalogBatch',{requestId:'edit',changes:[{contentId:'authored',action:'quietEdit',expectedRevisionId:'r1',patch:{title:'Original author'}}]},'other')).result;
 assert.equal((await f.r.jobs.run(job.operationId,f.r.handlers)).state,'SUCCEEDED');assert.equal((await f.call('project.categoryEdit',{requestId:'bad',id:'unsafe',name:'No'},'other')).status,403);
}finally{f.close();}});
