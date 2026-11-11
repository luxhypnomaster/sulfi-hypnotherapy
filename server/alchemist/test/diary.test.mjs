import {test} from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import vm from 'node:vm';import {createHash} from 'node:crypto';
const c=vm.createContext({});for(const f of ['Catalog','AtomicStore','Diary'])vm.runInContext(readFileSync(new URL('../src/'+f+'.js',import.meta.url),'utf8'),c);
test('diary private draft, immutable public snapshot, idempotent retry, quiet edit/reannounce/close and private working revision',()=>{
 let head=null,n=0;const files=new Map(),io={head:()=>head,read:k=>structuredClone(files.get(k)),writeVerified:v=>{let k=String(++n);files.set(k,structuredClone(v));return k;},setHead:k=>head=k,digest:s=>createHash('sha256').update(s).digest('hex')};const store=c.AlchemistAtomicStore.create(io);
 const core=c.AlchemistCatalog.create({store,lock:f=>f(),now:()=>new Date(0).toISOString(),digest:v=>io.digest(JSON.stringify(v)),canReadAsset:()=>true,validatePublication:()=>{},encodeCursor:JSON.stringify,decodeCursor:JSON.parse});let uuid=0;
 const diary=c.AlchemistDiary.create(core,store,{uuid:()=> 'id-'+(++uuid),now:()=>new Date(0).toISOString()}),owner={sub:'owner',roles:['owner']},entry={id:'one',title:'Название',message:'Послание',blocks:[{id:'text',type:'text',text:'Оригинальный текст'}]};
 const draft=diary.execute('entry.createDraft',owner,{requestId:'create',entry,visibility:'public'});assert.equal(draft.status,'draft');assert.equal(diary.execute('entry.createDraft',owner,{requestId:'create',entry,visibility:'public'}).etag,draft.etag);
 assert.equal(diary.execute('feed.list',null,{}).entries.length,0);
 const published=diary.execute('entry.publish',owner,{entryId:'one',requestId:'publish',ifMatch:'1'});const cycle=published.publication.activationCycleId;
 const patch=diary.execute('entry.patchDraft',owner,{entryId:'one',requestId:'patch',ifMatch:'2',entry:{...entry,blocks:[{id:'text',type:'text',text:'PRIVATE_NEW_WORKING_TEXT'}],publication:published.publication}});
 assert.equal(patch.etag,'3');const publicData=JSON.stringify(diary.execute('feed.list',null,{}));assert.match(publicData,/Оригинальный текст/);assert.doesNotMatch(publicData,/PRIVATE_NEW_WORKING_TEXT/);assert.doesNotMatch(JSON.stringify(diary.execute('feed.list',owner,{})),/PRIVATE_NEW_WORKING_TEXT/);assert.match(JSON.stringify(diary.execute('feed.list',owner,{ownedOnly:true})),/PRIVATE_NEW_WORKING_TEXT/);
 const safe=diary.execute('entry.updateMetadata',owner,{entryId:'one',requestId:'safe-quiet',ifMatch:'3',title:'Safe title'});assert.doesNotMatch(JSON.stringify(diary.execute('feed.list',null,{})),/PRIVATE_NEW_WORKING_TEXT/);
 assert.throws(()=>core.execute('catalog.getRevision',null,{catalogItemId:'entry_one',etag:'3'}),/REVISION_NOT_AVAILABLE/);
 diary.execute('entry.publish',owner,{entryId:'one',requestId:'publish2',ifMatch:'4'});
 const quiet=diary.execute('entry.updateMetadata',owner,{entryId:'one',requestId:'quiet',ifMatch:'5',title:'Quiet'});assert.equal(quiet.publication.activationCycleId,cycle);
 const again=diary.execute('entry.reannounce',owner,{entryId:'one',requestId:'again',ifMatch:'6'});assert.notEqual(again.publication.activationCycleId,cycle);
 const retry=diary.execute('entry.reannounce',owner,{entryId:'one',requestId:'again',ifMatch:'6'});assert.equal(retry.publication.activationCycleId,again.publication.activationCycleId);
 const closed=diary.execute('entry.close',owner,{entryId:'one',requestId:'close',ifMatch:'7'});assert.equal(closed.publication.authorClosed,true);
 assert.throws(()=>diary.execute('entry.archive',{sub:'reader',roles:['client']},{entryId:'one',requestId:'malicious',ifMatch:'7'}),/AUTHOR_REQUIRED/);
});

