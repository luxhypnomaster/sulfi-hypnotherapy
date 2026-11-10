/* GAS JSON broker: no undocumented request headers or binary ContentService. */
function alchemistCapabilities(){return {name:'Сервер Проекта Алхимик',schemaVersion:1,fullSourceReady:typeof AlchemistInitialConfig!=='undefined'&&AlchemistInitialConfig.fullSourceVerified===true,mediaTransferReady:typeof AlchemistInitialConfig!=='undefined'&&AlchemistInitialConfig.fullSourceVerified===true,liveVerified:false,chunkBytes:262144,media:['image/png','image/jpeg','image/webp','audio/mpeg','audio/mp4','audio/aac','audio/wav','audio/ogg','video/mp4','video/webm','video/quicktime','application/zip'],transfer:'authenticated-json-chunks',httpRangeOnWebApp:false};}
function doGet(e){var op=e&&e.parameter&&e.parameter.op;if(['health','capabilities','serverVersion'].indexOf(op)<0)return alchemistOutput({ok:false,status:405,error:{code:'USE_POST_ENVELOPE'}});return alchemistOutput({ok:true,status:200,result:alchemistCapabilities()});}
function doPost(e){
 var request,actor=null,operations=null;
 try{
  if(!e||!e.postData||e.postData.type.split(';')[0]!=='application/json'||e.postData.contents.length>500000)AlchemistCatalog.fail(422,'INVALID_ENVELOPE');
  request=JSON.parse(e.postData.contents);
  if(request.version!==1||typeof request.operation!=='string'||request.operation.length>80||! /^[a-zA-Z]+\.[a-zA-Z]+$/.test(request.operation)||!request.parameters||typeof request.parameters!=='object'||Array.isArray(request.parameters))AlchemistCatalog.fail(422,'INVALID_ENVELOPE');
  AlchemistRateLimit.checkIngress();
  if(request.operation==='system.initialize')return alchemistOutput({ok:true,status:200,result:AlchemistBootstrap.initialize(request.credential)});
  actor=request.credential?AlchemistJwt.verify(request.credential):null;
  AlchemistRateLimit.check(actor);
  if(request.operation==='storage.bootstrap')return alchemistOutput({ok:true,status:200,result:AlchemistGasFolders.bootstrap(actor)});
  var p=PropertiesService.getScriptProperties(),folder=p.getProperty('ALCHEMIST_REGISTRY_FOLDER_ID'),owner=p.getProperty('ALCHEMIST_OWNER_EMAIL');
  if(!folder||!owner)AlchemistCatalog.fail(503,'STORAGE_NOT_BOOTSTRAPPED');
  var io=AlchemistGasFiles.create(folder,owner),store=AlchemistAtomicStore.create(io);
  function scriptLock(fn){var l=LockService.getScriptLock();if(!l.tryLock(10000))AlchemistCatalog.fail(503,'BUSY');try{return fn();}finally{l.releaseLock();}}
  var access=AlchemistAccess.create(store,function(){return Date.now();});
  function canonical(v){if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(function(k){return JSON.stringify(k)+':'+canonical(v[k]);}).join(',')+'}';return JSON.stringify(v);}
  var services={lock:scriptLock,uuid:function(){return Utilities.getUuid();},now:function(){return new Date().toISOString();},canonical:canonical,digest:io.digest};
  var core=AlchemistCatalog.create({store:store,now:services.now,digest:function(v){return io.digest(JSON.stringify(v));},lock:scriptLock,encodeCursor:function(v){return Utilities.base64EncodeWebSafe(JSON.stringify(v));},decodeCursor:function(v){return JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(v)).getDataAsString('UTF-8'));},canReadAsset:access.canRead,validatePublication:access.validatePublication});
  operations=AlchemistOperations.create(store,core,services,p);
  function execute(){
   if(request.operation==='content.registerManifest')return AlchemistManifest.create(store,services,access).execute(request.operation,actor,request.parameters);
   if(request.operation==='feed.list'||request.operation.indexOf('entry.')===0||request.operation==='media.linkToEntry')return AlchemistDiary.create(core,store,services).execute(request.operation,actor,request.parameters);
   if(request.operation==='audio.list'||request.operation==='video.list'||request.operation==='image.list')return AlchemistLibrary.create(store,access,services).execute(request.operation,actor,request.parameters);
   if(request.operation.indexOf('media.')===0){
    var blobFolder=p.getProperty('ALCHEMIST_BLOB_FOLDER_ID');if(!blobFolder)AlchemistCatalog.fail(503,'STORAGE_NOT_BOOTSTRAPPED');
    var media=AlchemistMediaRuntime.create(store,AlchemistGasTransfer.create(blobFolder,owner),{lock:scriptLock,now:function(){return Date.now();},uuid:services.uuid,decode:function(s){return Utilities.base64Decode(s);},encode:function(b){return Utilities.base64Encode(b);},digest:function(b){return AlchemistSha256.create().update(b).hex();}});
    var method={'media.beginUpload':'begin','media.uploadChunk':'upload','media.commitUpload':'commit','media.abortUpload':'abort','media.downloadChunk':'download','media.getDescriptor':'descriptor','media.beginDownload':'descriptor','media.finalizeDownload':'finalize','media.metadata':'descriptor'}[request.operation];
    if(!method)AlchemistCatalog.fail(404,'UNKNOWN_OPERATION');return media[method](actor,request.parameters);
   }
   return request.operation.indexOf('catalog.')===0?core.execute(request.operation,actor,request.parameters):operations.execute(request.operation,actor,request.parameters);
  }
  var result=execute();
  if(request.parameters.requestId)operations.audit(actor,request.operation,200);
  return alchemistOutput({ok:true,status:200,result:result});
 }catch(error){
  var status=error.status||503,code=error.code||'SERVER_UNAVAILABLE';
  // No request body, token, subject, private title, path or Drive ID in logs.
  if(typeof console!=='undefined'&&console.warn)console.warn(JSON.stringify({event:'alchemist-request-denied',status:status,code:code}));
  if(operations){try{operations.audit(actor,request&&request.operation||'unknown',status);}catch(ignored){}}
  return alchemistOutput({ok:false,status:status,error:{code:code}});
 }
}
function alchemistOutput(value){value.requestId=Utilities.getUuid();value.serverTime=new Date().toISOString();return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON);}
