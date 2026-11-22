import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdtempSync,rmSync,readFileSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import crypto from 'node:crypto';
const require=createRequire(import.meta.url);
const {SqliteSnapshotStore}=require('../experimental/sqlite_snapshot_store.cjs');
const {ProjectStore22,digest22}=require('../experimental/project_store22.cjs');
const {ServerJobs22}=require('../experimental/server_jobs22.cjs');
const {IdentityRoles22}=require('../experimental/identity_roles22.cjs');
const {Ratings22,keyOf,calculate,summary}=require('../experimental/ratings22.cjs');
const backup=require('../experimental/backup22.cjs');
function fixture(){const root=mkdtempSync(join(tmpdir(),'sulfi22-')),sql=new SqliteSnapshotStore(join(root,'state.sqlite')),s=new ProjectStore22(sql.db),iam=new IdentityRoles22(s);
 const actor=(sub)=>iam.resolve({verified:true,issuer:'synthetic-google',sub,expiresAt:Date.now()+100000});
 const owner=actor('owner');iam.bootstrapOwner(owner.uid);const client=actor('client');
 return {root,sql,s,iam,owner,client,actor,close(){sql.close();rmSync(root,{recursive:true,force:true});}};}
const target=(type,contentId,revisionId='r1')=>({type,contentId,revisionId,ratingEpochId:'epoch1'});
const program=target('PROGRAM','program'),module=target('MODULE','module'),track=target('TRACK','track'),course=target('COURSE','course');
function ratingFixture(f){const records=new Map([course,program,module,track].map(t=>[t.contentId,{public:true,owner:f.owner.uid,ratingEpochId:'epoch1',exposureTargets:[program,module,track].filter(x=>x.contentId!==t.contentId).map(keyOf)}]));return {records,r:new Ratings22(f.s,f.iam,{resolveTarget:(_,t)=>records.get(t.contentId)})};}
function feedback(id='review',root=program,rating=5){return {schemaVersion:1,feedbackId:id,sequence:1,target:root,rating,execution:{executionId:'run-'+id,manifestHash:'a'.repeat(64),partialExecution:true},occurrences:[],componentRatings:[],consent:{schemaVersion:1,share:true},sourceApp:'CLIENT'};}
function policy(version=1,algorithmVersion=1){const c={sourceWeights:{CLIENT_DIRECT:1000,PRO_DIRECT:2000,COURSE_CONTEXT:500,PROGRAM_CONTEXT:500},edgeWeights:{SELF:1000,COURSE_PROGRAM:1000,COURSE_MODULE:1000,COURSE_TRACK:1000,PROGRAM_MODULE:1000,PROGRAM_TRACK:1000},hopWeights:{0:1000,1:1000,2:500,3:250},partialPermille:250,maxIndirectPermille:500,minimumIndependentN:1,repeatedRootCap:1};return {schemaVersion:1,policyId:'synthetic-only',configVersion:version,algorithmId:'evidence-mean-experimental',algorithmVersion,parameterSchemaVersion:1,config:{byTarget:Object.fromEntries(['COURSE','PROGRAM','MODULE','TRACK'].map(k=>[k,structuredClone(c)]))}};}
test('22 server jobs actual durable idempotency, cold readback, lease fencing, incident redaction/quarantine',async()=>{const f=fixture();try{
 let now=0,commits=0;const q=new ServerJobs22(f.s,{clock:()=>now,leaseMs:10,retryMs:1,maxAttempts:2,inject:p=>{if(p==='afterCommit')throw Error('TOKEN_MUST_NOT_LEAK')}});
 const input={requestId:'one',kind:'publish',input:{revision:1}},job=q.enqueue(f.owner.uid,input);
 for(let i=0;i<10;i++)assert.equal(q.enqueue(f.owner.uid,input).operationId,job.operationId);
 assert.throws(()=>q.enqueue(f.owner.uid,{...input,input:{revision:2}}),/IDEMPOTENCY_CONFLICT/);
 const done=await q.run(job.operationId,{publish:async()=>({revision:++commits})});assert.equal(done.state,'SUCCEEDED');assert.equal(commits,1);
 assert.equal((await q.run(job.operationId,{publish:()=>{throw Error('no replay')}})).receipt.preparedHash,done.receipt.preparedHash);
 const cold=new SqliteSnapshotStore(join(f.root,'state.sqlite'));assert.equal(new ProjectStore22(cold.db).get('jobs',job.operationId).receipt.outcome,'COMMITTED');cold.close();
 assert.throws(()=>q.status(f.client.uid,job.operationId),/SCOPE_DENIED/);
 const failed=q.enqueue(f.owner.uid,{requestId:'fail',kind:'bad'});await q.run(failed.operationId,{bad:()=>{throw Error('PRIVATE_DIARY_TOKEN')}});now+=3;await q.run(failed.operationId,{bad:()=>{throw Error('PRIVATE_DIARY_TOKEN')}});
 assert.equal(q.status(f.owner.uid,failed.operationId).state,'QUARANTINED');assert.equal(f.s.list('incidents').length,1);assert.equal(JSON.stringify(f.s.list('incidents')).includes('PRIVATE'),false);
 const lease=q.enqueue(f.owner.uid,{requestId:'lease',kind:'x'});let release;const gate=new Promise(r=>release=r);const old=q.run(lease.operationId,{x:async()=>{await gate;return{old:true}}});now+=20;await q.run(lease.operationId,{x:async()=>({new:true})});release();await old;assert.equal(f.s.read(q.status(f.owner.uid,lease.operationId).receipt.preparedHash).new,true);
}finally{f.close();}});
test('22 portable encrypted complete backup independent restore, tamper/keys/private destination gates',async()=>{const f=fixture();try{
 const key=crypto.randomBytes(32),groups=Object.fromEntries(backup.groups.map(k=>[k,{synthetic:true,ids:[k+'-one']}]));
 const b=backup.pack(groups,[{path:'media/synthetic.bin',bytes:Buffer.from('synthetic-safe')},{path:'database/export.json',bytes:Buffer.from(JSON.stringify(groups))}]);
 const bytes=backup.encrypt(b,key);assert.equal(bytes.includes(Buffer.from('synthetic-safe')),false);
 assert.equal(backup.decrypt(bytes,key).manifestHash,b.manifestHash);assert.throws(()=>backup.decrypt(bytes,crypto.randomBytes(32)),/INTEGRITY/);
 const bad=Buffer.from(bytes);bad[bad.length-1]^=1;const output=join(f.root,'badrestore');assert.throws(()=>backup.restoreIsolated(bad,key,output));assert.equal(existsSync(output),false);
 const restored=backup.restoreIsolated(bytes,key,join(f.root,'restore'));assert.equal(restored.files,2);assert.equal(readFileSync(join(f.root,'restore/media/synthetic.bin')).toString(),'synthetic-safe');assert.throws(()=>backup.restoreIsolated(bytes,key,join(f.root,'restore')),/EXISTS/);
 await assert.rejects(backup.verifiedPrivateBackup(b,key,{privateVerified:false}),/PRIVATE/);
 let cloud;const receipt=await backup.verifiedPrivateBackup(b,key,{privateVerified:true,put:async data=>{cloud=Buffer.from(data);return{id:'synthetic-private-file'}},read:async()=>cloud});assert.equal(receipt.restoreVerified,false);assert.equal(receipt.integrityVerified,true);
 assert.throws(()=>backup.pack({...groups,identity:undefined},[]));
}finally{f.close();}});
test('22 verified identity mapping and owner/lead/ordinary admin hierarchy without email auto-link',()=>{const f=fixture();try{
 const a=f.actor('same-sub'),b=f.iam.resolve({verified:true,issuer:'other',sub:'same-sub',email:'same@synthetic.invalid',expiresAt:Date.now()+100000});assert.notEqual(a.uid,b.uid);assert.equal(f.actor('same-sub').uid,a.uid);
 assert.throws(()=>f.iam.change(f.client,{requestId:'bad',uid:f.client.uid,role:'OWNER'}),/OWNER_IMMUTABLE/);
 f.iam.change(f.owner,{requestId:'lead',uid:a.uid,role:'ADMIN',canManageSubordinateRoles:true});f.iam.change(a,{requestId:'author',uid:b.uid,role:'AUTHOR'});assert.equal(f.iam.current(b.uid).role,'AUTHOR');
 assert.throws(()=>f.iam.change(a,{requestId:'grant',uid:b.uid,role:'ADMIN',canManageSubordinateRoles:true}),/DENIED/);
 f.iam.change(f.owner,{requestId:'revoke-lead',uid:a.uid,role:'ADMIN'});assert.throws(()=>f.iam.change(a,{requestId:'remove',uid:b.uid,role:'CLIENT'}),/DENIED/);
 assert.equal(f.iam.current(b.uid).role,'AUTHOR');
}finally{f.close();}});
test('22 feedback consent, 10 retries, correction/retract after withdrawal, no private payload',()=>{const f=fixture();try{
 const {r,records}=ratingFixture(f),event=feedback();const q={requestId:'send',feedback:event};
 for(let i=0;i<10;i++)r.ingest(f.client,q);r.flush();let s=r.snapshot(r.readHead().head.ratingsSnapshotHash).items[0];assert.equal(s.consumerDirect.n,1);assert.equal(s.consumerDirect.mean,5);assert.equal(s.professionalDirect.mean,null);assert.equal(s.weighted.status,'NOT_CALIBRATED');
 assert.throws(()=>r.ingest(f.client,{...q,feedback:{...event,notes:'PRIVATE'}}),/UNKNOWN_RATING_FIELD/);
 r.ingest(f.client,{requestId:'edit',feedback:{...event,sequence:2,rating:3}});r.flush();assert.equal(r.snapshot(r.readHead().head.ratingsSnapshotHash).items[0].consumerDirect.mean,3);
 records.clear();const retry=r.ingest(f.client,{requestId:'edit',feedback:{...event,sequence:2,rating:3}});assert.equal(retry.sequence,2);r.ingest(f.client,{requestId:'revoke',feedback:{...event,sequence:3,consent:{schemaVersion:1,share:false}}});r.flush();s=r.snapshot(r.readHead().head.ratingsSnapshotHash).items[0];assert.equal(s.consumerDirect.n,0);assert.equal(s.consumerDirect.mean,null);
}finally{f.close();}});
test('22 course/program direct cohorts remain separate; repeated/partial/unknown/unexposed occurrences never multiply votes or reset epochs',()=>{const f=fixture();try{
 const {r}=ratingFixture(f),event=feedback('course',course,4);
 event.occurrences=[{occurrenceId:'a',target:program,status:'COMPLETED',playedMs:100,durationMs:100},{occurrenceId:'b',target:module,status:'PARTIAL',playedMs:10,durationMs:100},{occurrenceId:'b-repeat',target:module,status:'PARTIAL',playedMs:20,durationMs:100},{occurrenceId:'c',target:track,status:'NOT_EXPOSED',playedMs:0,durationMs:100},{occurrenceId:'unknown',target:track,status:'UNKNOWN',playedMs:0,durationMs:100}];
 for(let i=0;i<30;i++)r.ingest(f.actor('course-client'+i),{requestId:'course'+i,feedback:{...event,feedbackId:'c'+i}});
 for(let i=0;i<3;i++)r.ingest(f.actor('program-client'+i),{requestId:'program'+i,feedback:feedback('p'+i,program,3)});
 r.flush();const items=r.snapshot(r.readHead().head.ratingsSnapshotHash).items;const p=items.find(x=>x.target.type==='PROGRAM'),m=items.find(x=>x.target.type==='MODULE');assert.equal(p.consumerDirect.n,3);assert.equal(p.evidenceCounts.contextCourseN,30);assert.equal(m.consumerDirect.n,0);assert.equal(m.context.rootN,30);assert.equal(m.context.occurrenceN,60);assert.equal(items.some(x=>x.target.type==='TRACK'),false);
 r.ingest(f.actor('program-r2'),{requestId:'r2',feedback:feedback('r2',{...program,revisionId:'r2'},5)});r.flush();assert.equal(r.snapshot(r.readHead().head.ratingsSnapshotHash).items.find(x=>x.target.type==='PROGRAM').consumerDirect.n,4);
}finally{f.close();}});
test('22 three ratings sparse500/pro/author; two immutable policy strategies preview, ACL activation rollback/failure keep lastGood',()=>{const f=fixture();try{
 const {r}=ratingFixture(f);
 for(let i=0;i<10;i++)r.ingest(f.actor('client'+i),{requestId:'c'+i,feedback:feedback('c'+i,program,3)});
 const pro=f.actor('pro');f.iam.change(f.owner,{requestId:'pro',uid:pro.uid,role:'CLIENT',verifiedPro:true});r.ingest(pro,{requestId:'profeedback',feedback:feedback('pro',program,5)});r.ingest(f.owner,{requestId:'self',feedback:{...feedback('self',program,5),sourceApp:'PRO'}});r.flush();
 const original=r.snapshot(r.readHead().head.ratingsSnapshotHash).items[0];assert.equal(original.consumerDirect.n,10);assert.equal(original.professionalDirect.n,1);assert.equal(original.professionalDirect.mean,5);assert.equal(original.weighted.value,null);
 const before=JSON.stringify(f.s.db.prepare('SELECT * FROM t22_feedback ORDER BY owner,id').all());
 const one=policy(),two=policy(2,2),e=r.evidence(keyOf(program));assert.notEqual(calculate(program,e,one,{experimental:true}).value,calculate(program,e,two,{experimental:true}).value);assert.equal(calculate(program,e,one).value,null);
 assert.throws(()=>r.draft(f.client,{requestId:'bad',policy:one}),/ADMIN_REQUIRED/);assert.throws(()=>r.draft(f.owner,{requestId:'script',policy:{...one,config:{formula:'eval(me)'}}}),/UNKNOWN_RATING_FIELD/);
 const draft=r.draft(f.owner,{requestId:'draft',policy:one});r.validate(f.owner,{hash:draft.hash});const expected=r.readHead().head.ratingsRevision;
 r.inject=p=>{if(p==='policyRecompute')throw Error('FAIL')};assert.throws(()=>r.activate(f.owner,{requestId:'activate',hash:draft.hash,expectedRevision:expected}));assert.equal(r.readHead().head.ratingsRevision,expected);
 r.inject=()=>{};r.activate(f.owner,{requestId:'activate',hash:draft.hash,expectedRevision:expected});assert.equal(r.activePolicy().configVersion,1);assert.equal(r.snapshot(r.readHead().head.ratingsSnapshotHash).items[0].weighted.value,null);
 const second=r.draft(f.owner,{requestId:'draft2',policy:two});r.validate(f.owner,{hash:second.hash});const first=r.readHead().head;r.activate(f.owner,{requestId:'act2',hash:second.hash,expectedRevision:first.ratingsRevision});r.activate(f.owner,{requestId:'rollback',hash:first.policyHash,expectedRevision:r.readHead().head.ratingsRevision,rollback:true});assert.equal(r.activePolicy().configVersion,1);assert.equal(JSON.stringify(f.s.db.prepare('SELECT * FROM t22_feedback ORDER BY owner,id').all()),before);
 const synthetic=Array.from({length:500},(_,i)=>({target:program,kind:'direct',rating:4,reviewerKind:'CLIENT',owner:'c'+i,rootFeedbackId:'x'+i,receivedSequence:i}));assert.equal(summary(program,synthetic,r.defaultPolicy(),'now').consumerDirect.n,500);
}finally{f.close();}});
test('22 actual full SQLite/database roles/ratings/media encrypted restoration and cold readback',async()=>{const f=fixture();try{
 const {r}=ratingFixture(f);r.ingest(f.client,{requestId:'f',feedback:feedback()});r.flush();
 const media=Buffer.from('synthetic audio bytes only'),hash=crypto.createHash('sha256').update(media).digest('hex'),file=join(f.root,'synthetic.bin');require('node:fs').writeFileSync(file,media);
 f.sql.putRecord({contentId:'audio',revisionId:'r1',type:'track',sha256:hash,byteLength:media.length});
 assert.throws(()=>backup.captureCandidate(f.sql,f.s,[]),/BACKUP_MISSING_MEDIA/);
 require('../experimental/admin_overview22.cjs').overviewCache22(f.sql.db,f.s)(f.owner,()=>({scope:'admin:'+f.owner.uid,sections:[]}));
 const bundle=backup.captureCandidate(f.sql,f.s,[{contentId:'audio',revisionId:'r1',path:file}]),key=crypto.randomBytes(32),bytes=backup.encrypt(bundle,key);
 const proof=backup.restoreDatabaseIsolated(bytes,key,join(f.root,'isolated'));
 const cold=new SqliteSnapshotStore(proof.path),store=new ProjectStore22(cold.db);
 assert.deepEqual(cold.records(),f.sql.records());assert.deepEqual(store.list('roles'),f.s.list('roles'));assert.deepEqual(store.get('ratings','head'),f.s.get('ratings','head'));
 assert.equal(crypto.createHash('sha256').update(readFileSync(join(f.root,'isolated/media',hash))).digest('hex'),hash);assert.equal(proof.databaseVerified,true);cold.close();
 let cloud;const receipt=await backup.verifiedPrivateBackup(bundle,key,{privateVerified:true,put:async b=>{cloud=b;return{id:'synthetic-private'}},read:async()=>cloud},{restoreVerifier:async (b,k)=>backup.restoreDatabaseIsolated(b,k,join(f.root,'independent-restore'))});assert.equal(receipt.restoreVerified,true);
}finally{f.close();}});
test('22 Google bridge verifies before decode, stable legacy subject binding and no email/role auto-link',async()=>{
 const {googleBridge22}=require('../experimental/google_bridge22.cjs');let calls=0;
 const token=claims=>'header.'+Buffer.from(JSON.stringify(claims)).toString('base64url')+'.signature';
 const bridge=googleBridge22({verify:async()=>{calls++;return{sub:'real-shape-synthetic-sub'}},endpoint:'https://synthetic.invalid/exec'}),claims={sub:'real-shape-synthetic-sub',iss:'accounts.google.com',exp:Math.floor(Date.now()/1000)+1000,email:'ignored@synthetic.invalid',role:'OWNER'};
 const a=await bridge(token(claims)),b=await bridge(token({...claims,iss:'https://accounts.google.com'}));assert.equal(a.binding,b.binding);assert.equal(a.issuer,'https://accounts.google.com');assert.equal(a.role,undefined);assert.equal(a.email,undefined);assert.equal(calls,2);
 await assert.rejects(bridge(token({...claims,sub:'forged'})),/GOOGLE_TOKEN_INVALID/);
 await assert.rejects(googleBridge22({verify:async()=>{throw Error('DENIED')},endpoint:'x'})(token(claims)),/DENIED/);
});
test('22 policy stable immutable identity, exact public hash and changed parameters same version rejected',()=>{const f=fixture();try{
 const {r}=ratingFixture(f);r.ingest(f.client,{requestId:'r1',feedback:feedback()});r.flush();const hash=r.readHead().head.policyHash;
 r.ingest(f.client,{requestId:'r2',feedback:{...feedback(),sequence:2,rating:3}});r.flush({actor:f.owner});assert.equal(r.readHead().head.policyHash,hash);assert.equal(r.snapshot(r.readHead().head.ratingsSnapshotHash).items[0].weighted.policyHash,hash);
 const p=policy(),draft=r.draft(f.owner,{requestId:'d1',policy:p});r.validate(f.owner,{hash:draft.hash});r.activate(f.owner,{requestId:'a1',hash:draft.hash,expectedRevision:r.readHead().head.ratingsRevision});
 assert.throws(()=>r.draft(f.owner,{requestId:'d2',policy:{...p,algorithmVersion:2}}),/POLICY_VERSION_CONFLICT/);
 // Policy rollback recomputes current evidence, cannot resurrect withdrawn review.
 r.ingest(f.client,{requestId:'withdraw',feedback:{...feedback(),sequence:3,consent:{schemaVersion:1,share:false}}});r.flush();r.activate(f.owner,{requestId:'rollback-safe',hash,expectedRevision:r.readHead().head.ratingsRevision,rollback:true});assert.equal(r.snapshot(r.readHead().head.ratingsSnapshotHash).items[0].consumerDirect.n,0);
}finally{f.close();}});
test('22 only exposed course program gets context; five consumer direct votes keep professional null and weighted uncalibrated',()=>{const f=fixture();try{
 const {r,records}=ratingFixture(f),b=target('PROGRAM','not-exposed-B'),c=target('PROGRAM','unknown-C');for(const t of[b,c])records.set(t.contentId,{public:true,owner:f.owner.uid,ratingEpochId:'epoch1',exposureTargets:[]});records.get(course.contentId).exposureTargets.push(keyOf(b),keyOf(c));
 const event=feedback('partial-course',course,4);event.occurrences=[{occurrenceId:'A',target:program,status:'COMPLETED',playedMs:100,durationMs:100},{occurrenceId:'B',target:b,status:'NOT_EXPOSED',playedMs:0,durationMs:100},{occurrenceId:'C',target:c,status:'UNKNOWN',playedMs:0,durationMs:100}];r.ingest(f.client,{requestId:'course-one',feedback:event});for(let i=0;i<5;i++)r.ingest(f.actor('d'+i),{requestId:'d'+i,feedback:feedback('d'+i,program,4)});r.flush();const items=r.snapshot(r.readHead().head.ratingsSnapshotHash).items,p=items.find(s=>s.target.contentId===program.contentId);assert.equal(p.consumerDirect.mean,4);assert.equal(p.consumerDirect.n,5);assert.equal(p.professionalDirect.mean,null);assert.equal(p.weighted.value,null);assert.equal(p.context.rootN,1);assert.equal(items.some(s=>['not-exposed-B','unknown-C'].includes(s.target.contentId)),false);
}finally{f.close();}});
