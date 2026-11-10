/* Auth administration, bounded audit and per-subject synchronization. */
var AlchemistOperations=(function(){
 'use strict';
 function create(store,core,services,properties){
  function authenticated(a){if(!a||!a.sub)AlchemistCatalog.fail(401,'IDENTITY_REQUIRED');}
  function owner(a){authenticated(a);if(a.roles.indexOf('owner')<0)AlchemistCatalog.fail(403,'OWNER_REQUIRED');}
  function tx(fn){return services.lock(function(){store.begin();try{var r=fn();store.commitTransaction();return r;}catch(e){store.rollback();throw e;}});}
  function subject(v){if(typeof v!=='string'||! /^[a-zA-Z0-9_-]{1,256}$/.test(v)||['constructor','prototype','__proto__'].indexOf(v)>=0)AlchemistCatalog.fail(422,'INVALID_SUBJECT');return v;}
  function request(v){if(typeof v!=='string'||! /^[\w-]{1,128}$/.test(v))AlchemistCatalog.fail(422,'INVALID_REQUEST_ID');return v;}
  function audit(actor,operation,status){return tx(function(){var events=store.get('audit:recent')||{sequence:0,events:[]};events.sequence++;events.events.push({sequence:events.sequence,at:services.now(),subjectDigest:services.digest((actor||{}).sub||'anonymous'),operation:operation,status:status});if(events.events.length>500)events.events.shift();store.put('audit:recent',events);return true;});}
  return {audit:audit,execute:function(op,a,q){q=q||{};
   if(op==='auth.whoami'||op==='auth.roles'){authenticated(a);return {subject:a.sub,roles:a.roles.slice(),expiresAt:a.exp||null};}
   if(op==='grant.list'){owner(a);return {grants:JSON.parse(properties.getProperty('ALCHEMIST_GRANTS')||'{}')};}
   if(op==='grant.set'||op==='grant.revoke'||op==='auth.revoke'){owner(a);subject(q.subject);request(q.requestId);if(q.subject===properties.getProperty('ALCHEMIST_OWNER_SUB'))AlchemistCatalog.fail(409,'OWNER_GRANT_IMMUTABLE');return services.lock(function(){var grants=JSON.parse(properties.getProperty('ALCHEMIST_GRANTS')||'{}'),revoked=JSON.parse(properties.getProperty('ALCHEMIST_REVOKED_SUBJECTS')||'{}');if(op==='grant.set'){if(!Array.isArray(q.roles)||!q.roles.length||q.roles.length>3||q.roles.some(function(r){return ['author','client','subscriber'].indexOf(r)<0;}))AlchemistCatalog.fail(422,'INVALID_GRANT');grants[q.subject]=q.roles;delete revoked[q.subject];}else{delete grants[q.subject];revoked[q.subject]=true;}var encoded=JSON.stringify(grants),denials=JSON.stringify(revoked);if(encoded.length>8000||denials.length>8000)AlchemistCatalog.fail(507,'GRANT_REGISTRY_FULL');properties.setProperty('ALCHEMIST_GRANTS',encoded);properties.setProperty('ALCHEMIST_REVOKED_SUBJECTS',denials);return {subject:q.subject,revoked:op!=='grant.set'};});}
   if(op==='audit.list'){owner(a);var log=store.get('audit:recent')||{sequence:0,events:[]};var after=q.after||0;if(!Number.isSafeInteger(after)||after<0)AlchemistCatalog.fail(422,'INVALID_CURSOR');return {events:log.events.filter(function(e){return e.sequence>after;}).slice(0,100),sequence:log.sequence,oldestRetained:log.events.length?log.events[0].sequence:null};}
   if(op==='snapshot.get'||op==='sync.pull'||op==='events.list'){var result=core.execute('catalog.changes',a,q);if(a){result.readerState=store.get('reader:'+a.sub)||{etag:'0',entries:[]};}return result;}
   if(op==='sync.push'||op==='conflict.resolve'){authenticated(a);request(q.requestId);if(!Array.isArray(q.entries)||q.entries.length>100)AlchemistCatalog.fail(422,'INVALID_READER_STATE');return tx(function(){var old=store.get('reader:'+a.sub)||{etag:'0',entries:[]},digest=services.digest(JSON.stringify(q)),key='reader:'+a.sub+':'+q.requestId,receipt=store.receipt(key);if(receipt){if(receipt.digest!==digest)AlchemistCatalog.fail(409,'IDEMPOTENCY_CONFLICT');return receipt.result;}if(q.ifMatch!==old.etag)AlchemistCatalog.fail(412,'READER_STATE_CONFLICT');var entries=q.entries.map(function(e){if(!e||typeof e.entryId!=='string'||e.entryId.length>128||typeof e.cycle!=='string'||e.cycle.length>128||typeof e.fingerprint!=='string'||e.fingerprint.length>128||typeof e.read!=='boolean'||!Number.isSafeInteger(e.page)||e.page<0)AlchemistCatalog.fail(422,'INVALID_READER_STATE');return {entryId:e.entryId,cycle:e.cycle,fingerprint:e.fingerprint,read:e.read,page:e.page};});var state={etag:String(Number(old.etag)+1),entries:entries};store.put('reader:'+a.sub,state);store.saveReceipt(key,{digest:digest,result:state});return state;});}
   if(op==='outbox.status'){authenticated(a);if(!Array.isArray(q.requestIds)||q.requestIds.length>100)AlchemistCatalog.fail(422,'INVALID_REQUESTS');return {receipts:q.requestIds.map(function(id){request(id);return {requestId:id,committed:!!store.receipt(a.sub+':'+id)};})};}
   if(op==='library.versionCheck')return core.execute('catalog.checkUpdates',a,q);
   var list={'audio.list':'track','template.list':'template','module.list':'module','session.list':'session','package.list':'package'}[op];
   if(list)return core.execute('catalog.list',a,Object.assign({},q,{type:list}));
   if(op==='package.getManifest'){var card=core.execute('catalog.get',a,q);if(card.type!=='package')AlchemistCatalog.fail(422,'NOT_PACKAGE');return {catalogItemId:card.catalogItemId,immutableRevisionId:card.immutableRevisionId,manifest:card.manifest};}
   if(op==='package.publish'||op==='package.revoke'){var record=core.execute('catalog.get',a,q);if(record.type!=='package')AlchemistCatalog.fail(422,'NOT_PACKAGE');return core.execute(op==='package.publish'?'catalog.publish':'catalog.withdraw',a,q);}
   AlchemistCatalog.fail(404,'UNKNOWN_OPERATION');
  }};
 }
 return {create:create};
})();
