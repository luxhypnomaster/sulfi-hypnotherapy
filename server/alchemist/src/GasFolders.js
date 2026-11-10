/* Owner-only bootstrap through Advanced Drive v3, with permission readback. */
var AlchemistGasFolders=(function(){
 'use strict';
 function bootstrap(actor){
  if(!actor||actor.roles.indexOf('owner')<0)AlchemistCatalog.fail(403,'OWNER_REQUIRED');
  var p=PropertiesService.getScriptProperties(),parent=p.getProperty('ALCHEMIST_PROJECT_FOLDER_ID'),email=p.getProperty('ALCHEMIST_OWNER_EMAIL');
  if(!parent||!email||actor.email!==email)AlchemistCatalog.fail(503,'OWNER_CONFIG_REQUIRED');
  function get(id){var f=Drive.Files.get(id,{fields:'id,name,mimeType,parents,owners(emailAddress),trashed'});if(f.trashed)throw Error('FOLDER_TRASHED');var permissions=[],page;
   do{var options={fields:'permissions(role,emailAddress,type),nextPageToken'};if(page)options.pageToken=page;var result=Drive.Permissions.list(id,options);permissions=permissions.concat(result.permissions||[]);page=result.nextPageToken;}while(page);
   return {id:f.id,name:f.name,mimeType:f.mimeType,parent:(f.parents||[])[0],owner:f.owners&&f.owners.length===1?f.owners[0].emailAddress:null,permissions:permissions.map(function(x){return {role:x.role,subject:x.emailAddress||x.type};})};
  }
  var drive={get:get,find:function(name,folder){var found=[],page;do{var q="'"+folder.replace(/'/g,"\\'")+"' in parents and name = '"+name.replace(/'/g,"\\'")+"' and trashed = false";var options={q:q,fields:'files(id),nextPageToken',pageSize:100};if(page)options.pageToken=page;var result=Drive.Files.list(options);found=found.concat((result.files||[]).map(function(x){return get(x.id);}));page=result.nextPageToken;}while(page);return found;},create:function(name,folder){var f=Drive.Files.create({name:name,mimeType:'application/vnd.google-apps.folder',parents:[folder]},null,{fields:'id'});return get(f.id);}};
  var registry={get:function(k){return p.getProperty('ALCHEMIST_FOLDER_'+k);},put:function(k,v){p.setProperty('ALCHEMIST_FOLDER_'+k,v);}};
  var lock=LockService.getScriptLock();if(!lock.tryLock(10000))AlchemistCatalog.fail(503,'BOOTSTRAP_BUSY');try{
   var result=AlchemistStorage.bootstrap(drive,registry,parent,email);
   p.setProperty('ALCHEMIST_REGISTRY_FOLDER_ID',result.folders['00_Система/registry']);p.setProperty('ALCHEMIST_BLOB_FOLDER_ID',result.folders['30_Медиа/immutable_blobs']);p.setProperty('ALCHEMIST_STORAGE_SCHEMA','1');
   // Folder IDs stay only in protected properties; public response is a receipt.
   return {schemaVersion:1,verifiedFolderCount:Object.keys(result.folders).length+1};
  }finally{lock.releaseLock();}
 }
 return {bootstrap:bootstrap};
})();
