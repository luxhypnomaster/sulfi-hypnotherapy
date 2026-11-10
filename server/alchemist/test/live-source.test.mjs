import {test} from 'node:test';import assert from 'node:assert/strict';import {mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {execFileSync} from 'node:child_process';import {createHash} from 'node:crypto';
import {requireTrustedLiveRun,verifyLiveSource} from '../../../scripts/alchemist/live-source.mjs';
test('production identity never reaches arbitrary PR/fork/ref or changed Flutter source/dependency lock',()=>{
 for(const env of [{},{GITHUB_EVENT_NAME:'pull_request',GITHUB_REF:'refs/heads/main',GITHUB_REPOSITORY:'luxhypnomaster/sulfi-hypnotherapy'},{GITHUB_EVENT_NAME:'workflow_dispatch',GITHUB_REF:'refs/heads/feature',GITHUB_REPOSITORY:'luxhypnomaster/sulfi-hypnotherapy'}])assert.throws(()=>requireTrustedLiveRun(env),/TRUSTED_MAIN/);
 const root=mkdtempSync(join(tmpdir(),'live-source-'));try{
 mkdirSync(join(root,'test'));writeFileSync(join(root,'test/task16_live_cloud_test.dart'),'reviewed');writeFileSync(join(root,'pubspec.lock'),'locked');
 const git=args=>execFileSync('git',['-C',root,...args],{encoding:'utf8'}).trim();git(['init','-q']);git(['add','.']);git(['-c','user.name=Fixture','-c','user.email=fixture@example.test','commit','-qm','fixture']);
 const sha=s=>createHash('sha256').update(s).digest('hex'),pin={repository:'luxhypnomaster/sulfi-hypnotherapy',sourceSha:git(['rev-parse','HEAD']),files:{'test/task16_live_cloud_test.dart':sha('reviewed'),'pubspec.lock':sha('locked')}};
 verifyLiveSource(root,pin);assert.throws(()=>verifyLiveSource(root,{...pin,sourceSha:'f'.repeat(40)}),/UNAPPROVED/);
 writeFileSync(join(root,'pubspec.lock'),'altered');assert.throws(()=>verifyLiveSource(root,pin),/MODIFIED/);
 }finally{rmSync(root,{recursive:true,force:true});}
});
