/* Actual Drive REST data plane. Owner OAuth stays inside GAS runtime only. */
var AlchemistGasTransfer=(function(){
 'use strict';
 function create(folderId,ownerEmail){
  function fail(code){AlchemistCatalog.fail(503,code);}
  function headers(extra){return Object.assign({Authorization:'Bearer '+ScriptApp.getOAuthToken()},extra||{});}
  function request(url,options){var r=UrlFetchApp.fetch(url,Object.assign({muteHttpExceptions:true,followRedirects:false,validateHttpsCertificates:true},options));if(r.getResponseCode()===429||r.getResponseCode()>=500)fail('DRIVE_RETRY_REQUIRED');return r;}
  function location(s){var url=s.privateLocation&&s.privateLocation.url;if(typeof url!=='string'||url.indexOf('https://www.googleapis.com/upload/drive/v3/files?')!==0)fail('INVALID_PRIVATE_SESSION');return url;}
  function fileId(s){var id=s.privateLocation&&s.privateLocation.fileId;if(typeof id!=='string'||!/^[\w-]+$/.test(id))fail('FILE_NOT_COMMITTED');return id;}
  function metadata(id){var m=Drive.Files.get(id,{fields:'id,size,mimeType,parents,trashed'});if(m.trashed||!m.parents||m.parents.length!==1||m.parents[0]!==folderId)fail('INVALID_MEDIA_PARENT');return m;}
  function read(s,offset,length){AlchemistGasFiles.privateFolder(folderId,ownerEmail);var id=fileId(s);metadata(id);var r=request('https://www.googleapis.com/drive/v3/files/'+encodeURIComponent(id)+'?alt=media',{method:'get',headers:headers({Range:'bytes='+offset+'-'+(offset+length-1)})});
   if(r.getResponseCode()!==206&&!(offset===0&&r.getResponseCode()===200))fail('DRIVE_RANGE_FAILED');var bytes=r.getBlob().getBytes();if(bytes.length!==length)fail('DRIVE_RANGE_SIZE');return bytes;}
  return {
   begin:function(q){AlchemistGasFiles.privateFolder(folderId,ownerEmail);var generated=Drive.Files.generateIds({count:1,space:'drive',fields:'ids'});if(!generated.ids||generated.ids.length!==1)fail('DRIVE_ID_ALLOCATION_FAILED');var allocatedId=generated.ids[0];var r=request('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',{method:'post',contentType:'application/json',headers:headers({'X-Upload-Content-Type':q.mime,'X-Upload-Content-Length':String(q.byteLength)}),payload:JSON.stringify({id:allocatedId,name:'asset-'+Utilities.getUuid(),mimeType:q.mime,parents:[folderId]})});
    if(r.getResponseCode()!==200)fail('DRIVE_BEGIN_FAILED');var h=r.getAllHeaders(),url=h.Location||h.location;var privateLocation={url:url,fileId:allocatedId};location({privateLocation:privateLocation});return privateLocation;},
   write:function(s,offset,bytes){AlchemistGasFiles.privateFolder(folderId,ownerEmail);if(s.privateLocation.fileId){try{var existing=metadata(s.privateLocation.fileId);if(Number(existing.size)===s.byteLength){if(existing.mimeType!==s.mime)fail('DRIVE_MIME_MISMATCH');return s.byteLength;}}catch(error){if(!/404|notFound|File not found/.test(String(error.message)))throw error;}}var r=request(location(s),{method:'put',contentType:s.mime,headers:headers({'Content-Range':'bytes '+offset+'-'+(offset+bytes.length-1)+'/'+s.byteLength}),payload:Utilities.newBlob(bytes.map(function(b){return b>127?b-256:b;})).getBytes()});
    if(r.getResponseCode()===308){var h=r.getAllHeaders(),range=h.Range||h.range,m=/^bytes=0-(\d+)$/.exec(range||'');if(!m)fail('DRIVE_OFFSET_UNKNOWN');return Number(m[1])+1;}
    if(r.getResponseCode()!==200&&r.getResponseCode()!==201)fail('DRIVE_WRITE_FAILED');var result=JSON.parse(r.getContentText());s.privateLocation.fileId=result.id;var meta=metadata(result.id);if(Number(meta.size)!==s.byteLength)fail('DRIVE_FINAL_SIZE');return s.byteLength;},
   read:read,
   chunkHash:function(s,offset,length){return AlchemistSha256.create().update(read(s,offset,length)).hex();},
   verify:function(s){var m=metadata(fileId(s));if(Number(m.size)!==s.byteLength||m.mimeType!==s.mime)fail('DRIVE_METADATA_MISMATCH');var checkpoint=s.verification||{offset:0,hash:null},h=AlchemistSha256.create(checkpoint.hash);
    var length=Math.min(262144,s.byteLength-checkpoint.offset);if(length>0){h.update(read(s,checkpoint.offset,length));checkpoint.offset+=length;checkpoint.hash=h.snapshot();s.verification=checkpoint;}
    if(checkpoint.offset<s.byteLength)return {pending:true,verifiedBytes:checkpoint.offset};return {sha256:h.hex(),byteLength:checkpoint.offset,privateFileId:fileId(s)};
   }
  };
 }
 return {create:create};
})();
