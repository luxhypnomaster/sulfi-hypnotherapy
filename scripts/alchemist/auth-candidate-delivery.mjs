// Private draft delivery only, never a published release/tag or broad rollout.
import {readFileSync,writeFileSync,statSync,createReadStream} from 'node:fs';
import {createHash} from 'node:crypto';
export function draftCandidateBody(repo,config){
 if(repo.private!==true||repo.full_name!=='luxhypnomaster/sulfi-hypnotherapy'||!/^task16a-auth-candidate-[0-9]+$/.test(config.draftTag)||!/^[a-f0-9]{40}$/.test(config.sourceSha)||config.package!=='ru.sulfi.sulfi_hypnotherapy')throw Error('PRIVATE_PINNED_CANDIDATE_REQUIRED');
 return {tag_name:config.draftTag,target_commitish:config.sourceSha,name:'№16-А: проверка Google, мастер, сборка '+config.versionCode,draft:true,prerelease:true,body:'Один кандидат для проверки настоящего Google-входа и серверных ролей владельцем. Не финальная пара APK и не приёмка на двух телефонах. Источник '+config.sourceSha+'. Обновлять поверх прежней мастерской версии; при конфликте подписи не удалять приложение. Клиентская APK после реальной серверной приёмки. Файл .sha256 содержит контрольную сумму. Google Drive для APK не используется.'};
}
async function main(){
 if(process.env.GITHUB_EVENT_NAME!=='workflow_dispatch'||process.env.GITHUB_REF!=='refs/heads/main'||process.env.GITHUB_REPOSITORY!=='luxhypnomaster/sulfi-hypnotherapy')throw Error('TRUSTED_MAIN_REQUIRED');
 const token=process.env.GH_TOKEN;if(!token)throw Error('GITHUB_WRITE_TOKEN_REQUIRED');
 const config=JSON.parse(readFileSync('server/alchemist/auth-candidate-source.json')),base='https://api.github.com/repos/luxhypnomaster/sulfi-hypnotherapy';
 async function api(path,method='GET',body){const r=await fetch(base+path,{method,redirect:'error',headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28',...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});if(!r.ok)throw Error('GITHUB_DRAFT_API_'+r.status);return r.json();}
 const repo=await api(''),body=draftCandidateBody(repo,config);
 const validation=await api('/actions/runs/'+config.verifiedChecksRun);
 if(validation.conclusion!=='success'||validation.head_sha!==config.sourceSha||validation.head_branch!==config.branch||validation.event!=='workflow_dispatch'||validation.path!=='.github/workflows/checks.yml')throw Error('PINNED_SOURCE_CHECKS_NOT_SUCCESSFUL');
 const file=process.env.CANDIDATE_APK;if(!file||statSync(file).size<1000000)throw Error('APK_REQUIRED');
 const hash=createHash('sha256').update(readFileSync(file)).digest('hex'),name='sulfi-master-auth-23.apk',sum=file+'.sha256';writeFileSync(sum,hash+'  '+name+'\n');
 const releases=await api('/releases?per_page=100'),matches=releases.filter(r=>r.tag_name===config.draftTag);
 if(matches.length>1||matches.some(r=>!r.draft))throw Error('PUBLISHED_OR_AMBIGUOUS_RELEASE_REFUSED');
 const release=matches[0]||await api('/releases','POST',body);
 if(!release.draft||release.target_commitish!==config.sourceSha)throw Error('DRAFT_SOURCE_MISMATCH');
 const upload=new URL(release.upload_url.split('{')[0]);if(upload.protocol!=='https:'||upload.host!=='uploads.github.com')throw Error('UNSAFE_ASSET_HOST');
 const assets=[];
 for(const [path,filename] of [[file,name],[sum,name+'.sha256']]){
  if(release.assets.some(a=>a.name===filename))throw Error('EXISTING_CANDIDATE_ASSET_REFUSED');
  upload.searchParams.set('name',filename);
  const response=await fetch(upload,{method:'POST',redirect:'error',duplex:'half',headers:{Authorization:'Bearer '+token,'Content-Type':'application/octet-stream','Content-Length':String(statSync(path).size)},body:createReadStream(path)});
  if(!response.ok)throw Error('DRAFT_ASSET_UPLOAD_'+response.status);const asset=await response.json();assets.push({name:asset.name,id:asset.id,bytes:asset.size,url:asset.browser_download_url});
 }
 const evidence={task:'16-A',kind:'PRIVATE_DRAFT_SINGLE_MASTER_CANDIDATE',sourceSha:config.sourceSha,versionCode:config.versionCode,sha256:hash,releaseUrl:release.html_url,releaseId:release.id,assets,physicalAndroid:'NOT_RUN',twoConnectedApks:'PENDING_REAL_SERVER_ACCEPTANCE'};
 writeFileSync(process.env.RUNNER_TEMP+'/AUTH_CANDIDATE_APK_16A.json',JSON.stringify(evidence,null,2));console.log('PRIVATE_DRAFT_CANDIDATE_URL='+release.html_url);console.log('CANDIDATE_SHA256='+hash);console.log('CANDIDATE_BYTES='+statSync(file).size);
}
if(process.env.SULFI_CANDIDATE_DELIVERY_EXECUTE==='1')main().catch(e=>{console.error(/^[A-Z0-9_]{1,96}$/.test(e.message)?e.message:'CANDIDATE_DELIVERY_FAILED_REDACTED');process.exitCode=1;});
