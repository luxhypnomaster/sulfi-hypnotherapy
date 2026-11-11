import {test} from 'node:test';import assert from 'node:assert/strict';import {draftCandidateBody} from '../../../scripts/alchemist/auth-candidate-delivery.mjs';
const repo={private:true,full_name:'luxhypnomaster/sulfi-hypnotherapy'},config={draftTag:'task16a-auth-candidate-23',sourceSha:'a'.repeat(40),package:'ru.sulfi.sulfi_hypnotherapy',versionCode:23};
test('16-A candidate delivery is a private draft only; public repo, foreign package and final-release tags are refused',()=>{
 const body=draftCandidateBody(repo,config);assert.equal(body.draft,true);assert.equal(body.prerelease,true);assert.equal(body.target_commitish,config.sourceSha);
 for(const r of [{...repo,private:false},{...repo,full_name:'other/repo'}])assert.throws(()=>draftCandidateBody(r,config),/PRIVATE_PINNED/);
 for(const c of [{...config,draftTag:'v0.4.15'},{...config,package:'other.package'},{...config,sourceSha:'main'}])assert.throws(()=>draftCandidateBody(repo,c),/PRIVATE_PINNED/);
});
