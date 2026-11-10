/* GAS-only private file adapter. Not executed by CI; live readback required. */
var AlchemistGasFiles=(function(){
 'use strict';
 function privateFolder(folderId,ownerEmail){
  var f=Drive.Files.get(folderId,{fields:'id,mimeType,parents,owners(emailAddress),trashed'});
  if(f.trashed||f.mimeType!=='application/vnd.google-apps.folder'||!f.owners||f.owners.length!==1||f.owners[0].emailAddress!==ownerEmail)throw Error('UNSAFE_FOLDER_OWNER');
  var page,permissions=[];do{var p=Drive.Permissions.list(folderId,{fields:'permissions(type,role,emailAddress),nextPageToken',pageToken:page});permissions=permissions.concat(p.permissions||[]);page=p.nextPageToken;}while(page);
  if(permissions.length!==1||permissions[0].role!=='owner'||permissions[0].emailAddress!==ownerEmail)throw Error('UNSAFE_FOLDER_ACL');
  return f;
 }
 function create(folderId,ownerEmail){
  privateFolder(folderId,ownerEmail);
  var props=PropertiesService.getScriptProperties(),name='ALCHEMIST_CATALOG_HEAD';
  function sha(s){return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256,s,Utilities.Charset.UTF_8).map(function(b){return ('0'+(b&255).toString(16)).slice(-2);}).join('');}
  function read(id){var f=Drive.Files.get(id,{fields:'id,parents,mimeType,trashed'});if(f.trashed||!f.parents||f.parents.length!==1||f.parents[0]!==folderId||f.mimeType!=='application/json')throw Error('INVALID_INDEX_REFERENCE');return JSON.parse(DriveApp.getFileById(id).getBlob().getDataAsString('UTF-8'));}
  return {digest:sha,head:function(){return props.getProperty(name);},read:read,
   writeVerified:function(value){privateFolder(folderId,ownerEmail);var serialized=JSON.stringify(value);var file=DriveApp.getFolderById(folderId).createFile('snapshot-'+Utilities.getUuid()+'.json',serialized,'application/json');var back=read(file.getId());if(sha(JSON.stringify(back))!==sha(serialized))throw Error('INDEX_READBACK_MISMATCH');return file.getId();},
   setHead:function(id){privateFolder(folderId,ownerEmail);read(id);props.setProperty(name,id);if(props.getProperty(name)!==id)throw Error('HEAD_READBACK_MISMATCH');}
  };
 }
 return {create:create,privateFolder:privateFolder};
})();
