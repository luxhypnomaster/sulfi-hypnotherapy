// Only trusted main may obtain the refresh grant. Flutter receives ONE short-lived
// owner ID token after its exact reviewed source/dependencies have been verified.
import {readFileSync,writeFileSync,mkdirSync,rmSync} from 'node:fs';import {resolve,join} from 'node:path';import {pathToFileURL} from 'node:url';import {spawn} from 'node:child_process';
import {requireTrustedLiveRun,verifyLiveSource} from './live-source.mjs';import {verifiedDeployIdentity} from './deploy-identity.mjs';import {verifyPinnedTarget} from './deploy-target.mjs';
let credential,identityFile,evidence;
try{
 requireTrustedLiveRun(process.env);
 const root=resolve(new URL('../..',import.meta.url).pathname),app=resolve(root,'app-fixture'),pin=JSON.parse(readFileSync(join(root,'server/alchemist/live-approved-source.json')));
 verifyLiveSource(app,pin);
 const temp=process.env.RUNNER_TEMP;if(!temp||!process.env.CLASPRC_JSON)throw Error('GITHUB_SECRET_MISSING');
 evidence=join(temp,'alchemist-live-evidence');mkdirSync(evidence,{recursive:true,mode:0o700});
 const state={kind:'REAL_PRODUCTION_RUNTIME',sourceSha:pin.sourceSha,fullAndroidE2E:false};
 const save=()=>writeFileSync(join(evidence,'LIVE_PREFLIGHT.json'),JSON.stringify(state,null,2),{mode:0o600});
 credential=join(temp,'alchemist-live.clasprc.json');identityFile=join(temp,'alchemist-live-id-token');
 JSON.parse(process.env.CLASPRC_JSON);writeFileSync(credential,process.env.CLASPRC_JSON,{mode:0o600});delete process.env.CLASPRC_JSON;
 const authRoot=join(temp,'clasp-tool/node_modules/@google/clasp/build/src/auth');
 const {FileCredentialStore}=await import(pathToFileURL(join(authRoot,'file_credential_store.js'))),{getAuthorizedOAuth2Client}=await import(pathToFileURL(join(authRoot,'auth.js')));
 const store=new FileCredentialStore(credential),saved=await store.load('default'),client=await getAuthorizedOAuth2Client(store,'default');await client.getAccessToken();
 const {token,identity}=await verifiedDeployIdentity(client,saved);
 const target=JSON.parse(readFileSync(join(root,'server/alchemist/production-target.json'))),api='https://script.googleapis.com/v1/projects/'+target.scriptId;
 const project=(await client.request({url:api})).data;verifyPinnedTarget(target,project,identity.email);
 const file=(await client.request({url:'https://www.googleapis.com/drive/v3/files/'+target.scriptId+'?fields=id,owners(emailAddress),permissions(type,role,emailAddress),trashed'})).data;
 if(file.trashed||file.owners?.length!==1||file.owners[0].emailAddress!==identity.email||file.permissions?.length!==1||file.permissions[0].type!=='user'||file.permissions[0].role!=='owner'||file.permissions[0].emailAddress!==identity.email)throw Error('UNSAFE_SCRIPT_ACL');
 const d=(await client.request({url:api+'/deployments'})).data.deployments.filter(v=>v.deploymentConfig?.description?.startsWith('alchemist-production:'));
 if(d.length!==1)throw Error('AMBIGUOUS_DEPLOYMENTS');
 const web=d[0].entryPoints?.find(e=>e.entryPointType==='WEB_APP')?.webApp,endpoint=web?.url;
 if(!/^https:\/\/script\.google\.com\/macros\/s\/[\w-]+\/exec$/.test(endpoint||'')||web.entryPointConfig?.executeAs!=='USER_DEPLOYING'||web.entryPointConfig?.access!=='ANYONE_ANONYMOUS')throw Error('UNSAFE_WEBAPP');
 async function broker(body){let r=await fetch(endpoint+(body?'':'?op=health'),{method:body?'POST':'GET',headers:body?{'Content-Type':'application/json'}:{},body:body?JSON.stringify(body):undefined,redirect:'manual',signal:AbortSignal.timeout(300000)});
  for(let n=0;[302,303].includes(r.status);n++){const u=new URL(r.headers.get('location'));if(n>=3||u.protocol!=='https:'||u.host!=='script.googleusercontent.com'||u.username||u.password)throw Error('UNSAFE_REDIRECT');r=await fetch(u,{redirect:'manual',signal:AbortSignal.timeout(300000)});}
  if(r.status!==200||!r.headers.get('content-type')?.includes('application/json'))throw Error('RUNTIME_NOT_JSON');const v=await r.json();if(!v.ok)throw Error('LIVE_'+(v.error?.code||'REQUEST_FAILED'));return v.result;}
 const health=await broker();if(health.name!==target.name||health.fullSourceReady!==true)throw Error('HEALTH_MISMATCH');
 const bootstrap=await broker({version:1,operation:'system.initialize',parameters:{},credential:token});if(bootstrap.verifiedFolderCount!==41||bootstrap.schemaVersion!==1)throw Error('STORAGE_UNVERIFIED');
 state.stage='PUBLIC_HEALTH_OWNER_ACL_STORAGE_VERIFIED';state.version=d[0].deploymentConfig.versionNumber;state.deploymentId=d[0].deploymentId;state.endpoint=endpoint;state.storage=bootstrap;save();
 writeFileSync(identityFile,token,{mode:0o600});rmSync(credential,{force:true});
 const childEnv=Object.fromEntries(Object.entries(process.env).filter(([k])=>!/CLASP|TOKEN|SECRET|PASSWORD|KEYSTORE|SIGNING|CREDENTIAL/i.test(k)));
 Object.assign(childEnv,{SULFI_LIVE_ENDPOINT:endpoint,SULFI_LIVE_CREDENTIAL_FILE:identityFile,SULFI_LIVE_PREFIX:'task16e2e_'+process.env.GITHUB_RUN_ID+'_'+process.env.GITHUB_RUN_ATTEMPT,SULFI_LIVE_EVIDENCE:join(evidence,'FLUTTER_LIVE_E2E.json')});
 console.log('LIVE_APPROVED_SOURCE_IDENTITY_AND_STORAGE_VERIFIED');
 const status=await new Promise((done,reject)=>{const p=spawn('flutter',['test','--no-pub','test/task16_live_cloud_test.dart','--reporter','expanded'],{cwd:app,env:childEnv,stdio:'inherit'});p.on('error',reject);p.on('close',done);});
 state.stage=status===0?'FLUTTER_SERVICE_E2E_PASSED':'FLUTTER_SERVICE_E2E_FAILED';save();if(status!==0)process.exitCode=1;
}catch(e){const code=/^[A-Z0-9_]{1,100}$/.test(e.message||'')?e.message:'LIVE_CHECK_FAILED_REDACTED';console.error(code);if(evidence)writeFileSync(join(evidence,'LIVE_BLOCKER.json'),JSON.stringify({code,fullAndroidE2E:false}));process.exitCode=1;}
finally{delete process.env.CLASPRC_JSON;if(credential)rmSync(credential,{force:true});if(identityFile)rmSync(identityFile,{force:true});}
