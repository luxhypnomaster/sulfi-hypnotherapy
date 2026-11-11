/* Explicit phone-side permission smoke. Only verified Web identities can enter
 * through Router. Proofs are private; status never exposes subjects or emails. */
var AlchemistPilotAuthorization=(function(){
 'use strict';
 function verify(actor,q,core,services,properties){
  if(!actor||!actor.sub)AlchemistCatalog.fail(401,'IDENTITY_REQUIRED');
  if(!q||typeof q.requestId!=='string'||! /^[\w-]{1,80}$/.test(q.requestId))AlchemistCatalog.fail(422,'INVALID_REQUEST_ID');
  var master=actor.sub===properties.getProperty('ALCHEMIST_OWNER_SUB');
  var web=properties.getProperty('ALCHEMIST_GOOGLE_WEB_CLIENT_ID');
  if(!web||actor.aud!==web)AlchemistCatalog.fail(401,'WEB_AUDIENCE_REQUIRED');
  var role=master?'MASTER':'CLIENT',tag='authcheck_'+services.digest(actor.sub).slice(0,16)+'_'+q.requestId;
  // Restricted text-only control entry: no personal files or public diary
  // entry, no visible pilot content. Real create/publish/withdraw operations.
  var payload={catalogItemId:tag,type:'diaryEntry',logicalContentId:tag,immutableRevisionId:'1',requestId:tag+'_create',card:{title:'Проверка авторизации №16-А',shortAnnotation:'Закрытый технический контроль прав',visibility:'restricted'},manifest:{dependencyRefs:[],entry:{id:tag,title:'Проверка авторизации №16-А',message:'Закрытый технический контроль',createdAt:'2026-11-11T00:00:00.000Z',blocks:[{id:'control-text',type:'text',text:'Закрытый технический контроль авторизации №16-А'}]}}};
  if(master){
   var created=core.execute('catalog.createDraft',actor,payload);
   var published=core.execute('catalog.publish',actor,{catalogItemId:tag,requestId:tag+'_publish',ifMatch:created.etag});
   core.execute('catalog.withdraw',actor,{catalogItemId:tag,requestId:tag+'_withdraw',ifMatch:published.etag});
  }else{
   var denied=false;try{core.execute('catalog.createDraft',actor,payload);}catch(e){if(e.status===403)denied=true;else throw e;}
   if(!denied)AlchemistCatalog.fail(503,'CLIENT_WRITE_BOUNDARY_FAILED');
  }
  var proof={policyVersion:2,role:role,subjectDigest:services.digest(actor.sub),sourceSha:properties.getProperty('ALCHEMIST_SOURCE_SHA'),webClientId:web,at:services.now(),masterPublicationVerified:master,clientPublicationDenied:!master};
  var encoded=JSON.stringify(proof),key='ALCHEMIST_16A_PROOF_'+role;
  properties.setProperty(key,encoded);if(properties.getProperty(key)!==encoded)AlchemistCatalog.fail(503,'AUTH_PROOF_READBACK_FAILED');
  return {role:role,verified:true,masterPublicationVerified:master,clientPublicationDenied:!master,at:proof.at,policyVersion:2};
 }
 function status(properties){
  var source=properties.getProperty('ALCHEMIST_SOURCE_SHA'),web=properties.getProperty('ALCHEMIST_GOOGLE_WEB_CLIENT_ID');
  function read(role){try{var p=JSON.parse(properties.getProperty('ALCHEMIST_16A_PROOF_'+role)||'null');return p&&p.policyVersion===2&&p.sourceSha===source&&p.webClientId===web&&p.role===role&&typeof p.subjectDigest==='string'?p:null;}catch(_){return null;}}
  var master=read('MASTER'),client=read('CLIENT'),distinct=!!master&&!!client&&master.subjectDigest!==client.subjectDigest;
  return {policyVersion:2,sourceSha:source,webClientId:web,master:master?{role:'MASTER',verified:master.masterPublicationVerified===true,at:master.at}:null,client:client?{role:'CLIENT',verified:client.clientPublicationDenied===true,at:client.at}:null,distinctAccounts:distinct,serverTwoAccountRoleCheck:distinct&&master.masterPublicationVerified&&client.clientPublicationDenied?'PASS':'PENDING_REAL_ACCOUNTS',serverTwoAccountCheck:distinct&&master.masterPublicationVerified&&client.clientPublicationDenied?'PARTIAL_CLIENT_READ_INSTALL_NOT_VERIFIED':'PENDING_REAL_ACCOUNTS',physicalTwoPhoneQa:'NOT_RUN'};
 }
 return {verify:verify,status:status};
})();