test('16-A: diary links require published exact typed roots; they never grant withdrawn assets or convert voice attachments into tracks',()=>{
 let head=null,n=0;const files=new Map(),io={head:()=>head,read:k=>structuredClone(files.get(k)),writeVerified:v=>{const k=String(++n);files.set(k,structuredClone(v));return k;},setHead:k=>head=k,digest:s=>createHash('sha256').update(s).digest('hex')};
 vm.runInContext(readFileSync(new URL('../src/Access.js',import.meta.url),'utf8'),c);
 const store=c.AlchemistAtomicStore.create(io),access=c.AlchemistAccess.create(store,()=>0),hash='a'.repeat(64),rev='b'.repeat(64),owner={sub:'owner',roles:['owner']};
 store.begin();store.retainAsset('module',rev,{id:'module-asset',logicalId:'module',revisionId:rev,owner:'owner',verified:true,sha256:hash,manifestDigest:rev,contentRevision:{type:'module',payload:{title:'Модуль'}},dependencyRefs:[],byteLength:0,mime:'application/json'});store.retainAsset('voice','v1',{id:'voice-asset',logicalId:'voice',revisionId:'v1',owner:'owner',verified:true,sha256:hash,byteLength:10,mime:'audio/mp4',dependencyRefs:[]});store.commitTransaction();
 const core=c.AlchemistCatalog.create({store,lock:f=>f(),now:()=>new Date(0).toISOString(),digest:v=>io.digest(JSON.stringify(v)),canReadAsset:access.canRead,validatePublication:access.validatePublication,encodeCursor:JSON.stringify,decodeCursor:JSON.parse});
 const diary=c.AlchemistDiary.create(core,store,{uuid:()=>String(++n),now:()=>new Date(0).toISOString()}),entry={id:'linked',title:'Ссылка',message:'Текст',blocks:[{id:'text',type:'text',text:'Текст'}],contentLinks:[{type:'module',logicalId:'module',revision:rev,digest:rev,action:'install'}]};
 assert.throws(()=>diary.execute('entry.createDraft',owner,{entry,requestId:'unpublished'}),/CONTENT_LINK_NOT_PUBLISHED/);
 core.execute('catalog.createDraft',owner,{requestId:'module-draft',catalogItemId:'card',type:'module',logicalContentId:'module',immutableRevisionId:rev,card:{title:'Модуль',shortAnnotation:'Аннотация',visibility:'public'},manifest:{dependencyRefs:[{logicalId:'module',revisionId:rev,sha256:hash}]}});
 core.execute('catalog.publish',owner,{requestId:'module-publish',catalogItemId:'card',ifMatch:'1'});
 assert.throws(()=>diary.execute('entry.createDraft',owner,{entry:{...entry,contentLinks:[{...entry.contentLinks[0],type:'track'}]},requestId:'wrong-type'}),/CONTENT_LINK_REVISION_MISSING/);
 diary.execute('entry.createDraft',owner,{entry,requestId:'valid-link',visibility:'public'});
 diary.execute('entry.publish',owner,{entryId:entry.id,requestId:'publish-entry',ifMatch:'1'});
 assert.equal(store.item('entry_linked').manifest.dependencyRefs.length,0);
 assert.equal(access.canRead(store.asset('module',rev),null),true);
 core.execute('catalog.withdraw',owner,{requestId:'withdraw-module',catalogItemId:'card',ifMatch:'2'});
 assert.equal(diary.execute('feed.list',null,{}).entries.length,1);
 assert.equal(access.canRead(store.asset('module',rev),null),false,'public diary link is not an independent access grant');
 assert.throws(()=>core.execute('catalog.resolveReference',owner,{logicalId:'module',revisionId:rev,digest:rev}),/EXACT_PUBLICATION_UNAVAILABLE/);
 assert.throws(()=>diary.execute('entry.publish',owner,{entryId:entry.id,requestId:'republish-after-withdraw',ifMatch:'2'}),/CONTENT_LINK_NOT_PUBLISHED/);
 const voice={...entry,id:'raw-voice',contentLinks:[],blocks:[{id:'voice',type:'audio',mediaRef:{logicalId:'voice',revisionId:'v1',sha256:hash}}]};
 diary.execute('entry.createDraft',owner,{entry:voice,requestId:'voice-entry',visibility:'public'});diary.execute('entry.publish',owner,{entryId:voice.id,requestId:'voice-publish',ifMatch:'1'});
 assert.equal(access.canRead(store.asset('voice','v1'),null),true);
 assert.throws(()=>core.execute('catalog.resolveReference',null,{logicalId:'voice',revisionId:'v1',digest:hash}),/EXACT_PUBLICATION_UNAVAILABLE|REFERENCE_DIGEST_MISMATCH/);
});

