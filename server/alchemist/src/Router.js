/* Real GAS JSON control-plane binding. Missing configuration fails closed. */
function doGet(e){
 var op=e&&e.parameter&&e.parameter.op;
 if(op!=='health'&&op!=='capabilities')return alchemistOutput({ok:false,status:405,error:{code:'USE_POST_ENVELOPE'}});
 return alchemistOutput({ok:true,status:200,result:{name:'Сервер Проекта Алхимик',schemaVersion:1,fullSourceReady:false,mediaTransferReady:false,liveVerified:false}});
}
function doPost(e){
 var request;
 try{
  if(!e||!e.postData||e.postData.type.split(';')[0]!=='application/json'||e.postData.contents.length>500000)AlchemistCatalog.fail(422,'INVALID_ENVELOPE');
  request=JSON.parse(e.postData.contents);
  if(request.version!==1||typeof request.operation!=='string'||!request.parameters||typeof request.parameters!=='object')AlchemistCatalog.fail(422,'INVALID_ENVELOPE');
  var actor=request.credential?AlchemistJwt.verify(request.credential):null;
  if(request.operation==='storage.bootstrap')return alchemistOutput({ok:true,status:200,result:AlchemistGasFolders.bootstrap(actor)});
  var properties=PropertiesService.getScriptProperties();
  var folder=properties.getProperty('ALCHEMIST_REGISTRY_FOLDER_ID'),owner=properties.getProperty('ALCHEMIST_OWNER_EMAIL');
  if(!folder||!owner)AlchemistCatalog.fail(503,'STORAGE_NOT_BOOTSTRAPPED');
  var io=AlchemistGasFiles.create(folder,owner),store=AlchemistAtomicStore.create(io);
  function scriptLock(fn){var l=LockService.getScriptLock();if(!l.tryLock(10000))AlchemistCatalog.fail(503,'BUSY');try{return fn();}finally{l.releaseLock();}}
  var access=AlchemistAccess.create(store,function(){return Date.now();});
  if(request.operation.indexOf('media.')===0){
    var blobFolder=properties.getProperty('ALCHEMIST_BLOB_FOLDER_ID');if(!blobFolder)AlchemistCatalog.fail(503,'STORAGE_NOT_BOOTSTRAPPED');
    var media=AlchemistMediaRuntime.create(store,AlchemistGasTransfer.create(blobFolder,owner),{lock:scriptLock,now:function(){return Date.now();},uuid:function(){return Utilities.getUuid();},decode:function(s){return Utilities.base64Decode(s);},encode:function(b){return Utilities.base64Encode(b);},digest:function(b){return AlchemistSha256.create().update(b).hex();}});
    var method={'media.beginUpload':'begin','media.uploadChunk':'upload','media.commitUpload':'commit','media.abortUpload':'abort','media.downloadChunk':'download','media.getDescriptor':'descriptor','media.beginDownload':'descriptor','media.finalizeDownload':'finalize'}[request.operation];
    if(!method)AlchemistCatalog.fail(404,'UNKNOWN_OPERATION');return alchemistOutput({ok:true,status:200,result:media[method](actor,request.parameters)});
  }
  var core=AlchemistCatalog.create({store:store,now:function(){return new Date().toISOString();},digest:function(v){return io.digest(JSON.stringify(v));},
   lock:function(fn){var l=LockService.getScriptLock();if(!l.tryLock(10000))AlchemistCatalog.fail(503,'BUSY');try{return fn();}finally{l.releaseLock();}},
   encodeCursor:function(v){return Utilities.base64EncodeWebSafe(JSON.stringify(v));},decodeCursor:function(v){return JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(v)).getDataAsString('UTF-8'));},
   canReadAsset:access.canRead,
   validatePublication:access.validatePublication
  });
  return alchemistOutput({ok:true,status:200,result:core.execute(request.operation,actor,request.parameters)});
 }catch(error){return alchemistOutput({ok:false,status:error.status||503,error:{code:error.code||'SERVER_UNAVAILABLE'}});}
}
function alchemistOutput(value){return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON);}
