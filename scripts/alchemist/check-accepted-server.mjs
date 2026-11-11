// The repository variable is set only after real two-account read/install QA.
// Unit tests, clasp identity, or role-only proof never set this acceptance gate.
const accepted=process.env.ACCEPTED_SERVER_SOURCE||'',endpoint=process.env.ALCHEMIST_API||'';
try{
 if(!/^[a-f0-9]{40}$/.test(accepted)||!/^https:\/\/script\.google\.com\/macros\/s\/[\w-]+\/exec$/.test(endpoint))throw Error();
 const health=await(await fetch(endpoint+'?op=health',{signal:AbortSignal.timeout(20000)})).json();
 if(!health.ok||health.result?.sourceSha!==accepted||health.result?.authorizationPolicyVersion!==2)throw Error();
 console.log('ACCEPTED_SERVER_SOURCE_VERIFIED');
}catch{console.error('REAL_TWO_ACCOUNT_SERVER_ACCEPTANCE_REQUIRED');process.exit(78);}
