// Read-only, manual trusted-main inspection. Never exposes token/subject/email.
import {readFileSync,writeFileSync,mkdirSync,rmSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {verifiedDeployIdentity} from './deploy-identity.mjs';
import {verifyPinnedTarget} from './deploy-target.mjs';
if(process.env.GITHUB_EVENT_NAME!=='workflow_dispatch'||process.env.GITHUB_REF!=='refs/heads/main'||process.env.GITHUB_REPOSITORY!=='luxhypnomaster/sulfi-hypnotherapy')throw Error('TRUSTED_MAIN_REQUIRED');
const temp=process.env.RUNNER_TEMP;if(!temp)throw Error('RUNNER_TEMP_REQUIRED');
const file=resolve(temp,'alchemist-status.clasprc.json'),out=resolve(temp,'alchemist-authorization-status');
mkdirSync(out,{recursive:true,mode:0o700});
const result={task:'16-A',checkedAt:new Date().toISOString(),readOnly:true,claspOwnerVerified:false,physicalTwoPhoneQa:'NOT_RUN'};
try{
 if(!process.env.CLASPRC_JSON)throw Error('REPOSITORY_SECRET_MISSING');
 JSON.parse(process.env.CLASPRC_JSON);writeFileSync(file,process.env.CLASPRC_JSON,{mode:0o600});delete process.env.CLASPRC_JSON;
 const base=resolve(temp,'clasp-tool/node_modules/@google/clasp/build/src');
 const {FileCredentialStore}=await import(pathToFileURL(join(base,'auth/file_credential_store.js')));
 const {getAuthorizedOAuth2Client}=await import(pathToFileURL(join(base,'auth/auth.js')));
 const store=new FileCredentialStore(file),saved=await store.load('default'),client=await getAuthorizedOAuth2Client(store,'default');
 await client.getAccessToken();const {token,identity}=await verifiedDeployIdentity(client,saved);result.claspOwnerVerified=true;
 const target=JSON.parse(readFileSync('server/alchemist/production-target.json'));
 const project=(await client.request({url:'https://script.googleapis.com/v1/projects/'+target.scriptId})).data;
 verifyPinnedTarget(target,project,identity.email);result.existingProjectVerified=true;
 const publicConfig=JSON.parse(readFileSync('server/alchemist/android-oauth-public.json'));
 const endpoint=process.env.ALCHEMIST_API;
 if(!/^https:\/\/script\.google\.com\/macros\/s\/[\w-]+\/exec$/.test(endpoint||''))throw Error('PINNED_ENDPOINT_REQUIRED');
 const deployments=(await client.request({url:'https://script.googleapis.com/v1/projects/'+target.scriptId+'/deployments'})).data.deployments||[];
 if(!deployments.some(d=>d.entryPoints?.some(e=>e.webApp?.url===endpoint)))throw Error('DEPLOYMENT_ENDPOINT_MISMATCH');
 async function broker(body){let response=await fetch(endpoint+(body?'':'?op=health'),{method:body?'POST':'GET',headers:body?{'Content-Type':'application/json'}:{},body:body?JSON.stringify(body):undefined,redirect:'manual',signal:AbortSignal.timeout(300000)});
  for(let n=0;[302,303].includes(response.status);n++){const u=new URL(response.headers.get('location'));if(n>=3||u.protocol!=='https:'||u.host!=='script.googleusercontent.com'||u.username||u.password)throw Error('UNEXPECTED_CONTENT_REDIRECT');response=await fetch(u,{redirect:'manual',signal:AbortSignal.timeout(300000)});}
  if(response.status!==200||!response.headers.get('content-type')?.includes('application/json'))throw Error('RUNTIME_NOT_JSON');return response.json();}
 const health=await broker();result.runtimeHealthVerified=health.ok===true&&health.result?.name===target.name;
 if(!result.runtimeHealthVerified)throw Error('RUNTIME_HEALTH_FAILED');
 result.webAudienceConfigured=health.result.webClientId===publicConfig.webClientId;result.authorizationPolicyVersion=health.result.authorizationPolicyVersion||null;
 const status=await broker({version:1,operation:'system.authorizationStatus',parameters:{},credential:token});
 if(!status.ok){result.serverTwoAccountCheck='PENDING_SERVER_UPDATE';result.statusErrorCode=/^[A-Z_]{1,80}$/.test(status.error?.code||'')?status.error.code:'STATUS_UNAVAILABLE';}
 else {const p=status.result;result.serverProof={policyVersion:p.policyVersion,sourceSha:p.sourceSha,webClientId:p.webClientId,master:p.master,client:p.client,distinctAccounts:p.distinctAccounts,serverTwoAccountCheck:p.serverTwoAccountCheck,physicalTwoPhoneQa:'NOT_RUN'};result.serverTwoAccountCheck=p.serverTwoAccountCheck;}
 console.log('CLASP_OWNER_VERIFIED; READ_ONLY; SERVER_TWO_ACCOUNT_CHECK='+result.serverTwoAccountCheck);
}catch(e){const message=String(e.message||'');result.blocker=/^[A-Z0-9_]{1,96}$/.test(message)?message:'READ_ONLY_STATUS_FAILED_REDACTED';console.error(result.blocker);process.exitCode=1;}
finally{writeFileSync(join(out,'AUTHORIZATION_STATUS_16A.json'),JSON.stringify(result,null,2),{mode:0o600});rmSync(file,{force:true});delete process.env.CLASPRC_JSON;}
