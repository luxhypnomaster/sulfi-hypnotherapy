import {test} from 'node:test';import assert from 'node:assert/strict';
import {verifiedDeployIdentity} from '../../../scripts/alchemist/deploy-identity.mjs';
const owner={sub:'fixture-owner',email:'luxhypnomaster@gmail.com',email_verified:true},saved={client_id:'fixture.apps.googleusercontent.com'};
test('existing lawful OAuth refresh supplies missing or expired CI ID token without another owner login',async()=>{
 for(const initial of [undefined,'EXPIRED_FIXTURE']){
 let refreshes=0;
 const client={credentials:{id_token:initial},verifyIdToken:async({idToken,audience})=>{assert.equal(audience,saved.client_id);if(idToken==='EXPIRED_FIXTURE')throw Error('expired');assert.equal(idToken,'REFRESHED_FIXTURE');return {getPayload:()=>owner};},refreshAccessToken:async()=>{refreshes++;return {credentials:{id_token:'REFRESHED_FIXTURE'}};}};
 const result=await verifiedDeployIdentity(client,saved);assert.equal(result.identity.sub,owner.sub);assert.equal(refreshes,1);
 }
});
test('missing refreshed identity, wrong account, unverified email and rejected signature fail closed',async()=>{
 for(const variant of ['missing','account','email','signature']){
 const client={credentials:{},refreshAccessToken:async()=>({credentials:variant==='missing'?{}:{id_token:'FIXTURE'}}),verifyIdToken:async()=>{if(variant==='signature')throw Error('forged');return {getPayload:()=>({...owner,...(variant==='account'?{email:'another@example.test'}:variant==='email'?{email_verified:false}:{})})};}};
 await assert.rejects(verifiedDeployIdentity(client,saved),/CI_ID_TOKEN_|WRONG_DEPLOY_OWNER/);
 }
});
