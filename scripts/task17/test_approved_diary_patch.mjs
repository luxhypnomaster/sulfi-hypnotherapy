// Controlled source/metadata fixtures, never Google credentials or live deployment.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {OLD,NEW,TARGET,PINNED_FILES,sha,planPatch,compareFiles,deploymentVersion} from './approved_diary_patch.mjs';
function fixture(){
 const pins={},files=Object.keys(PINNED_FILES).map(name=>{
  const source=name==='Diary'?'// controlled fixture\n'+OLD+'\n':'// '+name+' controlled';pins[name]=sha(source);return {name,type:'SERVER_JS',source};
 });
 files.push({name:'InitialConfig',type:'SERVER_JS',source:'// no credentials in fixture'},{name:'appsscript',type:'JSON',source:'{}'});
 const old=files.find(f=>f.name==='Diary').source;
 return {files,pins,target:{...TARGET,oldDiary:sha(old),newDiary:sha(old.replace(OLD,NEW))}};
}
test('approved subset changes exactly Diary, preserves initial config/vendor/manifest and all other bytes',()=>{const {files,pins,target}=fixture();const out=planPatch(files,structuredClone(files),pins,target);assert.deepEqual(out.filter(f=>f.name!=='Diary'),files.filter(f=>f.name!=='Diary'));assert.equal(out.find(f=>f.name==='Diary').source,files.find(f=>f.name==='Diary').source.replace(OLD,NEW));});
test('unpublished HEAD cannot be overwritten',()=>{const {files,pins,target}=fixture(),head=structuredClone(files);head[0].source+='private edit';assert.throws(()=>planPatch(files,head,pins,target),/UNPUBLISHED_HEAD/);});
test('candidate diagnostic Router/JWT cannot leak into baseline subset',()=>{const {files,pins,target}=fixture();files.find(f=>f.name==='Router').source+='candidate';assert.throws(()=>planPatch(files,files,pins,target),/BASELINE_SOURCE_HASH/);});
test('file names and manifest are fail closed',()=>{const {files,pins,target}=fixture();assert.throws(()=>planPatch([...files,{name:'../../danger',type:'SERVER_JS',source:''}],files,pins,target),/UNSAFE_SOURCE/);assert.throws(()=>planPatch(files.slice(1),files.slice(1),pins,target),/SOURCE_MANIFEST/);});
test('only exact old and expected new Diary digests permitted',()=>{const {files,pins,target}=fixture();assert.throws(()=>planPatch(files,files,pins,{...target,oldDiary:'0'.repeat(64)}),/PRECONDITION/);assert.throws(()=>planPatch(files,files,pins,{...target,newDiary:'0'.repeat(64)}),/DIGEST/);});
test('readback verifies every byte/type, not just one source name',()=>{const {files}=fixture();compareFiles(files,structuredClone(files));const changed=structuredClone(files);changed[0].source+='mutation';assert.throws(()=>compareFiles(changed,files),/READBACK/);});
test('deployment must retain exact endpoint, execution identity, access and ID',()=>{const d={deploymentId:TARGET.deployment,deploymentConfig:{versionNumber:6},entryPoints:[{entryPointType:'WEB_APP',webApp:{url:'https://script.google.com/macros/s/'+TARGET.deployment+'/exec',entryPointConfig:{executeAs:'USER_DEPLOYING',access:'ANYONE_ANONYMOUS'}}}]};assert.equal(deploymentVersion(d),6);for(const key of ['deploymentId']){const bad=structuredClone(d);bad[key]='other';assert.throws(()=>deploymentVersion(bad),/MISMATCH/);}const bad=structuredClone(d);bad.entryPoints[0].webApp.entryPointConfig.executeAs='USER_ACCESSING';assert.throws(()=>deploymentVersion(bad),/MISMATCH/);});
test('runtime source has no create/bootstrap/Drive permission actions and starts with main approval guard',()=>{const s=readFileSync(new URL('./approved_diary_patch.mjs',import.meta.url),'utf8');assert.ok(s.indexOf('SEPARATE_APPROVAL_AND_TRUSTED_MAIN_REQUIRED')<s.indexOf('writeFileSync(credential'));assert.doesNotMatch(s,/create-script|system\.initialize|permissions\.create|drive\.googleapis/);});

test('inspection returns before any production writer and readonly grant cannot select writer',()=>{
 const s=readFileSync(new URL('./approved_diary_patch.mjs',import.meta.url),'utf8');
 const begin=s.indexOf("if(mode==='inspect')"),end=s.indexOf('return; // STOP before workspace');
 assert.ok(begin>0&&end>begin&&end<s.indexOf('const cli='));
 const block=s.slice(begin,end);
 assert.doesNotMatch(block,/await clasp|await deploy|writeFileSync|mkdirSync/);
 assert.match(block,/LIVE_VERSION_NOT6_STOP/);assert.match(block,/planPatch\(base,head\)/);
 assert.match(s,/mode!==.inspect.&&process.env.TASK17_APPROVED!==.DIARY_ONLY_WITH_ROLLBACK6./);
});
