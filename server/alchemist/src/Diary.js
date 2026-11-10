/* Diary documents use the same private working/public immutable catalog commits. */
var AlchemistDiary=(function(){
 'use strict';
 function create(core,store,services){
  function fail(code){AlchemistCatalog.fail(422,code);}
  function normalized(e){
   if(!e||typeof e.id!=='string'||! /^[\w-]{1,120}$/.test(e.id)||!Array.isArray(e.blocks)||e.blocks.length>1000)fail('INVALID_ENTRY');
   var seen={},refs=[];
   var blocks=e.blocks.map(function(b){if(!b||typeof b.id!=='string'||seen[b.id]||['text','image','audio','video','contentLink'].indexOf(b.type)<0)fail('INVALID_BLOCK');seen[b.id]=true;
    if(b.type==='text'){if(typeof b.text!=='string'||b.text.length>400000)fail('INVALID_TEXT_BLOCK');return {id:b.id,type:'text',text:b.text};}
    if(b.type==='contentLink'){if(!b.link||!b.link.logicalId||!b.link.revisionId||!/^[a-f0-9]{64}$/.test(b.link.sha256))fail('INVALID_CONTENT_LINK');refs.push(b.link);return {id:b.id,type:b.type,link:b.link};}
    var ref=b.mediaRef;if(!ref||typeof ref.logicalId!=='string'||typeof ref.revisionId!=='string'||!/^[a-f0-9]{64}$/.test(ref.sha256))fail('INVALID_MEDIA_REFERENCE');refs.push(ref);return {id:b.id,type:b.type,mediaRef:ref,label:typeof b.label==='string'?b.label:'',caption:typeof b.caption==='string'?b.caption:'',altText:typeof b.altText==='string'?b.altText:'',width:b.width||null,height:b.height||null,durationMs:b.durationMs||null};
   });
   var publication=e.publication||{categoryId:'announcements',priority:'normal',urgent:false,activationCycleId:services.uuid(),activatedAt:services.now(),authorClosed:false,validUntil:null};
   if(typeof publication.activationCycleId!=='string'||['normal','high'].indexOf(publication.priority)<0||publication.validUntil&&!Number.isFinite(Date.parse(publication.validUntil)))fail('INVALID_PUBLICATION');
   return {dependencyRefs:refs,entry:{id:e.id,title:String(e.title||''),message:String(e.message||''),blocks:blocks,publication:publication},publication:publication};
  }
  function catalogId(q){if(typeof q.entryId!=='string'||!/^[\w-]{1,120}$/.test(q.entryId))fail('INVALID_ENTRY_ID');return 'entry_'+q.entryId;}
  function project(card){return {entry:card.manifest.entry,publication:card.manifest.publication,etag:card.etag,status:card.publicationState,revision:card.immutableRevisionId};}
  return {execute:function(op,actor,q){q=q||{};
   if(op==='feed.list'){var feed=core.execute('catalog.list',actor,{type:'diaryEntry',cursor:q.cursor,limit:q.limit});return {entries:feed.items.map(project),revision:feed.revision,nextPage:feed.nextPage};}
   if(op==='entry.get')return project(core.execute('catalog.get',actor,{catalogItemId:catalogId(q)}));
   var allowed=['entry.createDraft','entry.patchDraft','entry.publish','entry.unpublish','entry.archive','entry.deleteSoft','entry.restore','entry.reannounce','entry.close','entry.visibility','entry.updateMetadata'];
   if(allowed.indexOf(op)>=0){
    var entryId=q.entryId||q.entry&&q.entry.id;
    var command=Object.assign({},q,{catalogItemId:catalogId({entryId:entryId})});
    return project(core.transactRecord(actor,command,op,function(r){
      if(op==='entry.createDraft'){
       if(r)AlchemistCatalog.fail(409,'ENTRY_EXISTS');var m=normalized(q.entry);r={id:command.catalogItemId,owner:actor.sub,type:'diaryEntry',logicalContentId:entryId,contentRevision:services.uuid(),metadataRevision:1,etag:'1',state:'draft',card:{title:m.entry.title||'Без названия',shortAnnotation:m.entry.message||'Запись дневника',visibility:q.visibility||'private',categoryIds:[],tags:[],language:'ru',authorDisplayName:'',description:'',releaseNotes:'',coverAssetId:null},manifest:m,readers:[],publishedRecord:null,updatedAt:services.now()};return r;
      }
      if(!r)AlchemistCatalog.fail(404,'ENTRY_NOT_FOUND');
      if(op==='entry.patchDraft'){r.manifest=normalized(q.entry);r.contentRevision=services.uuid();r.card.title=r.manifest.entry.title||'Без названия';r.card.shortAnnotation=r.manifest.entry.message||'Запись дневника';}
      if(op==='entry.updateMetadata'){if(typeof q.title==='string'){r.manifest.entry.title=q.title;r.card.title=q.title;}if(typeof q.message==='string'){r.manifest.entry.message=q.message;r.card.shortAnnotation=q.message;}r.metadataRevision++;}
      if(op==='entry.reannounce'){r.manifest.publication.activationCycleId=services.uuid();r.manifest.publication.activatedAt=services.now();r.manifest.publication.authorClosed=false;r.manifest.entry.publication=r.manifest.publication;}
      if(op==='entry.close'){r.manifest.publication.authorClosed=true;r.manifest.entry.publication=r.manifest.publication;}
      if(op==='entry.visibility'){if(['private','public','restricted'].indexOf(q.visibility)<0)fail('INVALID_VISIBILITY');r.card.visibility=q.visibility;}
      if(op==='entry.publish'){if(!r.manifest.entry.blocks.some(function(b){return b.type==='text'&&b.text.trim()||b.mediaRef||b.link;}))fail('EMPTY_ENTRY');if(q.readerSubjects&&!Array.isArray(q.readerSubjects))fail('INVALID_READERS');r.state='published';r.readers=(q.readerSubjects||[]).map(function(s){if(typeof s!=='string'||!s||s.length>256)fail('INVALID_READER');return s;});}
      if(op==='entry.unpublish')r.state='withdrawn';if(op==='entry.archive'||op==='entry.deleteSoft')r.state='archived';if(op==='entry.restore')r.state='draft';
      r.etag=String(Number(r.etag)+1);r.updatedAt=services.now();
      if(r.state==='published'&&op!=='entry.patchDraft'){var publicRecord=JSON.parse(JSON.stringify(op!=='entry.publish'&&r.publishedRecord?r.publishedRecord:r));delete publicRecord.publishedRecord;publicRecord.etag=r.etag;publicRecord.updatedAt=r.updatedAt;if(op==='entry.updateMetadata'){if(typeof q.title==='string'){publicRecord.card.title=q.title;publicRecord.manifest.entry.title=q.title;}if(typeof q.message==='string'){publicRecord.card.shortAnnotation=q.message;publicRecord.manifest.entry.message=q.message;}}if(op==='entry.close'||op==='entry.reannounce'){publicRecord.manifest.publication=r.manifest.publication;publicRecord.manifest.entry.publication=r.manifest.publication;}if(op==='entry.visibility')publicRecord.card.visibility=r.card.visibility;r.publishedRecord=publicRecord;}
      if(r.state!=='published')r.publishedRecord=null;
      return r;
    }));
   }
   AlchemistCatalog.fail(404,'UNKNOWN_DIARY_OPERATION');
  }};
 }
 return {create:create};
})();
