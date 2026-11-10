/* Bounded execution budget. GAS exposes no trusted client IP; anonymous readers
   deliberately share a budget. It is not a claim of CDN/DoS protection. */
var AlchemistRateLimit=(function(){
 function check(actor){var key='alchemist-rate:'+AlchemistSha256.create().update(Utilities.newBlob(actor&&actor.sub||'anonymous').getBytes()).hex().slice(0,32),cache=CacheService.getScriptCache(),lock=LockService.getScriptLock();if(!lock.tryLock(1000))AlchemistCatalog.fail(503,'BUSY');try{var now=Date.now(),state=JSON.parse(cache.get(key)||'null');if(!state||state.until<=now)state={count:0,until:now+60000};var limit=actor&&actor.roles.indexOf('owner')>=0?600:300;if(state.count>=limit)AlchemistCatalog.fail(429,'REQUEST_BUDGET_EXCEEDED');state.count++;cache.put(key,JSON.stringify(state),60);}finally{lock.releaseLock();}}
 return {check:check,checkIngress:function(){return check({sub:'internal-ingress-budget',roles:['owner']});}};
})();
