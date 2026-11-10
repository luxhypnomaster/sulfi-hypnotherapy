import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const context=vm.createContext({});
for(const f of ['Catalog','Storage'])vm.runInContext(readFileSync(new URL('../src/'+f+'.js',import.meta.url),'utf8'),context);
const plain=x=>JSON.parse(JSON.stringify(x));
const actor={sub:'owner',roles:['owner']};
function fixture(){
 let revision=0;const items=new Map(),receipts=new Map(),assets=new Map();
 const env={digest:x=>createHash('sha256').update(JSON.stringify(x)).digest('hex'),now:()=>new Date(0).toISOString(),lock:f=>f(),canReadAsset:(a,p)=>a.owner===p?.sub||a.public,
 validatePublication:r=>{for(const ref of r.manifest.dependencyRefs){const a=assets.get(ref.logicalId+':'+ref.revisionId);if(r.card.visibility==='public'&&!a.public)throw new Error('PRIVATE_DEPENDENCY');}},
 store:{begin:()=>{},rollback:()=>{},commitTransaction:()=>{},item:id=>items.get(id),items:()=>[...items.values()],indexRevision:()=>revision,asset:(id,r)=>assets.get(id+':'+r),cover:()=>null,receipt:k=>receipts.get(k),saveReceipt:(k,v)=>receipts.set(k,v),commit:r=>{items.set(r.id,plain(r));revision++;}},encodeCursor:x=>JSON.stringify(x),decodeCursor:x=>JSON.parse(x)};
 const c=context.AlchemistCatalog.create(env);return {c,assets,items,receipts};
}
const hash='a'.repeat(64),ref={logicalId:'track1',revisionId:'v1',sha256:hash};
function draft(type='track'){return {requestId:'create',catalogItemId:'card1',type,logicalContentId:'content1',immutableRevisionId:'v1',card:{title:'Название',shortAnnotation:'Аннотация',visibility:'public'},manifest:{dependencyRefs:[ref]}};}
test('five publication kinds, annotation metadata-only, grants and selective exact dependency plan',()=>{
 for(const type of ['track','module','template','collection','diaryEntry']){
 const f=fixture();f.assets.set('track1:v1',{owner:'owner',public:true,verified:true,sha256:hash,byteLength:100,mime:'audio/mpeg'});
 const d=f.c.execute('catalog.createDraft',actor,draft(type));assert.equal(d.card.shortAnnotation,'Аннотация');assert.equal(f.c.execute('catalog.list',null,{}).items.length,0);
 const pub=f.c.execute('catalog.publish',actor,{requestId:'publish',catalogItemId:'card1',ifMatch:'1'});assert.equal(pub.publicationState,'published');
 const changed=f.c.execute('catalog.updateMetadata',actor,{requestId:'meta',catalogItemId:'card1',ifMatch:'2',card:{shortAnnotation:'Новая аннотация'}});assert.equal(changed.immutableRevisionId,pub.immutableRevisionId);assert.equal(f.assets.size,1);
 const plan=f.c.execute('catalog.getInstallPlan',null,{catalogItemId:'card1',installed:['track1:v1:'+hash]});assert.equal(plan.downloadBytes,0);
 assert.throws(()=>f.c.execute('catalog.withdraw',{sub:'reader',roles:['client']},{requestId:'bad'}));
 f.c.execute('catalog.withdraw',actor,{requestId:'withdraw',catalogItemId:'card1',ifMatch:'3'});assert.equal(f.c.execute('catalog.list',null,{}).items.length,0);assert.equal(f.assets.size,1);
 }
});
test('idempotence, stale etag, missing/corrupt/private dependency, cursor consistency',()=>{
 const f=fixture();const request=draft();f.c.execute('catalog.createDraft',actor,request);assert.deepEqual(plain(f.c.execute('catalog.createDraft',actor,request)),plain(f.c.execute('catalog.createDraft',actor,request)));
 assert.throws(()=>f.c.execute('catalog.createDraft',actor,{...request,card:{...request.card,title:'Other'}}),/IDEMPOTENCY/);
 assert.throws(()=>f.c.execute('catalog.publish',actor,{requestId:'p',catalogItemId:'card1',ifMatch:'0'}),/ETAG/);
 assert.throws(()=>f.c.execute('catalog.publish',actor,{requestId:'p2',catalogItemId:'card1',ifMatch:'1'}),/MISSING/);
 assert.equal(f.items.get('card1').state,'draft');
 f.assets.set('track1:v1',{owner:'owner',public:false,verified:true,sha256:hash,byteLength:100});assert.throws(()=>f.c.execute('catalog.publish',actor,{requestId:'p3',catalogItemId:'card1',ifMatch:'1'}),/PRIVATE_DEPENDENCY|DEPENDENCY_DENIED/);
 assert.equal(f.items.get('card1').state,'draft');
});
test('storage bootstrap exact tree replay and unsafe/ambiguous ACL fail closed',()=>{
 const folders=new Map([['parent',{id:'parent',name:'Проект Алхимик',mimeType:'application/vnd.google-apps.folder',owner:'owner',permissions:[{role:'owner',subject:'owner'}]}]]),registry=new Map();let n=0;
 const d={get:id=>folders.get(id),find:(name,parent)=>[...folders.values()].filter(f=>f.name===name&&f.parent===parent),create:(name,parent)=>{const f={id:'f'+(++n),name,parent,mimeType:'application/vnd.google-apps.folder',owner:'owner',permissions:[{role:'owner',subject:'owner'}]};folders.set(f.id,f);return f;}};
 const r={get:k=>registry.get(k),put:(k,v)=>registry.set(k,v)};
 const first=context.AlchemistStorage.bootstrap(d,r,'parent','owner');assert.equal(Object.keys(first.folders).length,40);const count=folders.size;
 assert.deepEqual(plain(context.AlchemistStorage.bootstrap(d,r,'parent','owner')),plain(first));assert.equal(folders.size,count);
 folders.get('parent').permissions.push({role:'reader',subject:'anyone'});assert.throws(()=>context.AlchemistStorage.bootstrap(d,r,'parent','owner'),/ACL/);assert.equal(folders.size,count);
});
