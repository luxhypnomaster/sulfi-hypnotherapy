// Trusted-main deployment only. Credentials never enter GAS source/artifacts.
import {existsSync,readFileSync,writeFileSync,mkdirSync,readdirSync,rmSync} from 'node:fs';
import {resolve,join} from 'node:path';import {pathToFileURL} from 'node:url';
import {execFile} from 'node:child_process';import {promisify} from 'node:util';import {createHash} from 'node:crypto';
import {deployCore,SERVER_NAME,OLD_SCRIPT} from './deploy-core.mjs';
import {verifiedDeployIdentity} from './deploy-identity.mjs';
const run=promisify(execFile),sha=x=>createHash('sha256').update(x).digest('hex');
const readiness=JSON.parse(readFileSync(new URL('../../server/alchemist/deployment-readiness.json',import.meta.url)));
function abort(code){console.error(code);process.exit(78);}
if(!process.env.CLASPRC_JSON)abort('AUTH_PENDING: GITHUB_SECRET_MISSING');
if(readiness.fullSourceVerified!==true)abort('DEPLOY_BLOCKED: FULL_SOURCE_NOT_VERIFIED; no credentials written and no project created');
if(process.env.GITHUB_EVENT_NAME!=='workflow_dispatch'||process.env.GITHUB_REF!=='refs/heads/main'||process.env.GITHUB_REPOSITORY!=='luxhypnomaster/sulfi-hypnotherapy')abort('TRUSTED_MAIN_REQUIRED');
const temp=process.env.RUNNER_TEMP;if(!temp)abort('RUNNER_TEMP_REQUIRED');
const tool=resolve(temp,'clasp-tool/node_modules/@google/clasp'),cli=resolve(temp,'clasp-tool/node_modules/.bin/clasp'),work=resolve(temp,'alchemist-deployment'),credential=resolve(temp,'alchemist.clasprc.json');
mkdirSync(work,{recursive:true,mode:0o700});
const evidence=resolve(temp,'alchemist-evidence');mkdirSync(evidence,{recursive:true,mode:0o700});
let last={stage:'AUTH_PENDING',fullE2E:false};
function checkpoint(v){last={...last,...v};writeFileSync(join(evidence,'DEPLOYMENT.json'),JSON.stringify(last,null,2),{mode:0o600});console.log('DEPLOY_STAGE='+v.stage);}
try{
 JSON.parse(process.env.CLASPRC_JSON);writeFileSync(credential,process.env.CLASPRC_JSON,{mode:0o600});delete process.env.CLASPRC_JSON;
 if(!existsSync(cli))throw Error('PINNED_CLASP_NOT_INSTALLED');
 const {FileCredentialStore}=await import(pathToFileURL(join(tool,'build/src/auth/file_credential_store.js')));
 const {getAuthorizedOAuth2Client}=await import(pathToFileURL(join(tool,'build/src/auth/auth.js')));
 const store=new FileCredentialStore(credential),saved=await store.load('default'),client=await getAuthorizedOAuth2Client(store,'default');
 await client.getAccessToken();
 const {token,identity}=await verifiedDeployIdentity(client,saved);
 checkpoint({stage:'AUTH_VERIFIED'});
 const sourceSha=process.env.GITHUB_SHA;
 if(!/^[a-f0-9]{40}$/.test(sourceSha||''))throw Error('SOURCE_SHA_REQUIRED');
 await run(process.execPath,['scripts/alchemist/build.mjs',join(work,'source')],{cwd:process.cwd()});
 const config={fullSourceVerified:true,ownerSubject:identity.sub,ownerEmail:identity.email,
   ciAudience:saved.client_id,androidWebAudience:process.env.GOOGLE_WEB_CLIENT_ID||null,
   projectFolderId:'1b-FP_emjwE5LpTyx4TFzkbzlffEE7pLl',sourceSha};
 if(config.androidWebAudience&&!/^[\w-]+\.apps\.googleusercontent\.com$/.test(config.androidWebAudience))throw Error('INVALID_ANDROID_OAUTH_AUDIENCE');
 writeFileSync(join(work,'source','InitialConfig.js'),'var AlchemistInitialConfig='+JSON.stringify(config)+';\n');
 writeFileSync(join(work,'.claspignore'),'SOURCE_HASHES.json\n**/.*\n**/node_modules/**\n');
 const files=readdirSync(join(work,'source')).filter(n=>n.endsWith('.js')||n==='appsscript.json').map(name=>({name:name.replace(/\.js$|\.json$/,''),type:name.endsWith('.js')?'SERVER_JS':'JSON',source:readFileSync(join(work,'source',name),'utf8')}));
 const description='alchemist-production:'+sourceSha;
 async function google(method,url,data){try{return (await client.request({method,url,data})).data;}catch(e){const status=e.response?.status||503,raw=e.response?.data?.error?.errors?.[0]?.reason,reason=/^[A-Za-z_]{1,64}$/.test(raw||'')?raw.toUpperCase():'UNSPECIFIED';throw Error((url.includes('script.googleapis.com')?'SCRIPT':'DRIVE')+'_'+method+'_'+status+'_'+reason);}}
 async function clasp(args){try{const r=await run(cli,['-A',credential,'--json',...args],{cwd:work,env:{...process.env,DEBUG:''},timeout:180000,maxBuffer:2*1024*1024});return args[0]==='push'?null:r.stdout.trim()?JSON.parse(r.stdout):null;}catch(e){if(/^(GOOGLE_|CLASP_)/.test(e.message))throw e;throw Error('CLASP_'+args[0].replaceAll('-','_').toUpperCase()+'_FAILED');}}
 function bind(id){writeFileSync(join(work,'.claspignore'),'SOURCE_HASHES.json\n**/.*\n**/node_modules/**\n');if(!id||id===OLD_SCRIPT||!/^[\w-]+$/.test(id))throw Error('UNSAFE_TARGET_SCRIPT');writeFileSync(join(work,'.clasp.json'),JSON.stringify({scriptId:id,rootDir:join(work,'source')}));}
 async function pages(url,key){const all=[];let pageToken;do{const response=await google('GET',url+(url.includes('?')?'&':'?')+(pageToken?'pageToken='+encodeURIComponent(pageToken):''));all.push(...(response[key]||[]));pageToken=response.nextPageToken;}while(pageToken);return all;}
 const scriptApi=id=>'https://script.googleapis.com/v1/projects/'+encodeURIComponent(id);
 const driveApi=id=>'https://www.googleapis.com/drive/v3/files/'+encodeURIComponent(id);
 async function compare(id,expected,version){const response=await google('GET',scriptApi(id)+'/content'+(version?'?versionNumber='+version:''));
   if(response.files.length!==expected.length)throw Error('SOURCE_FILE_COUNT_MISMATCH');
   for(const f of expected){const actual=response.files.find(v=>v.name===f.name&&v.type===f.type);if(!actual)throw Error('SOURCE_FILE_MISSING');
    const same=f.type==='JSON'?JSON.stringify(JSON.parse(actual.source))===JSON.stringify(JSON.parse(f.source)):sha(actual.source)===sha(f.source);
    if(!same)throw Error('SOURCE_READBACK_MISMATCH');}
   writeFileSync(join(evidence,'SOURCE_HASHES.json'),JSON.stringify({sourceSha,files:expected.map(f=>({name:f.name,sha256:sha(f.source)}))},null,2));}
 async function broker(endpoint,body){let response=await fetch(endpoint,{method:body?'POST':'GET',headers:body?{'Content-Type':'application/json'}:{},body:body?JSON.stringify(body):undefined,redirect:'manual',signal:AbortSignal.timeout(300000)});
   for(let i=0;response.status===302||response.status===303;i++){const u=new URL(response.headers.get('location'));if(i>=3||u.protocol!=='https:'||u.host!=='script.googleusercontent.com'||u.username||u.password)throw Error('CLOUD_RUNTIME_CONSENT_OR_ACCESS_REQUIRED');response=await fetch(u,{redirect:'manual',signal:AbortSignal.timeout(300000)});}
   if(response.status!==200||!response.headers.get('content-type')?.includes('application/json'))throw Error('CLOUD_RUNTIME_NOT_EXECUTABLE');return response.json();}
 const adapter={checkpoint,
  async findProjects(title){const q="mimeType='application/vnd.google-apps.script' and name='"+title+"' and trashed=false";
    const matches=await pages('https://www.googleapis.com/drive/v3/files?q='+encodeURIComponent(q)+'&fields=files(id,name,owners(emailAddress),appProperties),nextPageToken','files');
    return matches.map(f=>({id:f.id,title:f.name,owned:f.owners?.length===1&&f.owners[0].emailAddress===identity.email,marker:f.appProperties?.alchemistTask16}));},
  async createProject(title){await clasp(['create-script','--type','standalone','--title',title,'--rootDir',join(work,'source')]);return JSON.parse(readFileSync(join(work,'.clasp.json'))).scriptId;},
  async markProject(id){await google('PATCH',driveApi(id),{appProperties:{alchemistTask16:'task16-production'}});},
  async inspectProject(id){const project=await google('GET',scriptApi(id)),f=await google('GET',driveApi(id)+'?fields=id,owners(emailAddress),permissions(type,role,emailAddress),trashed');
    return {title:project.title,owned:!f.trashed&&f.owners?.length===1&&f.owners[0].emailAddress===identity.email,private:f.permissions?.length===1&&f.permissions[0].type==='user'&&f.permissions[0].role==='owner'&&f.permissions[0].emailAddress===identity.email};},
  async pushSource(id,expected){for(const f of readdirSync(join(work,'source')))rmSync(join(work,'source',f),{force:true});for(const f of expected)writeFileSync(join(work,'source',f.name+(f.type==='JSON'?'.json':'.js')),f.source);bind(id);await clasp(['push','--force']);},compareSource:(id,v)=>compare(id,v),compareVersion:(id,n,v)=>compare(id,v,n),
  versions:id=>pages(scriptApi(id)+'/versions','versions'),
  async createVersion(id,text){bind(id);return (await clasp(['create-version',text])).versionNumber;},
  async deployments(id){return (await pages(scriptApi(id)+'/deployments','deployments')).map(d=>({deploymentId:d.deploymentId,description:d.deploymentConfig?.description}));},
  async deployVersion(id,version,existing,text){bind(id);const args=['create-deployment','--versionNumber',String(version),'--description',text];if(existing)args.push('--deploymentId',existing);const result=await clasp(args);return {id:result.deploymentId};},
  async verifyDeployment(id,deployment,version){const d=await google('GET',scriptApi(id)+'/deployments/'+encodeURIComponent(deployment.id));const web=d.entryPoints?.find(e=>e.entryPointType==='WEB_APP')?.webApp;
    if(d.deploymentConfig?.versionNumber!==version||!web?.url||web.entryPointConfig?.executeAs!=='USER_DEPLOYING'||web.entryPointConfig?.access!=='ANYONE_ANONYMOUS')throw Error('WEBAPP_CONFIGURATION_MISMATCH');deployment.endpoint=web.url;},
  async health(endpoint){const result=await broker(endpoint+'?op=health');if(!result.ok||result.result?.name!==SERVER_NAME||result.result?.fullSourceReady!==true)throw Error('HEALTH_NOT_READY');},
  async bootstrap(endpoint){const result=await broker(endpoint,{version:1,operation:'system.initialize',parameters:{},credential:token});if(!result.ok)throw Error('BOOTSTRAP_'+(result.error?.code||'FAILED'));return result.result;},
  async negativeSecurity(endpoint){for(const q of [
    {operation:'catalog.createDraft',parameters:{requestId:'negative-client'},expected:[401,403]},
    {operation:'media.getDescriptor',parameters:{assetRevisionId:'unavailable'},expected:[404]},
    {operation:'auth.whoami',parameters:{},credential:'forged.token.signature',expected:[401]},
  ]){const result=await broker(endpoint,{version:1,operation:q.operation,parameters:q.parameters,...(q.credential?{credential:q.credential}:{})});if(result.ok||!q.expected.includes(result.status))throw Error('LIVE_NEGATIVE_SECURITY_FAILED');}writeFileSync(join(evidence,'LIVE_SECURITY.json'),JSON.stringify({anonymousMutationDenied:true,missingPrivateAssetDenied:true,forgedTokenDenied:true,fullE2E:false}));},
 };
 await deployCore(adapter,{fullSourceVerified:true,files,sha:sourceSha,description});
}catch(e){const raw=String(e.message||''),code=/^[A-Z0-9_: -]{1,128}$/.test(raw)?raw:'DEPLOYMENT_FAILED_REDACTED';checkpoint({stage:'BLOCKED',reason:code});console.error(code);process.exitCode=1;}
finally{delete process.env.CLASPRC_JSON;rmSync(credential,{force:true});}
