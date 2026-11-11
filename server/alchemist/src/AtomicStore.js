/* Immutable namespace shards + atomic private head. No destructive migration or
   media GC. API schema remains 1; this first production store uses schema 2. */
var AlchemistAtomicStore=(function(){
 'use strict';
 function create(io){
  var transaction=null,cache={},order=[];
  function clone(v){return JSON.parse(JSON.stringify(v));}
  function load(id){if(!Object.prototype.hasOwnProperty.call(cache,id)){cache[id]=JSON.stringify(io.read(id));order.push(id);if(order.length>32)delete cache[order.shift()];}return JSON.parse(cache[id]);}
  function root(){var id=io.head(),r=id?load(id):{schemaVersion:2,revision:0,catalogRevision:0,shards:{},ids:[],publicIds:[],owners:{},publishedOwners:{},readers:{}};if(r.schemaVersion!==2){var e=Error('UNSUPPORTED_STORAGE_SCHEMA');e.status=503;e.code='UNSUPPORTED_STORAGE_SCHEMA';throw e;}return r;}
  function current(){return transaction?transaction.root:root();}
  function namespace(key){return key.split(':')[0];}
  function shard(key){return namespace(key)+'-'+io.digest(key).slice(0,2);}
  function read(key){var r=current(),s=shard(key),map=transaction&&transaction.maps[s]||(r.shards[s]?load(r.shards[s]):{});return map[key]===undefined?null:clone(map[key]);}
  function put(key,value){if(!transaction)throw Error('TRANSACTION_REQUIRED');var s=shard(key);if(!transaction.maps[s])transaction.maps[s]=transaction.root.shards[s]?load(transaction.root.shards[s]):{};transaction.maps[s][key]=clone(value);}
  function scan(prefix){var r=current(),ns=namespace(prefix)+'-',keys=Object.keys(r.shards);if(transaction)keys=keys.concat(Object.keys(transaction.maps));var result={},seen={};keys.forEach(function(s){if(seen[s]||s.indexOf(ns)!==0)return;seen[s]=true;var map=transaction&&transaction.maps[s]||load(r.shards[s]);Object.keys(map).filter(function(k){return k.indexOf(prefix)===0;}).forEach(function(k){result[k]=clone(map[k]);});});return Object.keys(result).map(function(k){return result[k];});}
  function sorted(ids){return ids.sort(function(a,b){var aa=shard('card:'+a),bb=shard('card:'+b);return aa.localeCompare(bb)||a.localeCompare(b);});}
  function replace(ids,id,present){var next=(ids||[]).filter(function(v){return v!==id;});if(present)next.push(id);return sorted(next);}
  function indexed(map,key,id,present){var list=Object.prototype.hasOwnProperty.call(map,key)?map[key]:[];Object.defineProperty(map,key,{value:replace(list,id,present),enumerable:true,writable:true,configurable:true});}
  function abbreviated(r){if(!r)return null;var c=clone(r.card||{});delete c.description;delete c.releaseNotes;return {id:r.id,owner:r.owner,type:r.type,logicalContentId:r.logicalContentId,contentRevision:r.contentRevision,metadataRevision:r.metadataRevision,etag:r.etag,state:r.state,card:c,readers:clone(r.readers||[]),manifest:{dependencyRefs:clone((r.manifest||{}).dependencyRefs||[]),publication:clone((r.manifest||{}).publication||null)},summary:r.summary||null,updatedAt:r.updatedAt,publishedRecord:r.publishedRecord?abbreviated(r.publishedRecord):null,wasPublic:r.wasPublic===true};}
  function closure(record){var found={},seen={};function visit(ref){var key=ref.logicalId+':'+ref.revisionId;if(seen[key])return;seen[key]=true;var a=read('asset:'+key);if(!a||!a.verified||a.sha256!==ref.sha256)throw Error('UNVERIFIED_GRANT_REFERENCE');if(a.owner===record.owner)found[key]=a;(a.dependencyRefs||[]).forEach(visit);}if(record){var refs=record.type==='diaryEntry'?((record.manifest.entry||{}).blocks||[]).filter(function(b){return ['image','audio','video'].indexOf(b.type)>=0&&b.mediaRef;}).map(function(b){return b.mediaRef;}):record.manifest.dependencyRefs||[];refs.forEach(visit);if(record.card.coverAssetId){var cover=read('cover:'+record.card.coverAssetId);if(!cover||!cover.verified||cover.owner!==record.owner)throw Error('UNVERIFIED_COVER_GRANT');visit({logicalId:cover.logicalId,revisionId:cover.revisionId,sha256:cover.sha256});}}return found;}
  function grants(before,after,id){var old=closure(before),next=closure(after),keys={};Object.keys(old).concat(Object.keys(next)).forEach(function(k){keys[k]=true;});Object.keys(keys).forEach(function(k){var key='asset-grants:'+k,list=(read(key)||[]).filter(function(g){return g.publicationId!==id;});if(next[k])list.push({publicationId:id,grantPolicyVersion:2,publicationType:after.type,owner:after.owner,visibility:after.card.visibility,readers:clone(after.readers||[]),publication:clone(after.manifest.publication||null)});put(key,list);});}
  function commit(r){var revisionKey='catalog-revision:'+r.id+':'+r.etag,prior=read(revisionKey);if(prior&&JSON.stringify(prior)!==JSON.stringify(r))throw Error('IMMUTABLE_REVISION_CONFLICT');
   var before=read('item:'+r.id),oldPublic=before&&before.publishedRecord,newPublic=r.publishedRecord||null;
   if(JSON.stringify(oldPublic||null)!==JSON.stringify(newPublic))grants(oldPublic,newPublic,r.id);
   put(revisionKey,r);put('item:'+r.id,r);put('card:'+r.id,abbreviated(r));var h=transaction.root;
   h.ids=replace(h.ids,r.id,true);h.publicIds=replace(h.publicIds,r.id,!!newPublic&&newPublic.card.visibility==='public');
   indexed(h.owners,r.owner,r.id,true);indexed(h.publishedOwners,r.owner,r.id,!!newPublic);
   var subjects={};((oldPublic||{}).readers||[]).concat((newPublic||{}).readers||[]).forEach(function(s){subjects[s]=true;});Object.keys(subjects).forEach(function(s){indexed(h.readers,s,r.id,!!newPublic&&newPublic.card.visibility==='restricted'&&newPublic.readers.indexOf(s)>=0);});
   transaction.catalogChanged=true;
  }
  return {
   begin:function(){if(transaction)throw Error('NESTED_TRANSACTION');transaction={root:root(),maps:{}};},rollback:function(){transaction=null;},
   commitTransaction:function(){if(!transaction)throw Error('NO_TRANSACTION');try{var r=transaction.root;Object.keys(transaction.maps).forEach(function(s){r.shards[s]=io.writeVerified(transaction.maps[s]);});r.revision++;if(transaction.catalogChanged)r.catalogRevision++;var next=io.writeVerified(r);io.setHead(next);}finally{transaction=null;}},
   get:read,put:put,scan:scan,item:function(id){return read('item:'+id);},receipt:function(key){return read('receipt:'+key);},saveReceipt:function(key,v){put('receipt:'+key,v);},commit:commit,revision:function(id,etag){return read('catalog-revision:'+id+':'+etag);},
   asset:function(id,revision){return read('asset:'+id+':'+revision);},cover:function(id){return read('cover:'+id);},retainAsset:function(id,revision,value){put('asset:'+id+':'+revision,value);},
   assetGrants:function(id,revision){return read('asset-grants:'+id+':'+revision)||[];},
   indexRevision:function(){return current().catalogRevision||0;},sequence:function(){return current().revision;},items:function(){return scan('card:');},
   card:function(id){return read('card:'+id);},candidates:function(actor,q){var h=current(),sub=(actor||{}).sub;
    function own(map){return sub&&Object.prototype.hasOwnProperty.call(map,sub)?map[sub]:[];}
    if(q.ownedOnly===true)return own(h.owners).slice();
    var candidates=h.publicIds.concat(own(h.readers),own(q.readerView===true?h.publishedOwners:h.owners)),seen={};return sorted(candidates.filter(function(id){if(seen[id])return false;seen[id]=true;return true;}));
   }
  };
 }
 return {create:create};
})();
