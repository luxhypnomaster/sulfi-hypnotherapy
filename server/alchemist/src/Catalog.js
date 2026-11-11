/* Production catalog domain. GAS V8; all persistence/locks/identity injected. */
var AlchemistCatalog = (function () {
  'use strict';
  var types = ['track','module','template','session','collection','package','diaryEntry'];
  function fail(status, code) { code=code||({401:'AUTHENTICATION_FAILED',403:'ACCESS_DENIED',503:'SERVICE_UNAVAILABLE'}[status])||'REQUEST_REJECTED';var e=new Error(code);e.status=status;e.code=code;throw e; }
  function clone(x) { return JSON.parse(JSON.stringify(x)); }
  function id(x) { if(typeof x!=='string'||! /^[a-zA-Z0-9_-]{1,128}$/.test(x)||['constructor','__proto__','prototype'].indexOf(x)>=0) fail(422,'INVALID_ID');return x; }
  function hash(x) { if(typeof x!=='string'||!/^[a-f0-9]{64}$/.test(x))fail(422,'INVALID_SHA');return x; }
  function text(x,max,required) {if(typeof x!=='string'||x.length>max||(required&&!x.trim())) fail(422,'INVALID_TEXT');return x;}
  function author(actor) {if(!actor||!actor.sub||!actor.roles||!actor.roles.some(function(r){return r==='owner'||r==='author';}))fail(403,'AUTHOR_REQUIRED');}
  function exposed(record,actor) {return record&&record.owner===(actor||{}).sub?record:record&&record.publishedRecord||record;}
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
      if(!Array.isArray(installed)||installed.length>2000||installed.some(function(v){return typeof v!=='string'||v.length>400;}))fail(422,'INVALID_INSTALLED_LIST');
      var visiting={},seen={},versions={},ordered=[];
      function visit(ref){
        id(ref.logicalId);id(ref.revisionId);hash(ref.sha256);var token=ref.logicalId+':'+ref.revisionId;
        if(versions[ref.logicalId]&&versions[ref.logicalId]!==ref.revisionId)fail(422,'DEPENDENCY_VERSION_CONFLICT');versions[ref.logicalId]=ref.revisionId;
        if(visiting[token])fail(422,'DEPENDENCY_CYCLE');if(seen[token]){if(seen[token]!==ref.sha256)fail(422,'DEPENDENCY_CONFLICT');return;}
        var asset=env.store.asset(ref.logicalId,ref.revisionId);
        if(!asset||asset.sha256!==ref.sha256||asset.verified!==true)fail(422,'MISSING_VERIFIED_DEPENDENCY');
        if(!env.canReadAsset(asset,actor))fail(403,'DEPENDENCY_DENIED');
        visiting[token]=true;(asset.dependencyRefs||[]).forEach(visit);delete visiting[token];seen[token]=ref.sha256;
        ordered.push({assetRevisionId:asset.id||null,logicalId:ref.logicalId,revisionId:ref.revisionId,sha256:ref.sha256,byteLength:asset.byteLength,mime:asset.mime,missing:installed.indexOf(token+':'+ref.sha256)<0});
      }
      (manifest.dependencyRefs||[]).forEach(visit);
      var known={};installed.forEach(function(v){var h=v.split(':').pop();if(/^[a-f0-9]{64}$/.test(h))known[h]=true;});var total=0;ordered.forEach(function(v){v.downloadRequired=v.byteLength>0&&v.missing&&!known[v.sha256];if(v.downloadRequired){total+=v.byteLength;known[v.sha256]=true;}});return {dependencies:ordered,downloadBytes:total};
    }
    function projection(r,brief) {var c=clone(r.card);if(brief){delete c.description;delete c.releaseNotes;}return {catalogItemId:r.id,type:r.type,logicalContentId:r.logicalContentId,immutableRevisionId:r.contentRevision,metadataRevision:r.metadataRevision,etag:r.etag,card:c,...(brief?{}:{manifest:clone(r.manifest)}),updatedAt:r.updatedAt,publicationState:r.state,summary:r.summary||null};}
    function virtual(idValue,actor){if(typeof idValue!=='string'||idValue.indexOf('_asset_')!==0)return null;var a=env.store.get('media:'+idValue.slice(7));if(!a||!a.contentRevision||!env.canReadAsset(a,actor))fail(404,'EXACT_PUBLICATION_UNAVAILABLE');var p=a.contentRevision.payload;return {id:idValue,type:a.contentRevision.type,logicalContentId:a.logicalId,contentRevision:a.revisionId,metadataRevision:1,etag:a.manifestDigest,state:a.owner===(actor||{}).sub?'draft':'published',owner:a.owner,card:{title:p.title||p.name||'Материал',shortAnnotation:'Материал по точной ссылке',description:p.description||'',visibility:actor?'restricted':'public',categoryIds:[],tags:[],language:'ru',authorDisplayName:'',releaseNotes:'',coverAssetId:null},manifest:{schemaVersion:1,dependencyRefs:[{logicalId:a.logicalId,revisionId:a.revisionId,sha256:a.sha256}]},readers:[],updatedAt:null};}
    return {
      transactRecord:function(actor,request,operation,callback){return mutate(actor,Object.assign({},request,{_operation:operation}),function(){var record=env.store.item(id(request.catalogItemId));if(record)own(record,actor);if(record&&request.ifMatch!==record.etag)fail(412,'ETAG_CONFLICT');var next=callback(record?clone(record):null);safeManifest(next.manifest,0);if(next.state==='published'){var publicCandidate=next.publishedRecord||next;env.validatePublication(publicCandidate,actor,dependencyPlan(publicCandidate.manifest,actor,[]).dependencies);}env.store.commit(next);return projection(next);});},
      execute:function(op,actor,q){q=Object.assign({},q||{},{_operation:op});
        if(op==='catalog.createDraft')return mutate(actor,q,function(){
          id(q.catalogItemId);if(types.indexOf(q.type)<0)fail(422,'INVALID_TYPE');if(env.store.item(q.catalogItemId))fail(409,'ITEM_EXISTS');
          var r={id:q.catalogItemId,owner:actor.sub,type:q.type,logicalContentId:id(q.logicalContentId),contentRevision:id(q.immutableRevisionId),metadataRevision:1,etag:'1',state:'draft',card:card(q.card),manifest:safeManifest(q.manifest||{},0),publishedRecord:null,readers:[],updatedAt:env.now()};
          env.store.commit(r);return projection(r);
        });
        if(['catalog.patchDraft','catalog.updateMetadata','catalog.publish','catalog.withdraw','catalog.archive','catalog.restore'].indexOf(op)>=0)return mutate(actor,q,function(){
          var r=env.store.item(id(q.catalogItemId));own(r,actor);if(q.ifMatch!==r.etag)fail(412,'ETAG_CONFLICT');r=clone(r);
          if(op==='catalog.patchDraft'||op==='catalog.updateMetadata'){r.card=card(Object.assign({},r.card,q.card));r.metadataRevision++;}
          if(op==='catalog.patchDraft'&&q.manifest){r.manifest=safeManifest(q.manifest,0);r.contentRevision=id(q.immutableRevisionId);}
          if(op==='catalog.publish'){
            dependencyPlan(r.manifest,actor,[]);

            if((!r.manifest.dependencyRefs||!r.manifest.dependencyRefs.length)&&!(r.type==='diaryEntry'&&r.manifest.entry&&Array.isArray(r.manifest.entry.blocks)&&r.manifest.entry.blocks.some(function(b){return b.type==='text'&&typeof b.text==='string'&&b.text.trim();})))fail(422,'EMPTY_CONTENT');
            if(r.card.coverAssetId){var cover=env.store.cover(r.card.coverAssetId);if(!cover||!cover.verified||cover.owner!==actor.sub)fail(422,'INVALID_COVER');}
            var verifiedPlan=dependencyPlan(r.manifest,actor,[]);r.summary={downloadBytes:verifiedPlan.downloadBytes,dependencyCount:verifiedPlan.dependencies.length};
            r.state='published';if(r.card.visibility==='public')r.wasPublic=true;r.readers=(q.readerSubjects||[]).map(function(s){return text(s,256,true);});
            // Asset grants are publication references, never Drive sharing ACL.
            env.validatePublication(r,actor,dependencyPlan(r.manifest,actor,[]).dependencies);
          }
          if(op==='catalog.withdraw')r.state='withdrawn';if(op==='catalog.archive')r.state='archived';if(op==='catalog.restore')r.state='draft';
          r.etag=String(Number(r.etag)+1);r.updatedAt=env.now();if(op==='catalog.publish'||op==='catalog.updateMetadata'&&r.state==='published'){var snapshot=op==='catalog.updateMetadata'&&r.publishedRecord?clone(r.publishedRecord):clone(r);delete snapshot.publishedRecord;if(op==='catalog.updateMetadata'){snapshot.card=card(Object.assign({},snapshot.card,q.card));snapshot.etag=r.etag;snapshot.metadataRevision=r.metadataRevision;snapshot.updatedAt=r.updatedAt;}if(op==='catalog.updateMetadata'){if(snapshot.card.coverAssetId){var updatedCover=env.store.cover(snapshot.card.coverAssetId);if(!updatedCover||!updatedCover.verified||updatedCover.owner!==actor.sub)fail(422,'INVALID_COVER');}env.validatePublication(snapshot,actor,dependencyPlan(snapshot.manifest,actor,[]).dependencies);}r.publishedRecord=snapshot;}if(op==='catalog.withdraw'||op==='catalog.archive')r.publishedRecord=null;env.store.commit(r);return projection(r);
        });
        if(op==='catalog.getRevision'){
          var current=exposed(env.store.item(id(q.catalogItemId)),actor);if(!readable(current,actor))fail(404,'NOT_AVAILABLE');
          var historical=env.store.revision(id(q.catalogItemId),String(q.etag));if(!historical||historical.owner!==current.owner)fail(404,'REVISION_NOT_FOUND');
          if(current.owner!==(actor||{}).sub){if(!historical.publishedRecord||historical.publishedRecord.etag!==String(q.etag)||!readable(historical.publishedRecord,actor))fail(404,'REVISION_NOT_AVAILABLE');historical=historical.publishedRecord;}return projection(historical);
        }
        if(op==='catalog.diff'){
          var existing=env.store.item(id(q.catalogItemId));own(existing,actor);var before=dependencyPlan(existing.manifest,actor,[]),after=dependencyPlan(safeManifest(q.manifest||existing.manifest,0),actor,[]),known={};before.dependencies.forEach(function(d){known[d.sha256]=true;});return {newDependencies:after.dependencies.filter(function(d){return !known[d.sha256];}),metadataOnly:JSON.stringify(existing.manifest)===JSON.stringify(q.manifest||existing.manifest)};
        }
        if(op==='catalog.checkUpdates'){
          if(!Array.isArray(q.installed)||q.installed.length>500)fail(422,'INVALID_INSTALLED_LIST');return {updates:env.store.items().map(function(r){return exposed(r,actor);}).filter(function(r){return readable(r,actor)&&q.installed.some(function(i){return i.catalogItemId===r.id&&i.immutableRevisionId!==r.contentRevision;});}).map(function(r){return projection(exposed(env.store.item(r.id),actor));})};
        }
        if(op==='catalog.attachAsset')return mutate(actor,q,function(){
          var item=env.store.item(id(q.catalogItemId));own(item,actor);if(q.ifMatch!==item.etag)fail(412,'ETAG_CONFLICT');if(item.state==='published')fail(409,'NEW_CONTENT_REVISION_REQUIRED');var ref=q.reference;dependencyPlan({dependencyRefs:[ref]},actor,[]);item=clone(item);item.manifest.dependencyRefs=item.manifest.dependencyRefs||[];if(!item.manifest.dependencyRefs.some(function(r){return r.logicalId===ref.logicalId&&r.revisionId===ref.revisionId&&r.sha256===ref.sha256;}))item.manifest.dependencyRefs.push(clone(ref));item.etag=String(Number(item.etag)+1);item.updatedAt=env.now();env.store.commit(item);return projection(item);
        });
        if(op==='catalog.validateDependencies'){var draft=env.store.item(id(q.catalogItemId));own(draft,actor);return dependencyPlan(draft.manifest,actor,q.installed||[]);}
        if(op==='catalog.resolveReference'){
          id(q.logicalId);id(q.revisionId);if(q.digest&&q.digest!==q.revisionId)fail(422,'REFERENCE_DIGEST_MISMATCH');var found=env.store.items().map(function(r){return r&&r.publishedRecord||null;}).filter(function(r){return r&&r.state==='published'&&readable(r,actor)&&r.logicalContentId===q.logicalId&&r.contentRevision===q.revisionId;});if(!found.length)fail(404,'EXACT_PUBLICATION_UNAVAILABLE');if(q.digest){var asset=env.store.asset(q.logicalId,q.revisionId);if(!asset||!asset.verified||q.digest!==asset.manifestDigest)fail(404,'EXACT_PUBLICATION_UNAVAILABLE');}return projection(env.store.item(found[0].id).publishedRecord);
        }
        if(op==='catalog.changes'){
          var since=q.sinceRevision||0;if(!Number.isSafeInteger(since)||since<0)fail(422,'INVALID_SINCE');
          var changes=env.store.items().filter(function(r){return r.owner===(actor||{}).sub||readable(exposed(r,actor),actor)||r.wasPublic===true;}).map(function(r){var view=exposed(r,actor);return readable(view,actor)?projection(view,true):{catalogItemId:r.id,publicationState:'unavailable',tombstone:true};});
          var start=q.offset||0;if(!Number.isSafeInteger(start)||start<0)fail(422,'INVALID_CURSOR');if(q.snapshotRevision!==undefined&&q.snapshotRevision!==env.store.indexRevision())fail(409,'SNAPSHOT_CHANGED');
          return {items:since===env.store.indexRevision()?[]:changes.slice(start,start+50),revision:env.store.indexRevision(),nextOffset:start+50<changes.length?start+50:null};
        }
        if(op==='catalog.get'||op==='catalog.getInstallPlan'){
          var virtualRecord=virtual(q.catalogItemId,actor);if(virtualRecord)return op==='catalog.get'?projection(virtualRecord):dependencyPlan(virtualRecord.manifest,actor,q.installed||[]);
          var r=exposed(env.store.item(id(q.catalogItemId)),actor);if(!readable(r,actor))fail(404,'NOT_AVAILABLE');
          return op==='catalog.get'?projection(r):dependencyPlan(r.manifest,actor,q.installed||[]);
        }
        if(op==='catalog.list'||op==='catalog.search'){
          var revision=env.store.indexRevision(),offset=0;
          if(q.cursor){var cursor=env.decodeCursor(q.cursor);if(cursor.revision!==revision||cursor.query!==env.digest({type:q.type||null,readerView:q.readerView===true,ownedOnly:q.ownedOnly===true,includeManifest:q.includeManifest===true,search:q.search||'',category:q.category||null,tag:q.tag||null,state:q.state||null,subject:(actor||{}).sub||null}))fail(409,'SNAPSHOT_CHANGED');offset=cursor.offset;if(!Number.isSafeInteger(offset)||offset<0)fail(422,'INVALID_CURSOR');}
          var limit=q.limit===undefined?25:q.limit;if(!Number.isSafeInteger(limit)||limit<1||limit>50)fail(422,'INVALID_LIMIT');
          var indexed=!!env.store.candidates,candidates=indexed?env.store.candidates(actor,q):env.store.items().map(function(r){return r.id;}),end=offset,selected=[],budget=0,scanned=0;
          while(end<candidates.length&&selected.length<limit&&scanned<100){var record=indexed?env.store.card(candidates[end]):env.store.item(candidates[end]),r=q.readerView===true?record&&record.publishedRecord:exposed(record,actor);end++;scanned++;
           if(!readable(r,actor)||q.ownedOnly&&r.owner!==(actor||{}).sub||q.type&&r.type!==q.type||q.state&&r.state!==q.state||q.search&&(r.card.title+' '+r.card.shortAnnotation).toLowerCase().indexOf(q.search.toLowerCase())<0||q.category&&r.card.categoryIds.indexOf(q.category)<0||q.tag&&r.card.tags.indexOf(q.tag)<0)continue;
           if(q.includeManifest===true){var full=env.store.item(r.id);r=q.readerView===true?full.publishedRecord:exposed(full,actor);}
           var view=projection(r,q.includeManifest!==true),cost=JSON.stringify(view).length*3;if(selected.length&&budget+cost>1300000){end--;break;}selected.push(view);budget+=cost;
          }
          return {items:selected,revision:revision,nextPage:end<candidates.length?env.encodeCursor({revision:revision,offset:end,query:env.digest({type:q.type||null,readerView:q.readerView===true,ownedOnly:q.ownedOnly===true,includeManifest:q.includeManifest===true,search:q.search||'',category:q.category||null,tag:q.tag||null,state:q.state||null,subject:(actor||{}).sub||null})}):null};
        }
        fail(404,'UNKNOWN_OPERATION');
      }
    };
  }
  return {create:create,fail:fail,readable:readable,types:types,exposed:exposed};
})();
