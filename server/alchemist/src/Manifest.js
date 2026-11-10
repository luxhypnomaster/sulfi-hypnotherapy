var AlchemistManifest=(function(){
 'use strict';
 function create(store,services,access){
  return {execute:function(op,actor,q){
   if(op!=='content.registerManifest')AlchemistCatalog.fail(404,'UNKNOWN_CONTENT_OPERATION');
   if(!actor||!actor.roles.some(function(r){return r==='owner'||r==='author';}))AlchemistCatalog.fail(403,'AUTHOR_REQUIRED');
   var r=q.revision;
   if(!r||r.schema!==1||['track','module','template'].indexOf(r.type)<0||typeof r.logicalId!=='string'||! /^[\w-]{1,128}$/.test(r.logicalId)||!/^[a-f0-9]{64}$/.test(r.revision)||r.digest!==r.revision||!Array.isArray(r.dependencies))AlchemistCatalog.fail(422,'INVALID_MANIFEST');
   var body={type:r.type,logicalId:r.logicalId,payload:r.payload,dependencies:r.dependencies,parent:r.parent,declaredVersion:r.declaredVersion};
   if(typeof q.canonicalBody!=='string'||typeof q.canonicalRevision!=='string'||services.canonical(JSON.parse(q.canonicalBody))!==services.canonical(body)||services.canonical(JSON.parse(q.canonicalRevision))!==services.canonical(r)||services.digest(q.canonicalBody)!==r.digest)AlchemistCatalog.fail(422,'MANIFEST_DIGEST_MISMATCH');
   return services.lock(function(){store.begin();try{
    if(r.type==='track'){var track=store.asset(r.logicalId,r.revision);if(!track||track.owner!==actor.sub||track.sha256!==r.payload.contentHash||track.byteLength!==r.payload.fileSizeBytes||r.payload.filePath!=='capsule://'+track.sha256)AlchemistCatalog.fail(422,'TRACK_METADATA_MISMATCH');if(track.manifestDigest&&track.manifestDigest!==r.digest)AlchemistCatalog.fail(409,'TRACK_METADATA_IMMUTABLE');track.manifestDigest=r.digest;track.contentRevision=r;track.canonicalRevision=q.canonicalRevision;store.retainAsset(track.logicalId,track.revisionId,track);store.put('media:'+track.id,track);store.commitTransaction();return {logicalId:track.logicalId,revisionId:track.revisionId,sha256:track.sha256};}
    var refs=r.dependencies.map(function(d){if(d.digest!==String(d.revision))AlchemistCatalog.fail(422,'DEPENDENCY_CANONICAL_REFERENCE');var asset=store.asset(d.logicalId,String(d.revision));if(!asset||!access.canRead(asset,actor))AlchemistCatalog.fail(422,'MANIFEST_DEPENDENCY_MISSING');return {logicalId:asset.logicalId,revisionId:asset.revisionId,sha256:asset.sha256};});
    var prior=store.asset(r.logicalId,r.revision);if(prior){if(prior.owner!==actor.sub||prior.manifestDigest!==r.digest)AlchemistCatalog.fail(409,'MANIFEST_CONFLICT');store.rollback();return {logicalId:prior.logicalId,revisionId:prior.revisionId,sha256:prior.sha256};}
    var canonical=q.canonicalRevision,asset={id:services.uuid(),logicalId:r.logicalId,revisionId:r.revision,sha256:services.digest(canonical),manifestDigest:r.digest,owner:actor.sub,verified:true,byteLength:0,mime:'application/vnd.alchemist.manifest+json',contentRevision:r,canonicalRevision:canonical,dependencyRefs:refs};store.retainAsset(asset.logicalId,asset.revisionId,asset);store.put('media:'+asset.id,asset);store.commitTransaction();return {logicalId:asset.logicalId,revisionId:asset.revisionId,sha256:asset.sha256};
   }catch(e){store.rollback();throw e;}});
  }};
 }
 return {create:create};
})();
