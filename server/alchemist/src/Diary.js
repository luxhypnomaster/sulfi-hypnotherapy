/* Diary documents use the same private working/public immutable catalog commits. */
var AlchemistDiary=(function(){
 'use strict';
 function create(core,store,services){
  function fail(code){AlchemistCatalog.fail(422,code);}
  function publishedLink(logicalId,revisionId,digest,actor){
   try{return core.execute('catalog.resolveReference',actor,{logicalId:logicalId,revisionId:String(revisionId),digest:digest});}
   catch(e){if(e.status===404)fail('CONTENT_LINK_NOT_PUBLISHED');throw e;}
  }
  function validateLinks(entry,actor){
   (entry.contentLinks||[]).forEach(function(l){publishedLink(l.logicalId,l.revision,l.digest,actor);});
   (entry.blocks||[]).filter(function(b){return b.type==='contentLink';}).forEach(function(b){var a=store.asset(b.link.logicalId,b.link.revisionId);if(!a||!a.manifestDigest)fail('CONTENT_LINK_NOT_PUBLISHED');publishedLink(a.logicalId,a.revisionId,a.manifestDigest,actor);});
  }
  function normalized(e,actor){
   if(!e||typeof e.id!=='string'||! /^[\w-]{1,120}$/.test(e.id)||!Array.isArray(e.blocks)||e.blocks.length>1000)fail('INVALID_ENTRY');
   var seen={},refs=[];
   var links=(e.contentLinks||[]).map(function(link){if(!link||['track','module','template'].indexOf(link.type)<0||['install','open'].indexOf(link.action)<0)fail('INVALID_CONTENT_LINK');var asset=store.asset(link.logicalId,String(link.revision));if(!asset||!asset.verified||!asset.contentRevision||asset.contentRevision.type!==link.type||asset.manifestDigest!==link.digest)fail('CONTENT_LINK_REVISION_MISSING');publishedLink(asset.logicalId,asset.revisionId,link.digest,actor);return {type:link.type,logicalId:link.logicalId,revision:String(link.revision),digest:link.digest,action:link.action};});
   var blocks=e.blocks.map(function(b){if(!b||typeof b.id!=='string'||seen[b.id]||['text','image','audio','video','contentLink'].indexOf(b.type)<0)fail('INVALID_BLOCK');seen[b.id]=true;
    if(b.type==='text'){if(typeof b.text!=='string'||b.text.length>400000)fail('INVALID_TEXT_BLOCK');return {id:b.id,type:'text',text:b.text};}
    if(b.type==='contentLink'){if(!b.link||!b.link.logicalId||!b.link.revisionId||!/^[a-f0-9]{64}$/.test(b.link.sha256))fail('INVALID_CONTENT_LINK');var linked=store.asset(b.link.logicalId,b.link.revisionId);if(!linked||linked.sha256!==b.link.sha256||!linked.manifestDigest||!linked.contentRevision||['track','module','template'].indexOf(linked.contentRevision.type)<0)fail('CONTENT_LINK_NOT_PUBLISHED');publishedLink(linked.logicalId,linked.revisionId,linked.manifestDigest,actor);return {id:b.id,type:b.type,link:b.link};}
    var ref=b.mediaRef;if(!ref||typeof ref.logicalId!=='string'||typeof ref.revisionId!=='string'||!/^[a-f0-9]{64}$/.test(ref.sha256))fail('INVALID_MEDIA_REFERENCE');refs.push(ref);return {id:b.id,type:b.type,mediaRef:ref,label:typeof b.label==='string'?b.label:'',caption:typeof b.caption==='string'?b.caption:'',altText:typeof b.altText==='string'?b.altText:'',width:b.width||null,height:b.height||null,durationMs:b.durationMs||null};
   });
   var publication=e.publication||{categoryId:'announcements',priority:'normal',urgent:false,activationCycleId:services.uuid(),activatedAt:services.now(),authorClosed:false,validUntil:null};
   if(typeof publication.activationCycleId!=='string'||['normal','high'].indexOf(publication.priority)<0||publication.validUntil&&!Number.isFinite(Date.parse(publication.validUntil)))fail('INVALID_PUBLICATION');
   return {dependencyRefs:refs,entry:{id:e.id,title:String(e.title||''),message:String(e.message||''),blocks:blocks,contentLinks:links,order:Number.isSafeInteger(e.order)?e.order:0,createdAt:e.createdAt||services.now(),publication:publication},publication:publication};
  }
  function catalogId(q){if(typeof q.entryId!=='string'||!/^[\w-]{1,120}$/.test(q.entryId))fail('INVALID_ENTRY_ID');return 'entry_'+q.entryId;}
  function project(card){var entry=JSON.parse(JSON.stringify(card.manifest.entry));entry.blocks=entry.blocks.map(function(b){if(b.mediaRef){var asset=store.asset(b.mediaRef.logicalId,b.mediaRef.revisionId);if(!asset||!asset.verified||asset.sha256!==b.mediaRef.sha256)fail('MEDIA_REFERENCE_UNAVAILABLE');b.media={assetId:asset.id,mime:asset.mime,bytes:asset.byteLength,hash:asset.sha256,locator:'alchemist:'+asset.id};}return b;});entry.schemaVersion=2;entry.status=card.publicationState==='published'?'published':card.publicationState==='draft'?'draft':'unpublished';entry.version=Number(card.etag);entry.updatedAt=card.updatedAt;entry.publishedAt=card.publicationState==='published'?card.manifest.publication.activatedAt:null;return {entry:entry,visibility:card.card.visibility,publication:card.manifest.publication,etag:card.etag,status:card.publicationState,revision:card.immutableRevisionId};}
  return {execute:function(op,actor,q){q=q||{};
   if(op==='feed.list'){var feed=core.execute('catalog.list',actor,{type:'diaryEntry',cursor:q.cursor,limit:q.limit,includeManifest:true,readerView:q.ownedOnly!==true,ownedOnly:q.ownedOnly===true});return {entries:feed.items.map(project),revision:feed.revision,nextPage:feed.nextPage};}
   if(op==='entry.get')return project(core.execute('catalog.get',actor,{catalogItemId:catalogId(q)}));
   var allowed=['entry.createDraft','entry.patchDraft','entry.publish','entry.unpublish','entry.archive','entry.deleteSoft','entry.restore','entry.reannounce','entry.close','entry.visibility','entry.updateMetadata','media.linkToEntry'];
   if(allowed.indexOf(op)>=0){
    var entryId=q.entryId||q.entry&&q.entry.id;
    var command=Object.assign({},q,{catalogItemId:catalogId({entryId:entryId})});
    return project(core.transactRecord(actor,command,op,function(r){
      if(op==='entry.createDraft'){
       if(r)AlchemistCatalog.fail(409,'ENTRY_EXISTS');var m=normalized(q.entry,actor);r={id:command.catalogItemId,owner:actor.sub,type:'diaryEntry',logicalContentId:entryId,contentRevision:services.uuid(),metadataRevision:1,etag:'1',state:'draft',card:{title:m.entry.title||'Без названия',shortAnnotation:m.entry.message||'Запись дневника',visibility:q.visibility||'private',categoryIds:[],tags:[],language:'ru',authorDisplayName:'',description:'',releaseNotes:'',coverAssetId:null},manifest:m,readers:[],publishedRecord:null,updatedAt:services.now()};return r;
      }
      if(!r)AlchemistCatalog.fail(404,'ENTRY_NOT_FOUND');
      if(op==='media.linkToEntry'){var entry=JSON.parse(JSON.stringify(r.manifest.entry));entry.blocks.push(q.block);r.manifest=normalized(entry,actor);r.contentRevision=services.uuid();}
      if(op==='entry.patchDraft'){r.manifest=normalized(q.entry,actor);r.contentRevision=services.uuid();r.card.title=r.manifest.entry.title||'Без названия';r.card.shortAnnotation=r.manifest.entry.message||'Запись дневника';}
      if(op==='entry.updateMetadata'){if(q.publication){var p=normalized(Object.assign({},r.manifest.entry,{publication:q.publication}),actor).publication;if(p.activationCycleId!==r.manifest.publication.activationCycleId)fail('USE_REANNOUNCE');r.manifest.publication=p;r.manifest.entry.publication=p;}if(q.order!==undefined){if(!Number.isSafeInteger(q.order))fail('INVALID_ORDER');r.manifest.entry.order=q.order;}if(typeof q.title==='string'){r.manifest.entry.title=q.title;r.card.title=q.title;}if(typeof q.message==='string'){r.manifest.entry.message=q.message;r.card.shortAnnotation=q.message;}r.metadataRevision++;}
      if(op==='entry.reannounce'){r.manifest.publication.activationCycleId=services.uuid();r.manifest.publication.activatedAt=services.now();r.manifest.publication.authorClosed=false;r.manifest.entry.publication=r.manifest.publication;}
      if(op==='entry.close'){r.manifest.publication.authorClosed=true;r.manifest.entry.publication=r.manifest.publication;}
      if(op==='entry.visibility'){if(['private','public','restricted'].indexOf(q.visibility)<0)fail('INVALID_VISIBILITY');r.card.visibility=q.visibility;}
      if(op==='entry.publish'){validateLinks(r.manifest.entry,actor);if(!r.manifest.entry.message.trim()&&!r.manifest.entry.blocks.some(function(b){return b.type==='text'&&b.text.trim()||b.mediaRef||b.link;}))fail('EMPTY_ENTRY');if(q.readerSubjects&&!Array.isArray(q.readerSubjects))fail('INVALID_READERS');r.state='published';if(r.card.visibility==='public')r.wasPublic=true;r.readers=(q.readerSubjects||[]).map(function(s){if(typeof s!=='string'||!s||s.length>256)fail('INVALID_READER');return s;});}
      if(op==='entry.unpublish')r.state='withdrawn';if(op==='entry.archive'||op==='entry.deleteSoft')r.state='archived';if(op==='entry.restore')r.state='draft';
      r.etag=String(Number(r.etag)+1);r.updatedAt=services.now();
      if(r.state==='published'&&op!=='entry.patchDraft'&&op!=='media.linkToEntry'){var publicRecord=JSON.parse(JSON.stringify(op!=='entry.publish'&&r.publishedRecord?r.publishedRecord:r));delete publicRecord.publishedRecord;publicRecord.etag=r.etag;publicRecord.updatedAt=r.updatedAt;if(op==='entry.updateMetadata'){publicRecord.manifest.publication=r.manifest.publication;publicRecord.manifest.entry.publication=r.manifest.publication;publicRecord.manifest.entry.order=r.manifest.entry.order;if(typeof q.title==='string'){publicRecord.card.title=q.title;publicRecord.manifest.entry.title=q.title;}if(typeof q.message==='string'){publicRecord.card.shortAnnotation=q.message;publicRecord.manifest.entry.message=q.message;}}if(op==='entry.close'||op==='entry.reannounce'){publicRecord.manifest.publication=r.manifest.publication;publicRecord.manifest.entry.publication=r.manifest.publication;}if(op==='entry.visibility')publicRecord.card.visibility=r.card.visibility;r.publishedRecord=publicRecord;}
      if(r.state!=='published')r.publishedRecord=null;
      return r;
    }));
   }
   AlchemistCatalog.fail(404,'UNKNOWN_DIARY_OPERATION');
  }};
 }
 return {create:create};
})();
