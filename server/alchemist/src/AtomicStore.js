/* Immutable index shards + one atomic private root pointer. No media GC. */
var AlchemistAtomicStore=(function(){
 'use strict';
 function create(io){
  var transaction=null;
  function root(){return io.head()?io.read(io.head()):{schemaVersion:1,revision:0,shards:{}};}
  function shard(key){return io.digest(key).slice(0,2);}
  function read(key){var r=transaction?transaction.root:root(),s=shard(key);var map=transaction&&transaction.maps[s]|| (r.shards[s]?io.read(r.shards[s]):{});return map[key]===undefined?null:JSON.parse(JSON.stringify(map[key]));}
  function put(key,value){if(!transaction)throw new Error('TRANSACTION_REQUIRED');var s=shard(key);if(!transaction.maps[s])transaction.maps[s]=transaction.root.shards[s]?io.read(transaction.root.shards[s]):{};transaction.maps[s][key]=JSON.parse(JSON.stringify(value));}
  return {
   begin:function(){if(transaction)throw new Error('NESTED_TRANSACTION');transaction={root:root(),maps:{}};},
   rollback:function(){transaction=null;},
   commitTransaction:function(){if(!transaction)throw new Error('NO_TRANSACTION');try{var r=transaction.root;Object.keys(transaction.maps).forEach(function(s){r.shards[s]=io.writeVerified(transaction.maps[s]);});r.revision++;if(transaction.catalogChanged)r.catalogRevision=(r.catalogRevision||0)+1;var next=io.writeVerified(r);io.setHead(next);}finally{transaction=null;}},
   get:read,put:put,
   item:function(id){return read('item:'+id);},receipt:function(key){return read('receipt:'+key);},
   saveReceipt:function(key,v){put('receipt:'+key,v);},commit:function(r){put('item:'+r.id,r);transaction.catalogChanged=true;},
   asset:function(id,revision){return read('asset:'+id+':'+revision);},cover:function(id){return read('cover:'+id);},
   retainAsset:function(id,revision,value){put('asset:'+id+':'+revision,value);},
   indexRevision:function(){return (transaction?transaction.root:root()).catalogRevision||0;},
   items:function(){var r=transaction?transaction.root:root(),result=[];Object.keys(r.shards).forEach(function(s){var map=transaction&&transaction.maps[s]||io.read(r.shards[s]);Object.keys(map).filter(function(k){return k.indexOf('item:')===0;}).forEach(function(k){result.push(map[k]);});});return result;}
  };
 }
 return {create:create};
})();
