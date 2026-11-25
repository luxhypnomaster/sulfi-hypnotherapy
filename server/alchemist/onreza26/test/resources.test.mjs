import test from 'node:test';import assert from 'node:assert/strict';import {reconcile} from '../core/resources.mjs';
const inventory={workspaceId:'synthetic-workspace',sqlInUse:1,sqlLimit:1,resources:[{kind:'project',id:'p',name:'protocol22-staging'},{kind:'compute',id:'c',name:'protocol22-api',projectId:'p'},{kind:'sql',id:'s',name:'protocol22-staging',projectId:'p'}]};
test('resource reconciliation reuses saved IDs and refuses ambiguity',()=>{
 const q={expectedWorkspaceId:inventory.workspaceId,inventory,saved:{project:'p',compute:'c',sql:'s'}};
 assert.equal(reconcile(q).status,'REUSE');assert.equal(reconcile({...q,saved:{sql:'other'}}).reason,'SAVED_ID_MISMATCH');
 assert.equal(reconcile({...q,inventory:{...inventory,resources:[...inventory.resources,inventory.resources[0]]}}).reason,'DUPLICATE_RESOURCE');
 assert.equal(reconcile({...q,expectedWorkspaceId:'wrong'}).reason,'WORKSPACE_AMBIGUOUS');
});
test('occupied PostgreSQL quota stops creation, missing resources never provision themselves',()=>{
 const i={...inventory,resources:[]};assert.equal(reconcile({expectedWorkspaceId:i.workspaceId,inventory:i}).reason,'SQL_QUOTA_OCCUPIED');
 const q=reconcile({expectedWorkspaceId:i.workspaceId,inventory:{...i,sqlInUse:0}});assert.equal(q.status,'MISSING_REQUIRES_LIVE_GATES');assert.equal(q.provisions,false);
});
