// OAuth access credentials and Google ID tokens have separate lifecycles.
// Refresh the existing lawful grant when the saved access token has no ID token.
// No authorization code, token value or private identity is logged.
export async function verifiedDeployIdentity(client,saved){
 if(!saved?.client_id)throw Error('CI_OAUTH_AUDIENCE_UNAVAILABLE');
 let token=client.credentials.id_token||saved.id_token,ticket;
 if(token){try{ticket=await client.verifyIdToken({idToken:token,audience:saved.client_id});}catch{}}
 if(!ticket){
  const refreshed=await client.refreshAccessToken();
  token=refreshed.credentials?.id_token||client.credentials.id_token;
  if(!token)throw Error('CI_ID_TOKEN_REFRESH_UNAVAILABLE');
  try{ticket=await client.verifyIdToken({idToken:token,audience:saved.client_id});}catch{throw Error('CI_ID_TOKEN_VERIFICATION_FAILED');}
 }
 const identity=ticket.getPayload();
 if(identity.email!=='luxhypnomaster@gmail.com'||identity.email_verified!==true||!identity.sub)throw Error('WRONG_DEPLOY_OWNER');
 return {token,identity};
}
