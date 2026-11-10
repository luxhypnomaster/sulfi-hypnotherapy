/* Safe metadata gallery; Drive locators and upload sessions are never projected. */
var AlchemistLibrary=(function(){
 function create(store,access,services){return {execute:function(op,actor,q){
  var kind={'audio.list':'audio/','image.list':'image/','video.list':'video/'}[op];if(!kind)AlchemistCatalog.fail(404,'UNKNOWN_LIBRARY_OPERATION');
  var offset=q.offset||0,limit=q.limit||25;if(!Number.isSafeInteger(offset)||offset<0||!Number.isSafeInteger(limit)||limit<1||limit>50)AlchemistCatalog.fail(422,'INVALID_PAGE');
  var revision=store.sequence();if(q.snapshotRevision!==undefined&&q.snapshotRevision!==revision)AlchemistCatalog.fail(409,'SNAPSHOT_CHANGED');
  var unique={},items=store.scan('media:').filter(function(a){if(!a.verified||a.mime.indexOf(kind)!==0||!access.canRead(a,actor)||unique[a.logicalId+':'+a.revisionId])return false;unique[a.logicalId+':'+a.revisionId]=true;return true;}).sort(function(a,b){return a.id.localeCompare(b.id);});
  return {items:items.slice(offset,offset+limit).map(function(a){return {assetRevisionId:a.id,logicalId:a.logicalId,revisionId:a.revisionId,sha256:a.sha256,mime:a.mime,byteLength:a.byteLength};}),revision:revision,nextOffset:offset+limit<items.length?offset+limit:null};
 }};}
 return {create:create};
})();
