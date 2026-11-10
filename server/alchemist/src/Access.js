/* Publication-reference ACL: withdrawal stops new bytes without deleting assets. */
var AlchemistAccess=(function(){
 'use strict';
 function create(store,now){
  function reachable(manifest,target,seen){return (manifest.dependencyRefs||[]).some(function(ref){var key=ref.logicalId+':'+ref.revisionId;if(seen[key])return false;seen[key]=true;var asset=store.asset(ref.logicalId,ref.revisionId);if(!asset||!asset.verified||asset.sha256!==ref.sha256)return false;if(asset.id&&target.id&&asset.id===target.id&&asset.sha256===target.sha256||asset.logicalId&&target.logicalId&&asset.logicalId===target.logicalId&&asset.revisionId===target.revisionId&&asset.sha256===target.sha256)return true;return reachable({dependencyRefs:asset.dependencyRefs||[]},target,seen);});}
  function active(item){if(item.state!=='published')return false;var publication=item.manifest.publication;if(publication&&(publication.authorClosed||publication.validUntil&&new Date(publication.validUntil).getTime()<=now()))return false;return true;}
  function canRead(asset,actor){if(!asset||!asset.verified)return false;if(asset.owner===(actor||{}).sub)return true;return store.items().some(function(item){item=AlchemistCatalog.exposed(item,actor);return item.owner===asset.owner&&active(item)&&AlchemistCatalog.readable(item,actor)&&(reachable(item.manifest,asset,{})||item.card.coverAssetId===asset.id&&!!store.cover(asset.id));});}
  return {canRead:canRead,validatePublication:function(item,actor,closure){closure.forEach(function(ref){var asset=store.asset(ref.logicalId,ref.revisionId);if(!asset||!asset.verified||(asset.owner!==actor.sub&&!canRead(asset,actor)))AlchemistCatalog.fail(403,'DEPENDENCY_PUBLISH_DENIED');if(asset.owner!==actor.sub){if(item.card.visibility==='public'&&!canRead(asset,null))AlchemistCatalog.fail(403,'PRIVATE_FOREIGN_DEPENDENCY');if(item.card.visibility==='restricted'&&item.readers.some(function(sub){return !canRead(asset,{sub:sub,roles:['client']});}))AlchemistCatalog.fail(403,'PRIVATE_FOREIGN_DEPENDENCY');}});}};
 }
 return {create:create};
})();
