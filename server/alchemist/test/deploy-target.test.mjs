import {test} from 'node:test';import assert from 'node:assert/strict';
import {verifyPinnedTarget,freshPrivateAcl} from '../../../scripts/alchemist/deploy-target.mjs';
const email='owner@example.test',now=Date.parse('2026-11-10T12:00:00Z');
const t={schemaVersion:1,scriptId:'new-script-created-by-clasp',name:'Сервер Проекта Алхимик',privateAclReadback:{source:'connected-drive-files-get',checkedAt:'2026-11-10T11:59:00Z',shared:false,permissions:[{role:'owner',type:'user',emailAddress:email}]}};
test('pin recovered project ID and freshly observed private ACL; never discover/create through incomplete Drive.file listing',()=>{
 assert.equal(verifyPinnedTarget(t,{scriptId:t.scriptId,title:t.name,creator:{email}},email).id,t.scriptId);assert.equal(freshPrivateAcl(t,email,now),true);
 for(const project of [{scriptId:'other',title:t.name,creator:{email}},{scriptId:t.scriptId,title:t.name,creator:{email:'other@example.test'}}])assert.throws(()=>verifyPinnedTarget(t,project,email),/MISMATCH/);
 for(const proof of [{...t.privateAclReadback,shared:true},{...t.privateAclReadback,checkedAt:'2026-11-10T11:00:00Z'},{...t.privateAclReadback,permissions:[]},{...t.privateAclReadback,permissions:[...t.privateAclReadback.permissions,{type:'anyone',role:'writer'}]}])assert.throws(()=>freshPrivateAcl({...t,privateAclReadback:proof},email,now),/FRESH_PRIVATE/);
});
