import test from 'node:test';import assert from 'node:assert/strict';
import {stagingTargetPlan} from '../adapters/staging_target26.mjs';
const base={workspaceId:'fixture-workspace',expectedWorkspaceId:'fixture-workspace',projectId:'fixture-api',expectedProjectId:'fixture-api',environments:[{id:'fixture-production',name:'Production',type:'PRODUCTION',participating:true}],createCustomCapability:{allowed:false,details:{requiredPlan:'PRO',currentPlan:'HOBBY'}}};
test('actual Hobby-shaped capability never falls back to Production or upgrades the plan',()=>{
 const p=stagingTargetPlan(base);assert.equal(p.status,'BLOCKED_CUSTOM_ENVIRONMENT_REQUIRES_PRO');assert.equal(p.target,null);assert.deepEqual(p.mutations,[]);
});
test('existing participating Custom Staging is selected exactly; available but unconnected environment requires a separate reviewed step',()=>{
 const env={id:'fixture-staging',name:'Staging',type:'CUSTOM',participating:true};
 const p=stagingTargetPlan({...base,environments:[...base.environments,env]});assert.equal(p.status,'EXISTING_STAGING_TARGET');assert.equal(p.target.environmentId,env.id);assert.equal(p.target.environmentName,'Staging');assert.deepEqual(p.mutations,[]);
 assert.equal(stagingTargetPlan({...base,environments:[{...env,participating:false}]}).status,'STAGING_PARTICIPATION_REQUIRES_REVIEW');
});
test('ambiguous target, wrong workspace/project, missing capability and production-type disguise fail closed',()=>{
 const env={id:'fixture-staging',name:'staging',type:'CUSTOM',participating:true};
 assert.equal(stagingTargetPlan({...base,workspaceId:'other'}).status,'STOP_SCOPE_MISMATCH');
 assert.equal(stagingTargetPlan({...base,projectId:'other'}).status,'STOP_SCOPE_MISMATCH');
 assert.equal(stagingTargetPlan({...base,environments:[env,{...env,id:'duplicate'}]}).status,'STOP_AMBIGUOUS_STAGING');
 assert.equal(stagingTargetPlan({...base,environments:[{...env,type:'PRODUCTION'}]}).status,'STOP_PRODUCTION_TARGET');
 assert.equal(stagingTargetPlan({...base,createCustomCapability:null}).status,'STAGING_CAPABILITY_UNVERIFIED');
 assert.equal(stagingTargetPlan({...base,createCustomCapability:{allowed:true}}).status,'CUSTOM_CREATION_REQUIRES_REVIEW');
});
