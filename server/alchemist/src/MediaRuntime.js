var AlchemistMediaRuntime=(function(){
 'use strict';
 function create(store,drive,services){
  function tx(fn){return services.lock(function(){store.begin();try{var result=fn();store.commitTransaction();return result;}catch(e){store.rollback();throw e;}});}
  var access=AlchemistAccess.create(store,services.now);
  return AlchemistTransfer.create({lock:tx,uuid:services.uuid,now:services.now,decode:services.decode,encode:services.encode,digest:services.digest,drive:drive,
   sessions:{get:function(id){return store.get('upload:'+id);},put:function(s){store.put('upload:'+s.id,s);store.put('upload-request:'+s.owner+':'+s.requestId,{id:s.id});},byRequest:function(sub,key){var pointer=store.get('upload-request:'+sub+':'+key);return pointer?store.get('upload:'+pointer.id):null;}},
   chunks:{get:function(id,offset){return store.get('chunk:'+id+':'+offset);},put:function(id,offset,value){store.put('chunk:'+id+':'+offset,value);}},
   assets:{existing:function(actor,q){var key=store.get('media-digest:'+actor.sub+':'+q.sha256);var asset=key?store.get('media:'+key.id):null;return asset&&asset.verified&&asset.owner===actor.sub&&asset.mime===q.mime&&asset.byteLength===q.byteLength?asset:null;},alias:function(actor,q,prior){var logicalId=q.logicalId||prior.logicalId,revisionId=q.revisionId||prior.revisionId,old=store.asset(logicalId,revisionId);if(old&&(old.owner!==actor.sub||old.sha256!==prior.sha256))AlchemistCatalog.fail(409,'IMMUTABLE_ASSET_CONFLICT');var asset=Object.assign({},prior,{id:services.uuid(),logicalId:logicalId,revisionId:revisionId});store.put('media:'+asset.id,asset);store.retainAsset(logicalId,revisionId,asset);return asset.id;},get:function(id){return store.get('media:'+id);},canRead:access.canRead,retain:function(s,v){var id=s.id,asset={id:id,logicalId:s.logicalId||id,revisionId:s.revisionId||s.sha256,owner:s.owner,sha256:v.sha256,byteLength:v.byteLength,mime:s.mime,verified:true,privateLocation:{fileId:v.privateFileId},dependencyRefs:[]};var prior=store.asset(asset.logicalId,asset.revisionId);if(prior&&(prior.sha256!==asset.sha256||prior.owner!==asset.owner))AlchemistCatalog.fail(409,'IMMUTABLE_ASSET_CONFLICT');store.put('media:'+id,asset);store.put('media-digest:'+s.owner+':'+s.sha256,{id:id});store.retainAsset(asset.logicalId,asset.revisionId,asset);return id;}}
  });
 }
 return {create:create};
})();
