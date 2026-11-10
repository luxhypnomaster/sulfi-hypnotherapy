import {readFileSync} from 'node:fs';import {resolve} from 'node:path';import {execFileSync} from 'node:child_process';import {createHash} from 'node:crypto';
export function requireTrustedLiveRun(env){if(env.GITHUB_EVENT_NAME!=='workflow_dispatch'||env.GITHUB_REF!=='refs/heads/main'||env.GITHUB_REPOSITORY!=='luxhypnomaster/sulfi-hypnotherapy')throw Error('TRUSTED_MAIN_REQUIRED');}
export function verifyLiveSource(directory,pin){
 if(pin.repository!=='luxhypnomaster/sulfi-hypnotherapy'||!/^[a-f0-9]{40}$/.test(pin.sourceSha)||!pin.files)throw Error('INVALID_APPROVED_SOURCE');
 if(execFileSync('git',['-C',directory,'rev-parse','HEAD'],{encoding:'utf8'}).trim()!==pin.sourceSha)throw Error('UNAPPROVED_APP_SOURCE');
 if(execFileSync('git',['-C',directory,'diff','--name-only','HEAD','--','lib','test','pubspec.yaml','pubspec.lock'],{encoding:'utf8'}).trim())throw Error('APP_SOURCE_MODIFIED');
 for(const [name,hash] of Object.entries(pin.files)){
  if(!['test/task16_live_cloud_test.dart','pubspec.lock'].includes(name)||!/^[a-f0-9]{64}$/.test(hash)||createHash('sha256').update(readFileSync(resolve(directory,name))).digest('hex')!==hash)throw Error('APP_SOURCE_HASH_MISMATCH');
 }
}
