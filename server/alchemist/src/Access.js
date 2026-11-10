/* Publication-reference ACL: withdrawal stops new bytes without deleting assets. */
var AlchemistAccess=(function(){
 'use strict';
 function create(store,now){
  function reachable(manifest,target,seen){return (manifest.dependencyRefs||[]).some(function(ref){var key=ref.logicalId+':'+ref.revisionId;if(seen[key])return false;seen[key]=true;var asset=store.asset(ref.logicalId,ref.revisionId);if(!asset||!asset.verified||asset.sha256!==ref.sha256)return false;if(asset.id&&target.id&&asset.id===target.id&&asset.sha256===target.sha256||asset.logicalId&&target.logicalId&&asset.logicalId===target.logicalId&&asset.revisionId===target.revisionId&&asset.sha256===target.sha256)return true;return reachable({dependencyRefs:asset.dependencyRefs||[]},target,seen);});}
  function active(item){if(item.state!=='published')return false;var publication=item.manifest.publication;if(publication&&(publication.authorClosed||publication.validUntil&&new Date(publication.validUntil).getTime()<=now()))return false;return true;}
  function canRead(asset,actor){if(!asset||!asset.verified)return false;if(asset.owner===(actor||{}).sub)return true;return store.items().some(function(item){return active(item)&&AlchemistCatalog.readable(item,actor)&&reachable(item.manifest,asset,{});});}
  return {canRead:canRead,validatePublication:function(item,actor,closure){closure.forEach(function(ref){var asset=store.asset(ref.logicalId,ref.revisionId);if(!asset||!asset.verified||(asset.owner!==actor.sub&&!canRead(asset,actor)))AlchemistCatalog.fail(403,'DEPENDENCY_PUBLISH_DENIED');});}};
 }
 return {create:create};
})();
