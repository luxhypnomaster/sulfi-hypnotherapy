/* Production catalog domain. GAS V8; all persistence/locks/identity injected. */
var AlchemistCatalog = (function () {
  'use strict';
  var types = ['track','module','template','session','collection','package','diaryEntry'];
  function fail(status, code) { var e=new Error(code);e.status=status;e.code=code;throw e; }
  function clone(x) { return JSON.parse(JSON.stringify(x)); }
  function id(x) { if(typeof x!=='string'||! /^[a-zA-Z0-9_-]{1,128}$/.test(x)||['constructor','__proto__','prototype'].indexOf(x)>=0) fail(422,'INVALID_ID');return x; }
  function hash(x) { if(typeof x!=='string'||!/^[a-f0-9]{64}$/.test(x))fail(422,'INVALID_SHA');return x; }
  function text(x,max,required) {if(typeof x!=='string'||x.length>max||(required&&!x.trim())) fail(422,'INVALID_TEXT');return x;}
  function author(actor) {if(!actor||!actor.sub||!actor.roles||!actor.roles.some(function(r){return r==='owner'||r==='author';}))fail(403,'AUTHOR_REQUIRED');}
  function readable(record,actor) {return !!record&&(record.owner===(actor||{}).sub||(record.state==='published'&&(record.card.visibility==='public'||(record.card.visibility==='restricted'&&record.readers.indexOf((actor||{}).sub)>=0))));}
  function own(record,actor) {author(actor);if(!record||record.owner!==actor.sub)fail(403,'NOT_OWNER');}
  function card(input) {
    var c={title:text(input.title,500,true),shortAnnotation:text(input.shortAnnotation,1500,true),description:text(input.description||'',50000,false),language:text(input.language||'ru',32,true),authorDisplayName:text(input.authorDisplayName||'',500,false),releaseNotes:text(input.releaseNotes||'',10000,false),visibility:input.visibility||'private',categoryIds:[],tags:[],coverAssetId:input.coverAssetId||null};
    if(['private','public','restricted'].indexOf(c.visibility)<0)fail(422,'INVALID_VISIBILITY');
    ['categoryIds','tags'].forEach(function(k){var list=input[k]||[];if(!Array.isArray(list)||list.length>100)fail(422,'INVALID_TAGS');c[k]=list.map(function(v){return text(v,128,true);});});
    if(c.coverAssetId)id(c.coverAssetId);return c;
  }
  function safeManifest(value,depth) {
    if(depth>32)fail(422,'MANIFEST_DEPTH');
    if(value&&typeof value==='object')Object.keys(value).forEach(function(k){
      if(['__proto__','constructor','prototype','filePath','localPath','driveFileId','folderId','privateLocation','token','credential','grants','readers','owner'].indexOf(k)>=0)fail(422,'PRIVATE_MANIFEST_FIELD');
      safeManifest(value[k],depth+1);
    });
    if(typeof value==='string'&&(/drive\.google\.com|^file:\/\//.test(value)))fail(422,'PRIVATE_MANIFEST_LOCATOR');
    return clone(value);
  }
  function create(env) {
    function mutate(actor,request,operation) {
      author(actor);id(request.requestId);
      return env.lock(function(){
        env.store.begin();
        try { var key=actor.sub+':'+request.requestId, digest=env.digest(request), receipt=env.store.receipt(key);
        if(receipt){if(receipt.digest!==digest)fail(409,'IDEMPOTENCY_CONFLICT');env.store.rollback();return clone(receipt.result);}
        var result=operation();env.store.saveReceipt(key,{digest:digest,result:clone(result)});env.store.commitTransaction();return result;
        } catch(error) {env.store.rollback();throw error;}
      });
    }
    function dependencyPlan(manifest,actor,installed) {
      var visiting={},seen={},ordered=[];
      function visit(ref){
        id(ref.logicalId);id(ref.revisionId);hash(ref.sha256);var token=ref.logicalId+':'+ref.revisionId;
        if(visiting[token])fail(422,'DEPENDENCY_CYCLE');if(seen[token]){if(seen[token]!==ref.sha256)fail(422,'DEPENDENCY_CONFLICT');return;}
        var asset=env.store.asset(ref.logicalId,ref.revisionId);
        if(!asset||asset.sha256!==ref.sha256||asset.verified!==true)fail(422,'MISSING_VERIFIED_DEPENDENCY');
        if(!env.canReadAsset(asset,actor))fail(403,'DEPENDENCY_DENIED');
        visiting[token]=true;(asset.dependencyRefs||[]).forEach(visit);delete visiting[token];seen[token]=ref.sha256;
        ordered.push({logicalId:ref.logicalId,revisionId:ref.revisionId,sha256:ref.sha256,byteLength:asset.byteLength,mime:asset.mime,missing:installed.indexOf(token+':'+ref.sha256)<0});
      }
      (manifest.dependencyRefs||[]).forEach(visit);
      return {dependencies:ordered,downloadBytes:ordered.filter(function(v){return v.missing;}).reduce(function(n,v){return n+v.byteLength;},0)};
    }
    function projection(r) {return {catalogItemId:r.id,type:r.type,logicalContentId:r.logicalContentId,immutableRevisionId:r.contentRevision,metadataRevision:r.metadataRevision,etag:r.etag,card:clone(r.card),manifest:clone(r.manifest),updatedAt:r.updatedAt,publicationState:r.state};}
    return {
      execute:function(op,actor,q){q=q||{};
        if(op==='catalog.createDraft')return mutate(actor,q,function(){
          id(q.catalogItemId);if(types.indexOf(q.type)<0)fail(422,'INVALID_TYPE');if(env.store.item(q.catalogItemId))fail(409,'ITEM_EXISTS');
          var r={id:q.catalogItemId,owner:actor.sub,type:q.type,logicalContentId:id(q.logicalContentId),contentRevision:id(q.immutableRevisionId),metadataRevision:1,etag:'1',state:'draft',card:card(q.card),manifest:safeManifest(q.manifest||{},0),readers:[],updatedAt:env.now()};
          env.store.commit(r);return projection(r);
        });
        if(['catalog.patchDraft','catalog.updateMetadata','catalog.publish','catalog.withdraw','catalog.archive','catalog.restore'].indexOf(op)>=0)return mutate(actor,q,function(){
          var r=env.store.item(id(q.catalogItemId));own(r,actor);if(q.ifMatch!==r.etag)fail(412,'ETAG_CONFLICT');r=clone(r);
          if(op==='catalog.patchDraft'||op==='catalog.updateMetadata'){r.card=card(Object.assign({},r.card,q.card));r.metadataRevision++;}
          if(op==='catalog.patchDraft'&&q.manifest){if(r.state==='published')fail(409,'CONTENT_REVISION_REQUIRED');r.manifest=safeManifest(q.manifest,0);r.contentRevision=id(q.immutableRevisionId);}
          if(op==='catalog.publish'){
            dependencyPlan(r.manifest,actor,[]);
            if(r.card.visibility==='public')dependencyPlan(r.manifest,null,[]);
            if(!r.manifest.dependencyRefs||!r.manifest.dependencyRefs.length)fail(422,'EMPTY_CONTENT');
            if(r.card.coverAssetId){var cover=env.store.cover(r.card.coverAssetId);if(!cover||!cover.verified||cover.owner!==actor.sub)fail(422,'INVALID_COVER');}
            r.state='published';r.readers=(q.readerSubjects||[]).map(function(s){return text(s,256,true);});
            // Asset grants are publication references, never Drive sharing ACL.
            env.validatePublication(r,actor);
          }
          if(op==='catalog.withdraw')r.state='withdrawn';if(op==='catalog.archive')r.state='archived';if(op==='catalog.restore')r.state='draft';
          r.etag=String(Number(r.etag)+1);r.updatedAt=env.now();env.store.commit(r);return projection(r);
        });
        if(op==='catalog.get'||op==='catalog.getInstallPlan'){
          var r=env.store.item(id(q.catalogItemId));if(!readable(r,actor))fail(404,'NOT_AVAILABLE');
          return op==='catalog.get'?projection(r):dependencyPlan(r.manifest,actor,q.installed||[]);
        }
        if(op==='catalog.list'||op==='catalog.search'){
          var revision=env.store.indexRevision(),offset=0;
          if(q.cursor){var cursor=env.decodeCursor(q.cursor);if(cursor.revision!==revision||cursor.query!==env.digest({type:q.type||null,search:q.search||'',category:q.category||null,tag:q.tag||null}))fail(409,'SNAPSHOT_CHANGED');offset=cursor.offset;if(!Number.isSafeInteger(offset)||offset<0)fail(422,'INVALID_CURSOR');}
          var items=env.store.items().filter(function(r){return readable(r,actor)&&(!q.type||r.type===q.type)&&(!q.search||(r.card.title+' '+r.card.shortAnnotation).toLowerCase().indexOf(q.search.toLowerCase())>=0)&&(!q.category||r.card.categoryIds.indexOf(q.category)>=0)&&(!q.tag||r.card.tags.indexOf(q.tag)>=0);}).sort(function(a,b){return a.id.localeCompare(b.id);});
          var limit=q.limit===undefined?25:q.limit;if(!Number.isSafeInteger(limit)||limit<1||limit>50)fail(422,'INVALID_LIMIT');
          var end=offset+limit;return {items:items.slice(offset,end).map(projection),revision:revision,nextPage:end<items.length?env.encodeCursor({revision:revision,offset:end,query:env.digest({type:q.type||null,search:q.search||'',category:q.category||null,tag:q.tag||null})}):null};
        }
        fail(404,'UNKNOWN_OPERATION');
      }
    };
  }
  return {create:create,fail:fail,readable:readable,types:types};
})();
