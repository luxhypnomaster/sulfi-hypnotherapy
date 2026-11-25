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

test('actual standalone SQL owner topology reuses saved DB instead of duplicating it',()=>{
 const i={...inventory,resources:[...inventory.resources.filter(r=>r.kind!=='sql'),{kind:'sql',id:'sql-existing',name:'protocol22_staging',projectId:'sql-owner-product',ownerProjectId:'sql-owner-product',workspaceId:inventory.workspaceId,bindings:[]}]};
 const p=reconcile({expectedWorkspaceId:i.workspaceId,inventory:i,saved:{project:'p',compute:'c',sql:'sql-existing',sqlOwnerProjectId:'sql-owner-product',environment:'staging-env'}});
 assert.equal(p.status,'SQL_BINDING_REQUIRES_REVIEW');assert.equal(p.reuse.sql,'sql-existing');assert.deepEqual(p.missing,[]);assert.equal(p.provisions,false);
 const bound=structuredClone(i);bound.resources.at(-1).bindings=[{projectId:'p',serviceId:'c',environmentId:'staging-env'}];
 assert.equal(reconcile({expectedWorkspaceId:i.workspaceId,inventory:bound,saved:{project:'p',compute:'c',sql:'sql-existing',sqlOwnerProjectId:'sql-owner-product',environment:'staging-env'}}).status,'REUSE');
});
test('standalone SQL belonging to another workspace or unconfirmed owner cannot be adopted',()=>{
 const i={...inventory,resources:[...inventory.resources.filter(r=>r.kind!=='sql'),{kind:'sql',id:'sql-existing',name:'protocol22_staging',projectId:'sql-owner-product',ownerProjectId:'sql-owner-product',workspaceId:'other',bindings:[]}]};
 const q={expectedWorkspaceId:inventory.workspaceId,inventory:i,saved:{sql:'sql-existing',sqlOwnerProjectId:'sql-owner-product'}};
 assert.equal(reconcile(q).reason,'WRONG_PROJECT');i.resources.at(-1).workspaceId=inventory.workspaceId;
 assert.equal(reconcile({...q,saved:{sql:'sql-existing'}}).reason,'WRONG_PROJECT');
});
