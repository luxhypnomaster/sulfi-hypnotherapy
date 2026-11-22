'use strict';
const {digest22,fail,id}=require('./project_store22.cjs');
const {digest,validateSnapshot}=require('./catalog_snapshot.cjs');
const own=(actor,r)=>r.owner===actor.uid||r.owner===actor.subject;
class Catalog22 {
 constructor(base,s,iam,{clock=()=>new Date().toISOString()}={}){this.base=base;this.s=s;this.iam=iam;this.clock=clock;}
 author(actor){const a=this.iam.current(actor.uid);if(!['OWNER','ADMIN','AUTHOR','EDITOR'].includes(a.role))fail(403,'AUTHOR_REQUIRED');return a;}
 target(actor,t){
  const types={template:'PROGRAM',course:'COURSE',module:'MODULE',track:'TRACK'},records=this.base.records();
  const current=records.find(r=>r.contentId===t.contentId);
  if(!current||current.state!=='published'||current.public!==true||types[current.type]!==t.type)return null;
  const at=(contentId,revisionId)=>records.find(r=>r.contentId===contentId&&r.revisionId===revisionId)||this.s.get('catalog-revisions',contentId+':'+revisionId);
  const historical=at(t.contentId,t.revisionId);if(!historical||types[historical.type]!==t.type)return null;
  const children=[],seen=new Set();const visit=x=>{for(const dep of x.dependencies||[]){const d=at(dep.contentId,dep.revisionId);if(d&&!seen.has(d.contentId+':'+d.revisionId)){seen.add(d.contentId+':'+d.revisionId);if(types[d.type])children.push([types[d.type],d.contentId,d.ratingEpochId||'initial'].join(':'));visit(d);}}};visit(historical);
  return {...historical,public:current.public,owner:current.owner,ratingEpochId:historical.ratingEpochId||'initial',exposureTargets:children};
 }
 prepare(actor,q){this.author(actor);if(!Array.isArray(q.changes)||q.changes.length<1||q.changes.length>50)fail(422,'CATALOG_BATCH_LIMIT');
  const records=this.base.records(),changed=[],next=new Map(records.map(r=>[r.contentId,r]));
  for(const c of q.changes){id(c.contentId);const old=next.get(c.contentId);if(old&&!own(actor,old)&&!['OWNER','ADMIN'].includes(this.iam.current(actor.uid).role))fail(403,'CONTENT_OWNER_DENIED');
   if(!old&&c.type!=='course')fail(422,'EXISTING_VERIFIED_CONTENT_REQUIRED');
   if(c.action==='quietEdit'&&old?.state!=='published')fail(422,'PUBLISH_EXPLICIT_REQUIRED');
   if(!['publish','withdraw','quietEdit'].includes(c.action)||Object.keys(c).some(k=>!['contentId','type','action','expectedRevisionId','patch','programRefs'].includes(k)))fail(422,'CATALOG_PATCH_SCHEMA');
   if(old&&old.revisionId!==c.expectedRevisionId)fail(409,'REVISION_CONFLICT');
   const patch=c.patch||{};if(Object.keys(patch).some(k=>!['title','description','categoryIds','tags','language','authorDisplayName'].includes(k))||patch.title!==undefined&&(typeof patch.title!=='string'||!patch.title.trim()))fail(422,'INVALID_CATALOG_PATCH');
   let r={...old,...patch,contentId:c.contentId,owner:old?.owner||actor.uid,public:old?old.public===true:true,current:true,ratingEpochId:old?.ratingEpochId||'initial',state:c.action==='withdraw'?'withdrawn':'published'};
   if(c.programRefs){if(c.type!=='course'||!Array.isArray(c.programRefs)||!c.programRefs.length||c.programRefs.length>200)fail(422,'COURSE_SCHEMA');
    const seen=new Set();for(const ref of c.programRefs){const program=next.get(ref.contentId);if(!program||program.type!=='template'||program.state!=='published'||program.revisionId!==ref.revisionId||program.sha256!==ref.sha256||seen.has(ref.contentId))fail(422,'COURSE_EXACT_REFERENCE');seen.add(ref.contentId);}
    r={...r,type:'course',programs:c.programRefs,dependencies:c.programRefs,byteLength:0};
   }
   if(!r.type||!r.title)fail(422,'MATERIAL_REQUIRED');
   const metadataRevisionId='meta-'+digest22({old:old?.revisionId||null,patch,programs:r.programs||[],state:r.state});
   // Metadata edits have an immutable editorial revision. Asset revision/bytes,
   // logical ID and rating epoch do not reset. No claim of new verified audio.
   r.metadataRevisionId=metadataRevisionId;
   if(!old||c.programRefs){r.sha256=digest22({programs:r.programs||[],contentId:r.contentId});r.revisionId='course-'+r.sha256;}
   r.catalogItemId=old?.catalogItemId||'course-'+digest22(c.contentId);next.set(c.contentId,r);changed.push(r);
  }
  const scopes=['master:public','client:public'],prepared=[];
  for(const scope of scopes){const old=this.base.head(scope),revision=(old?.catalogRevision||0)+1;
   const items=[...next.values()].filter(r=>r.public&&r.state==='published'&&r.current).map(r=>({contentId:r.contentId,revisionId:r.revisionId,type:r.type,ratingEpochId:r.ratingEpochId||'initial',title:r.title,description:r.description||'',sha256:r.sha256,byteLength:r.byteLength||0,dependencies:r.dependencies||[],catalogItemId:r.catalogItemId||r.contentId,card:{title:r.title,shortAnnotation:r.shortAnnotation||r.title,description:r.description||'',categoryIds:r.categoryIds||[],tags:r.tags||[],language:r.language||'ru',authorDisplayName:r.authorDisplayName||'',coverAssetId:r.coverAssetId||null}})).sort((a,b)=>a.contentId.localeCompare(b.contentId));
   const snapshot=validateSnapshot({schemaVersion:1,scope,catalogRevision:revision,createdAt:this.clock(),items});const hash=digest(snapshot),snapshotId='sha256-'+hash;this.base.putImmutable(scope,snapshotId,snapshot);
   if(digest(this.base.snapshot(scope,snapshotId))!==hash)fail(422,'READBACK_HASH_MISMATCH');
   prepared.push({expectedRevision:old?.catalogRevision||0,epoch:this.base.epoch(scope),head:{schemaVersion:1,scope,catalogRevision:revision,createdAt:snapshot.createdAt,snapshotId,snapshotHash:hash}});
  }
  return {changed,prepared,source:digest22(q)};
 }
 commit(actor,q,prepared){this.author(actor);return this.s.receipt(actor.uid,q.requestId,q,()=>{
  if(prepared.source!==digest22(q))fail(409,'PREPARE_PAYLOAD_MISMATCH');
  for(const p of prepared.prepared){const h=p.head;if((this.base.head(h.scope)?.catalogRevision||0)!==p.expectedRevision||this.base.epoch(h.scope)!==p.epoch)fail(409,'REVISION_CONFLICT');if(digest(this.base.snapshot(h.scope,h.snapshotId))!==h.snapshotHash)fail(422,'READBACK_HASH_MISMATCH');}
  for(const r of prepared.changed){this.s.set('catalog-revisions',r.contentId+':'+r.revisionId,r);this.base.putRecord(r);}
  for(const p of prepared.prepared){const h=p.head;this.base.db.prepare('INSERT INTO heads VALUES(?,?,?,?) ON CONFLICT(scope) DO UPDATE SET revision=excluded.revision,payload=excluded.payload,epoch=excluded.epoch').run(h.scope,h.catalogRevision,JSON.stringify(h),p.epoch);}
  this.s.audit(actor.uid,'catalog.commit',prepared.source);return {outcome:'COMMITTED',requestId:q.requestId,heads:prepared.prepared.map(p=>p.head),changed:prepared.changed.map(r=>({contentId:r.contentId,revisionId:r.revisionId,metadataRevisionId:r.metadataRevisionId}))};
 });}
 categories(actor,q){this.iam.admin(actor);return this.s.receipt(actor.uid,q.requestId,q,()=>{const name=String(q.name||'').normalize('NFKC').trim(),normalized=name.toLocaleLowerCase('ru');if(!name||name.length>120)fail(422,'CATEGORY_NAME');
  const existing=this.s.list('categories').find(r=>r.value.normalized===normalized&&r.key!==q.id);if(existing)fail(409,'CATEGORY_DUPLICATE');
  const parent=q.parentId||null;if(parent&&!this.s.get('categories',parent))fail(422,'CATEGORY_PARENT');let cursor=parent;for(let n=0;cursor&&n<100;n++){if(cursor===q.id)fail(422,'CATEGORY_CYCLE');cursor=this.s.get('categories',cursor)?.parentId;}
  const value={id:id(q.id),name,normalized,parentId:parent,archived:q.archived===true};this.s.set('categories',q.id,value);this.s.audit(actor.uid,'category.edit',q.id);return value;
 });}
}
module.exports={Catalog22};
