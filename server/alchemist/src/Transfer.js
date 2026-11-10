/* Chunked data-plane orchestration; no Drive credentials or URLs leave adapter. */
var AlchemistTransfer=(function(){
 'use strict';
 function create(env){
  function fail(s,c){AlchemistCatalog.fail(s,c);}
  function owner(a){if(!a||!a.roles||a.roles.indexOf('author')<0&&a.roles.indexOf('owner')<0)fail(403,'AUTHOR_REQUIRED');}
  function session(id,a){var s=env.sessions.get(id);if(!s||s.owner!==(a||{}).sub)fail(404,'TRANSFER_NOT_AVAILABLE');if(s.expiresAt<=env.now())fail(410,'TRANSFER_EXPIRED');return s;}
  return {
   begin:function(a,q){owner(a);if(!q||typeof q.requestId!=='string'||! /^[a-zA-Z0-9_-]{1,128}$/.test(q.requestId)||!Number.isSafeInteger(q.byteLength)||q.byteLength<1||!/^[a-f0-9]{64}$/.test(q.sha256)||typeof q.mime!=='string'||! /^(audio\/(mpeg|mp4|aac|wav|ogg)|video\/(mp4|webm|quicktime)|image\/(png|jpeg|webp)|application\/zip)$/.test(q.mime))fail(422,'INVALID_DESCRIPTOR');
    if(q.logicalId&&!/^[a-zA-Z0-9_-]{1,128}$/.test(q.logicalId)||q.revisionId&&!/^[a-zA-Z0-9_-]{1,128}$/.test(q.revisionId))fail(422,'INVALID_ASSET_ID');
    return env.lock(function(){var existing=env.sessions.byRequest(a.sub,q.requestId);if(existing){if(existing.sha256!==q.sha256||existing.byteLength!==q.byteLength||existing.mime!==q.mime||existing.logicalId!==(q.logicalId||null)||existing.revisionId!==(q.revisionId||null))fail(409,'TRANSFER_RETRY_CONFLICT');return {sessionId:existing.id,offset:existing.offset,chunkBytes:existing.chunkBytes};}
     var s={id:env.uuid(),owner:a.sub,requestId:q.requestId,sha256:q.sha256,byteLength:q.byteLength,mime:q.mime,logicalId:q.logicalId||null,revisionId:q.revisionId||null,offset:0,chunkBytes:256*1024,expiresAt:env.now()+86400000,state:'uploading',privateLocation:env.drive.begin(q)};env.sessions.put(s);return {sessionId:s.id,offset:0,chunkBytes:s.chunkBytes};});},
   upload:function(a,q){owner(a);return env.lock(function(){var s=session(q.sessionId,a);if(s.state!=='uploading')fail(409,'NOT_UPLOADING');var bytes=env.decode(q.base64);if(!bytes.length||bytes.length>s.chunkBytes||q.offset<0||!Number.isSafeInteger(q.offset)||q.offset+bytes.length>s.byteLength)fail(422,'INVALID_CHUNK');
     if(q.offset<s.offset){var received=env.chunks.get(s.id,q.offset);if(!received||received.length!==bytes.length||received.sha256!==env.digest(bytes))fail(409,'CHUNK_RETRY_MISMATCH');return {offset:s.offset};}
     if(q.offset!==s.offset)fail(409,'OFFSET_CONFLICT');if(q.offset+bytes.length<s.byteLength&&bytes.length%262144!==0)fail(422,'CHUNK_ALIGNMENT');
     // Adapter reconcile handles crash after Drive acceptance before local offset.
     var accepted=env.drive.write(s,q.offset,bytes);if(accepted!==q.offset+bytes.length)fail(503,'DRIVE_OFFSET_MISMATCH');env.chunks.put(s.id,q.offset,{length:bytes.length,sha256:env.digest(bytes)});s.offset=accepted;env.sessions.put(s);return {offset:s.offset};});},
   commit:function(a,q){owner(a);return env.lock(function(){var s=session(q.sessionId,a);if(s.state==='committed')return {assetRevisionId:s.assetRevisionId,logicalId:s.logicalId||s.id,revisionId:s.revisionId||s.sha256,sha256:s.sha256,byteLength:s.byteLength};if(s.offset!==s.byteLength)fail(409,'INCOMPLETE_UPLOAD');
     // Verification is a real adapter operation; opaque upload receipt is insufficient.
     var verified=env.drive.verify(s);if(verified.pending===true){env.sessions.put(s);return {state:'verifying',verifiedBytes:verified.verifiedBytes,byteLength:s.byteLength};}if(verified.byteLength!==s.byteLength||verified.sha256!==s.sha256)fail(422,'BYTE_VERIFICATION_FAILED');s.assetRevisionId=env.assets.retain(s,verified);s.state='committed';env.sessions.put(s);return {assetRevisionId:s.assetRevisionId,logicalId:s.logicalId||s.id,revisionId:s.revisionId||s.sha256,sha256:s.sha256,byteLength:s.byteLength};});},
   descriptor:function(a,q){var asset=env.assets.get(q.assetRevisionId);if(!asset||!env.assets.canRead(asset,a))fail(404,'ASSET_NOT_AVAILABLE');return {assetRevisionId:asset.id,logicalId:asset.logicalId,revisionId:asset.revisionId,sha256:asset.sha256,byteLength:asset.byteLength,mime:asset.mime};},
   finalize:function(a,q){var asset=env.assets.get(q.assetRevisionId);if(!asset||!env.assets.canRead(asset,a))fail(404,'ASSET_NOT_AVAILABLE');if(q.sha256!==asset.sha256||q.byteLength!==asset.byteLength)fail(422,'DOWNLOAD_VERIFY_FAILED');return {verified:true,assetRevisionId:asset.id};},
   download:function(a,q){var asset=env.assets.get(q.assetRevisionId);if(!asset||!env.assets.canRead(asset,a))fail(404,'ASSET_NOT_AVAILABLE');
    if(!Number.isSafeInteger(q.offset)||q.offset<0||q.offset>=asset.byteLength||!Number.isSafeInteger(q.length)||q.length<1||q.length>262144)fail(422,'INVALID_RANGE');
    var bytes=env.drive.read(asset,q.offset,Math.min(q.length,asset.byteLength-q.offset));if(bytes.length!==Math.min(q.length,asset.byteLength-q.offset))fail(503,'SHORT_READ');
    return {offset:q.offset,byteLength:asset.byteLength,base64:env.encode(bytes),chunkSha256:env.digest(bytes),sha256:asset.sha256};},
   abort:function(a,q){owner(a);return env.lock(function(){var s=session(q.sessionId,a);if(s.state==='committed')fail(409,'COMMITTED_ASSET_RETAINED');s.state='aborted';env.sessions.put(s);return {state:s.state};});}
  };
 }
 return {create:create};
})();
