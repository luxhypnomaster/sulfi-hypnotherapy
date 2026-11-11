import {test} from 'node:test';import assert from 'node:assert/strict';
import {scriptAclDecision,readScriptAcl} from '../../../scripts/alchemist/script-acl.mjs';
const email='owner@example.test',file={shared:true,owners:[{emailAddress:email}]},owner={type:'user',role:'owner',emailAddress:email};
test('complete explicit permission ACL is authoritative; Files.shared summary grants no permission',()=>{
 assert.equal(scriptAclDecision(file,[owner],1,email).privateVerified,true);
 for(const permissions of [[],[owner,{type:'anyone',role:'reader'}],[owner,{type:'user',role:'writer',emailAddress:'other@example.test'}],[{...owner,role:'reader'}],[{...owner,emailAddress:'other@example.test'}]])assert.equal(scriptAclDecision({...file,shared:false},permissions,1,email).privateVerified,false);
 assert.equal(scriptAclDecision({...file,trashed:true},[owner],1,email).privateVerified,false);
});
test('all permission pages are read; hidden later page grant or cursor loop never passes',async()=>{
 let calls=0;const client={request:async({url})=>{calls++;return {data:!url.endsWith('/permissions')?file:calls===2?{permissions:[owner],nextPageToken:'next'}:{permissions:[{type:'anyone',role:'reader'}]}};}};
 const result=await readScriptAcl(client,'pinned-project',email);assert.equal(result.permissionPages,2);assert.equal(result.privateVerified,false);
 const looping={request:async({url})=>({data:url.endsWith('/permissions')?{permissions:[owner],nextPageToken:'same'}:file})};await assert.rejects(readScriptAcl(looping,'pinned-project',email),/CURSOR_LOOP/);
});
