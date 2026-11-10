import {test} from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import vm from 'node:vm';import {createHash} from 'node:crypto';
const ctx=vm.createContext({});for(const file of ['AtomicStore','Catalog','Access','Transfer','MediaRuntime'])vm.runInContext(readFileSync(new URL('../src/'+file+'.js',import.meta.url),'utf8'),ctx);
const sha=x=>createHash('sha256').update(x).digest('hex'),json=x=>JSON.parse(JSON.stringify(x)),owner={sub:'owner',roles:['owner']};
test('real transaction store links media to publications, persists replay, revokes each chunk on withdrawal',()=>{
 let head=null,n=0;const files=new Map(),blobs=new Map();
 const io={head:()=>head,read:k=>structuredClone(files.get(k)),writeVerified:v=>{const k=String(++n);files.set(k,structuredClone(v));return k;},setHead:k=>head=k,digest:sha};
 let store=ctx.AlchemistAtomicStore.create(io);
 const access=ctx.AlchemistAccess.create(store,()=>0),services={lock:f=>f(),uuid:()=> 'asset-'+(++n),now:()=>0,encode:b=>Buffer.from(b).toString('base64'),decode:s=>Buffer.from(s,'base64'),digest:sha};
 const drive={begin:()=>({url:'PRIVATE'}),write:(s,o,b)=>{blobs.set(s.id,Buffer.from(b));return b.length;},verify:s=>({sha256:sha(blobs.get(s.id)),byteLength:blobs.get(s.id).length,privateFileId:s.id}),read:(a,o,n)=>blobs.get(a.id).subarray(o,o+n)};
 const media=ctx.AlchemistMediaRuntime.create(store,drive,services),bytes=Buffer.from('media fixture');
 const request={requestId:'upload-1',logicalId:'track-1',revisionId:'r1',byteLength:bytes.length,mime:'audio/mpeg',sha256:sha(bytes)};
 const started=media.begin(owner,request);media.upload(owner,{sessionId:started.sessionId,offset:0,base64:bytes.toString('base64')});const committed=media.commit(owner,{sessionId:started.sessionId});
 assert.throws(()=>media.descriptor(null,{assetRevisionId:committed.assetRevisionId}),/NOT_AVAILABLE/);
 const core=ctx.AlchemistCatalog.create({store,lock:f=>f(),now:()=>new Date(0).toISOString(),digest:x=>sha(JSON.stringify(x)),canReadAsset:access.canRead,validatePublication:access.validatePublication,encodeCursor:JSON.stringify,decodeCursor:JSON.parse});
 core.execute('catalog.createDraft',owner,{requestId:'create',catalogItemId:'card',type:'track',logicalContentId:'track-1',immutableRevisionId:'r1',card:{title:'Трек',shortAnnotation:'Аннотация',visibility:'public'},manifest:{dependencyRefs:[{logicalId:'track-1',revisionId:'r1',sha256:sha(bytes)}]}});
 core.execute('catalog.publish',owner,{requestId:'publish',catalogItemId:'card',ifMatch:'1'});
 assert.equal(Buffer.from(media.download(null,{assetRevisionId:committed.assetRevisionId,offset:0,length:bytes.length}).base64,'base64').toString(),bytes.toString());
 assert.throws(()=>core.execute('catalog.withdraw',owner,{requestId:'publish',catalogItemId:'card',ifMatch:'1'}),/IDEMPOTENCY/);
 core.execute('catalog.withdraw',owner,{requestId:'withdraw',catalogItemId:'card',ifMatch:'2'});
 assert.throws(()=>media.download(null,{assetRevisionId:committed.assetRevisionId,offset:0,length:1}),/NOT_AVAILABLE/);
 assert.equal(blobs.size,1);assert.equal(store.revision('card','2').state,'published');
 store=ctx.AlchemistAtomicStore.create(io);assert.equal(store.receipt('owner:publish').result.publicationState,'published');assert.equal(store.item('card').state,'withdrawn');
});
test('reader grants never authorize republication of foreign private bytes; source withdrawal revokes foreign links',()=>{
 let head=null,n=0;const files=new Map();
 const store=ctx.AlchemistAtomicStore.create({head:()=>head,read:k=>structuredClone(files.get(k)),writeVerified:v=>{const k=String(++n);files.set(k,structuredClone(v));return k;},setHead:k=>head=k,digest:sha});
 const access=ctx.AlchemistAccess.create(store,()=>0),bob={sub:'bob',roles:['author']},alice={sub:'alice',roles:['author']};
 const asset={id:'blob',logicalId:'private-audio',revisionId:'v1',sha256:sha('bytes'),owner:'bob',verified:true,byteLength:5,mime:'audio/mpeg',dependencyRefs:[]},ref={logicalId:asset.logicalId,revisionId:asset.revisionId,sha256:asset.sha256};
 store.begin();store.retainAsset(asset.logicalId,asset.revisionId,asset);store.put('media:'+asset.id,asset);store.commitTransaction();
 const core=ctx.AlchemistCatalog.create({store,lock:f=>f(),now:()=>new Date(0).toISOString(),digest:x=>sha(JSON.stringify(x)),canReadAsset:access.canRead,validatePublication:access.validatePublication,encodeCursor:JSON.stringify,decodeCursor:JSON.parse});
 function draft(who,id){return core.execute('catalog.createDraft',who,{requestId:'create-'+id,catalogItemId:id,type:'track',logicalContentId:asset.logicalId,immutableRevisionId:asset.revisionId,card:{title:id,shortAnnotation:'fixture',visibility:who.sub==='bob'?'restricted':'public'},manifest:{dependencyRefs:[ref]}});}
 draft(bob,'bob-source');core.execute('catalog.publish',bob,{requestId:'publish-bob',catalogItemId:'bob-source',ifMatch:'1',readerSubjects:['alice']});
 assert.equal(access.canRead(asset,alice),true);assert.equal(access.canRead(asset,null),false);
 draft(alice,'alice-copy');assert.throws(()=>core.execute('catalog.publish',alice,{requestId:'bad-publish',catalogItemId:'alice-copy',ifMatch:'1'}),/PRIVATE_FOREIGN/);
 core.execute('catalog.updateMetadata',bob,{requestId:'make-public',catalogItemId:'bob-source',ifMatch:'2',card:{visibility:'public'}});
 core.execute('catalog.publish',alice,{requestId:'allowed-link',catalogItemId:'alice-copy',ifMatch:'1'});assert.equal(access.canRead(asset,null),true);
 core.execute('catalog.withdraw',bob,{requestId:'withdraw-source',catalogItemId:'bob-source',ifMatch:'3'});
 assert.equal(access.canRead(asset,null),false);assert.equal(access.canRead(asset,alice),false);assert.equal(access.canRead(asset,bob),true);
});
test('indexed ACL and catalog ignore thousands of transfer receipts; cover grants and complete manifests survive reopen',()=>{
 let head=null,n=0,reads=0;const files=new Map();
 const io={head:()=>head,read:k=>{reads++;return structuredClone(files.get(k));},writeVerified:v=>{const k=String(++n);files.set(k,structuredClone(v));return k;},setHead:k=>head=k,digest:sha};
 let store=ctx.AlchemistAtomicStore.create(io);
 const image={id:'cover',logicalId:'image',revisionId:'v1',sha256:sha('png'),owner:'owner',verified:true,byteLength:3,mime:'image/png',dependencyRefs:[]};
 store.begin();store.retainAsset('image','v1',image);store.put('cover:cover',image);for(let i=0;i<10000;i++)store.put('chunk:large:'+i,{offset:i});store.commitTransaction();
 let access=ctx.AlchemistAccess.create(store,()=>0);
 function catalog(){return ctx.AlchemistCatalog.create({store,lock:f=>f(),now:()=>new Date(0).toISOString(),digest:x=>sha(JSON.stringify(x)),canReadAsset:access.canRead,validatePublication:access.validatePublication,encodeCursor:JSON.stringify,decodeCursor:JSON.parse});}
 let core=catalog();core.execute('catalog.createDraft',owner,{requestId:'create',catalogItemId:'card',type:'diaryEntry',logicalContentId:'entry',immutableRevisionId:'v1',card:{title:'Full diary',shortAnnotation:'Approved',visibility:'public',coverAssetId:'cover'},manifest:{dependencyRefs:[],entry:{blocks:[{id:'text',type:'text',text:'COMPLETE BODY'}]}}});
 core.execute('catalog.publish',owner,{requestId:'publish',catalogItemId:'card',ifMatch:'1'});
 store=ctx.AlchemistAtomicStore.create(io);access=ctx.AlchemistAccess.create(store,()=>0);core=catalog();reads=0;
 assert.equal(access.canRead(image,null),true);assert.ok(reads<=2,`range ACL read ${reads} files`);
 const page=core.execute('catalog.list',null,{includeManifest:true,readerView:true});assert.equal(page.items[0].manifest.entry.blocks[0].text,'COMPLETE BODY');assert.ok(reads<=5,`page read ${reads} files`);
 assert.equal(core.execute('catalog.resolveReference',null,{logicalId:'entry',revisionId:'v1'}).manifest.entry.blocks[0].text,'COMPLETE BODY');
 assert.equal(core.execute('catalog.checkUpdates',null,{installed:[{catalogItemId:'card',immutableRevisionId:'old'}]}).updates[0].manifest.entry.blocks[0].text,'COMPLETE BODY');
 core.execute('catalog.withdraw',owner,{requestId:'withdraw',catalogItemId:'card',ifMatch:'2'});assert.equal(access.canRead(image,null),false);
 assert.equal(core.execute('catalog.list',null,{}).items.length,0);assert.equal(store.scan('chunk:').length,10000);
});
