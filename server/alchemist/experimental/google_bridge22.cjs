'use strict';
// Additive bridge for the existing GoogleJwt verifier. No new OAuth provider,
// chooser, audience bypass or email-based identity merge. Not wired to GAS.
const crypto=require('node:crypto');
const {fail}=require('./project_store22.cjs');
function googleBridge22({verify,endpoint,clock=()=>Date.now()}){
 if(typeof verify!=='function'||!endpoint)fail(422,'GOOGLE_BRIDGE_CONFIG');
 return async token=>{
  const verified=await verify(token); // signature/aud/iss/expiry checked FIRST
  let claims;try{claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString('utf8'));}catch(_){fail(401,'GOOGLE_TOKEN_INVALID');}
  const sub=verified?.sub||verified?.subject;
  if(!sub||claims.sub!==sub||!['accounts.google.com','https://accounts.google.com'].includes(claims.iss)||!Number.isInteger(claims.exp)||claims.exp*1000<=clock())fail(401,'GOOGLE_TOKEN_INVALID');
  const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
  return {verified:true,issuer:'https://accounts.google.com',sub,expiresAt:claims.exp*1000,binding:hash(endpoint+'|account:'+hash('alchemist:'+endpoint+':'+sub))};
 };
}
async function bootstrapGoogleOwner22(bridge,iam,token,ownerSubject){const v=await bridge(token);if(!ownerSubject||v.sub!==ownerSubject)fail(403,'OWNER_BOOTSTRAP_DENIED');const actor=iam.resolve(v);iam.bootstrapOwner(actor.uid);return {uid:actor.uid};}
module.exports={googleBridge22,bootstrapGoogleOwner22};
