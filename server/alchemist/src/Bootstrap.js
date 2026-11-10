/* No public setup password. CI's Google-signed ID token must match the configured
   owner subject/email AND its exact OAuth audience. Config contains no tokens. */
var AlchemistBootstrap=(function(){
 function initialize(credential){
  if(typeof AlchemistInitialConfig==='undefined'||AlchemistInitialConfig.fullSourceVerified!==true)AlchemistCatalog.fail(503,'BUILD_NOT_READY');
  var c=AlchemistInitialConfig;
  if(!c.ownerSubject||!c.ownerEmail||!c.ciAudience||!c.projectFolderId)AlchemistCatalog.fail(503,'BOOTSTRAP_CONFIG_MISSING');
  var actor=AlchemistJwt.verify(credential,{audience:c.ciAudience,ownerSubject:c.ownerSubject});
  if(actor.roles.indexOf('owner')<0||actor.email!==c.ownerEmail)AlchemistCatalog.fail(403,'OWNER_REQUIRED');
  var p=PropertiesService.getScriptProperties(),lock=LockService.getScriptLock();
  if(!lock.tryLock(10000))AlchemistCatalog.fail(503,'BUSY');
  try{
   var owner=p.getProperty('ALCHEMIST_OWNER_SUB'),email=p.getProperty('ALCHEMIST_OWNER_EMAIL');
   if(owner&&owner!==c.ownerSubject||email&&email!==c.ownerEmail)AlchemistCatalog.fail(409,'OWNER_CONFIG_IMMUTABLE');
   var audiences=[c.ciAudience];if(c.androidWebAudience)audiences.push(c.androidWebAudience);
   p.setProperties({ALCHEMIST_OWNER_SUB:c.ownerSubject,ALCHEMIST_OWNER_EMAIL:c.ownerEmail,
     ALCHEMIST_PROJECT_FOLDER_ID:c.projectFolderId,ALCHEMIST_GOOGLE_AUDIENCES:JSON.stringify(audiences),ALCHEMIST_SOURCE_SHA:c.sourceSha});
   if(p.getProperty('ALCHEMIST_OWNER_SUB')!==c.ownerSubject||p.getProperty('ALCHEMIST_GOOGLE_AUDIENCES')!==JSON.stringify(audiences))AlchemistCatalog.fail(503,'CONFIG_READBACK_FAILED');
  }finally{lock.releaseLock();}
  AlchemistGasFiles.privateFile(ScriptApp.getScriptId(),c.ownerEmail);
  return AlchemistGasFolders.bootstrap(actor);
 }
 return {initialize:initialize};
})();
