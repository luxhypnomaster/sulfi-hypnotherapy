import {test} from 'node:test';import assert from 'node:assert/strict';import vm from 'node:vm';import {readFileSync} from 'node:fs';
test('effective blob/index file ACL is checked even when its parent stays private',()=>{
 let permissions=[{type:'user',role:'owner',emailAddress:'owner@example.test'}],owner='owner@example.test';
 const c=vm.createContext({Drive:{Files:{get:()=>({id:'file',owners:[{emailAddress:owner}],mimeType:'application/json',parents:['private-folder']})},Permissions:{list:()=>({permissions})}}});
 vm.runInContext(readFileSync(new URL('../src/GasFiles.js',import.meta.url),'utf8'),c);
 assert.equal(c.AlchemistGasFiles.privateFile('file',owner).id,'file');
 permissions.push({type:'anyone',role:'reader'});assert.throws(()=>c.AlchemistGasFiles.privateFile('file',owner),/UNSAFE_FILE_ACL/);
 permissions=[{type:'user',role:'owner',emailAddress:owner}];owner='other@example.test';
 assert.throws(()=>c.AlchemistGasFiles.privateFile('file','owner@example.test'),/UNSAFE_FILE_OWNER/);
});
