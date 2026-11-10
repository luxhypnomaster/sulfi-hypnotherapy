import {SERVER_NAME,OLD_SCRIPT} from './deploy-core.mjs';
// Private-repo pinned ID was recovered from the trusted create-once run.
// A Drive.file token may push via Script API but cannot mark arbitrary Drive
// appProperties. Never create another project to work around that restriction.
export function verifyPinnedTarget(target,project,email){
 if(target?.schemaVersion!==1||!/^[\w-]{20,200}$/.test(target.scriptId||'')||target.scriptId===OLD_SCRIPT||target.name!==SERVER_NAME||project.scriptId!==target.scriptId||project.title!==SERVER_NAME||project.creator?.email!==email)throw Error('PINNED_PROJECT_MISMATCH');
 return {id:target.scriptId,title:SERVER_NAME,owned:true,marker:'task16-production'};
}
export function freshPrivateAcl(target,email,now=Date.now()){
 const p=target.privateAclReadback,age=now-Date.parse(p?.checkedAt);
 if(!p||p.source!=='connected-drive-files-get'||!Number.isFinite(age)||age<0||age>1800000||p.shared!==false||p.permissions?.length!==1||p.permissions[0].type!=='user'||p.permissions[0].role!=='owner'||p.permissions[0].emailAddress!==email)throw Error('FRESH_PRIVATE_SCRIPT_ACL_REQUIRED');
 return true;
}
