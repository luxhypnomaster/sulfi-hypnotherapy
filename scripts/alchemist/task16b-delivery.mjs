import {readFileSync,writeFileSync,statSync,createReadStream} from 'node:fs';import {createHash} from 'node:crypto';
export function task16bPairBody(repo,c){
 if(repo.private!==true||repo.full_name!=='luxhypnomaster/sulfi-hypnotherapy'||c.purpose!=='TWO_TEST_CANDIDATES_FOR_HUMAN_ACCEPTANCE_NOT_ACCEPTED_RELEASE'||!/^[a-f0-9]{40}$/.test(c.sourceSha)||!/^task16b-qa-pair-25$/.test(c.draftTag)||c.packages?.master!=='ru.sulfi.sulfi_hypnotherapy'||c.packages?.client!=='ru.sulfi.sulfi_hypnotherapy.clienttest')throw Error('PRIVATE_QA_PAIR_REQUIRED');
 return {tag_name:c.draftTag,target_commitish:c.sourceSha,draft:true,prerelease:true,name:'№16/16-А/16-Б: две APK для приёмки, сборка '+c.versionCode,body:'Два кандидата из одного проверенного SHA '+c.sourceSha+'. Для владельца и второго Google-пользователя. Первоначальные входы на двух телефонах подтверждены владельцем для APK24. Повторная приёмка APK25 и полный E2E ожидают испытаний владельца. Сервер6 существующий. Стабильная подпись и package сохранены. Мастерскую APK устанавливать поверх прежней, не удалять данные. Это закрытый черновик, не принятый релиз и не массовая раздача. Google Drive для APK не используется.'};
}
async function main(){
 if(process.env.GITHUB_EVENT_NAME!=='workflow_dispatch'||process.env.GITHUB_REF!=='refs/heads/fix/task16b-auth-transfer-publication'||process.env.GITHUB_REPOSITORY!=='luxhypnomaster/sulfi-hypnotherapy')throw Error('TRUSTED_MAIN_REQUIRED');
 const token=process.env.GH_TOKEN,c={purpose:'TWO_TEST_CANDIDATES_FOR_HUMAN_ACCEPTANCE_NOT_ACCEPTED_RELEASE',sourceSha:process.env.GITHUB_SHA,draftTag:'task16b-qa-pair-25',versionCode:25,branch:'fix/task16b-auth-transfer-publication',packages:{master:'ru.sulfi.sulfi_hypnotherapy',client:'ru.sulfi.sulfi_hypnotherapy.clienttest'}},base='https://api.github.com/repos/luxhypnomaster/sulfi-hypnotherapy';if(!token)throw Error('TOKEN_REQUIRED');
 async function api(path,method='GET',body){const r=await fetch(base+path,{method,redirect:'error',headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json',...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});if(!r.ok)throw Error('GITHUB_QA_API_'+r.status);return r.json();}
 const body=task16bPairBody(await api(''),c);
 const runs=await api('/actions/workflows/checks.yml/runs?event=workflow_dispatch&head_sha='+c.sourceSha);
 const check=runs.workflow_runs.find(r=>r.conclusion==='success'&&r.head_sha===c.sourceSha&&r.head_branch===c.branch&&r.path==='.github/workflows/checks.yml');
 if(!check)throw Error('EXACT_SOURCE_CHECKS_REQUIRED');
 const existing=(await api('/releases?per_page=100')).filter(r=>r.tag_name===c.draftTag);if(existing.length>1||existing.some(r=>!r.draft||r.target_commitish!==c.sourceSha))throw Error('DRAFT_MISMATCH');
 const release=existing[0]||await api('/releases','POST',body),upload=new URL(release.upload_url.split('{')[0]);if(upload.protocol!=='https:'||upload.host!=='uploads.github.com')throw Error('UNSAFE_UPLOAD_HOST');
 const assets=[];
 for(const edition of ['master','client']){
  const name='sulfi-'+edition+'-test-'+c.versionCode+'.apk',path=process.env.RUNNER_TEMP+'/qa-pair/'+name,bytes=statSync(path).size,hash=createHash('sha256').update(readFileSync(path)).digest('hex');if(bytes<1000000)throw Error('APK_REQUIRED');
  let asset=release.assets.find(a=>a.name===name);
  if(asset){if(asset.digest!=='sha256:'+hash||asset.size!==bytes)throw Error('EXISTING_ASSET_MISMATCH');}
  else{upload.searchParams.set('name',name);const r=await fetch(upload,{method:'POST',redirect:'error',duplex:'half',headers:{Authorization:'Bearer '+token,'Content-Type':'application/octet-stream','Content-Length':String(bytes)},body:createReadStream(path)});if(!r.ok)throw Error('ASSET_UPLOAD_'+r.status);asset=await r.json();}
  if(asset.size!==bytes||asset.digest!=='sha256:'+hash)throw Error('ASSET_DIGEST_READBACK_MISMATCH');
  assets.push({edition,name,id:asset.id,bytes,sha256:hash,url:asset.browser_download_url,package:c.packages[edition]});console.log('QA_APK_'+edition.toUpperCase()+'_URL='+asset.browser_download_url);console.log('QA_APK_'+edition.toUpperCase()+'_SHA256='+hash);
 }
 const evidence={sourceSha:c.sourceSha,versionCode:c.versionCode,draft:true,releaseId:release.id,releaseUrl:release.html_url,assets,realGoogleUsers:'OWNER_REPORTED_INITIAL_LOGIN_APK24_ONLY',physicalAcceptance:'NOT_RUN',accepted:false};
 writeFileSync(process.env.RUNNER_TEMP+'/QA_PAIR_25.json',JSON.stringify(evidence,null,2));console.log('QA_PAIR_DRAFT_URL='+release.html_url);
}
if(process.env.SULFI_QA_PAIR_EXECUTE==='1')main().catch(e=>{console.error(/^[A-Z0-9_]{1,96}$/.test(e.message)?e.message:'QA_PAIR_DELIVERY_FAILED_REDACTED');process.exitCode=1;});