test('16-A legacy v4 diary grants are filtered on read without deleting content; real voice attachments stay readable',()=>{
 vm.runInContext(readFileSync(new URL('../src/Access.js',import.meta.url),'utf8'),c);
 let head=null,n=0;const files=new Map(),io={head:()=>head,read:k=>structuredClone(files.get(k)),writeVerified:v=>{const k=String(++n);files.set(k,structuredClone(v));return k;},setHead:k=>head=k,digest:s=>createHash('sha256').update(s).digest('hex')};
 const store=c.AlchemistAtomicStore.create(io),hash='c'.repeat(64),owner={sub:'owner',roles:['owner']},ref=id=>({logicalId:id,revisionId:'v1',sha256:hash});
 store.begin();for(const id of ['linked-module','voice'])store.retainAsset(id,'v1',{id:id+'-asset',logicalId:id,revisionId:'v1',owner:'owner',verified:true,sha256:hash,byteLength:10,mime:'audio/mp4',dependencyRefs:[]});
 const old={id:'entry_legacy',owner:'owner',type:'diaryEntry',logicalContentId:'legacy',contentRevision:'v1',metadataRevision:1,etag:'2',state:'published',card:{title:'История',shortAnnotation:'Аннотация',visibility:'public',coverAssetId:null},manifest:{dependencyRefs:[ref('linked-module'),ref('voice')],entry:{blocks:[{id:'text',type:'text',text:'Saved old entry'},{id:'voice',type:'audio',mediaRef:ref('voice')}],contentLinks:[{type:'module',logicalId:'linked-module',revision:'v1',digest:hash,action:'install'}]}},readers:[],updatedAt:new Date(0).toISOString()};
 store.commit({...old,publishedRecord:old});
 // Inject exactly the old grant shape, independent of the corrected writer.
 for(const id of ['linked-module','voice'])store.put('asset-grants:'+id+':v1',[{publicationId:old.id,owner:'owner',visibility:'public',readers:[],publication:null}]);store.commitTransaction();
 const access=c.AlchemistAccess.create(store,()=>0);assert.equal(access.canRead(store.asset('linked-module','v1'),null),false);assert.equal(access.canRead(store.asset('voice','v1'),null),true);assert.equal(access.canRead(store.asset('linked-module','v1'),owner),true);
 assert.equal(store.item(old.id).manifest.entry.blocks[0].text,'Saved old entry');assert.equal(store.asset('linked-module','v1').verified,true);
 // New writes do not add material ContentLinks as diary grants at all.
 store.begin();store.commit({...old,id:'entry_new',publishedRecord:{...old,id:'entry_new'}});store.commitTransaction();
 assert.equal(store.assetGrants('linked-module','v1').some(g=>g.publicationId==='entry_new'),false);assert.equal(store.assetGrants('voice','v1').some(g=>g.publicationId==='entry_new'&&g.grantPolicyVersion===2),true);
});
