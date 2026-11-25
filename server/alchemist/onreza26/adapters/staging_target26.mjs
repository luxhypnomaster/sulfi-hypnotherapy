// Read-only normalized control-plane target review, not a deployment executor.
// Never creates an environment, changes a tariff or falls back to Production.
export function stagingTargetPlan({workspaceId,expectedWorkspaceId,projectId,expectedProjectId,environments=[],createCustomCapability,dedicatedHobbyApproval}) {
 const result=status=>({status,target:null,mutations:[]});
 if(!expectedWorkspaceId||workspaceId!==expectedWorkspaceId||!expectedProjectId||projectId!==expectedProjectId)return result('STOP_SCOPE_MISMATCH');
 const matches=environments.filter(e=>typeof e.name==='string'&&e.name.toLowerCase()==='staging');
 if(matches.length>1)return result('STOP_AMBIGUOUS_STAGING');
 if(matches.length===1){const e=matches[0];
  if(e.type!=='CUSTOM')return result('STOP_PRODUCTION_TARGET');
  if(!e.id)return result('STAGING_CAPABILITY_UNVERIFIED');
  if(e.participating!==true)return result('STAGING_PARTICIPATION_REQUIRES_REVIEW');
  return {status:'EXISTING_STAGING_TARGET',target:{projectId,environmentId:e.id,environmentName:e.name},mutations:[]};
 }
 if(dedicatedHobbyApproval?.ownerAuthorized===true){
  if(dedicatedHobbyApproval.projectId!==projectId||dedicatedHobbyApproval.workspaceId!==workspaceId||dedicatedHobbyApproval.logicalEnvironment!=='staging'||dedicatedHobbyApproval.observedPlan!=='HOBBY')return result('STOP_APPROVAL_SCOPE_MISMATCH');
  const defaults=environments.filter(e=>e.name==='Production'&&e.type==='PRODUCTION'&&e.participating===true);
  if(defaults.length!==1||!defaults[0].id)return result('STOP_AMBIGUOUS_APPROVED_DEFAULT');
  return {status:'OWNER_APPROVED_DEDICATED_HOBBY_STAGING',target:{projectId,environmentId:defaults[0].id,environmentName:defaults[0].name,logicalEnvironment:'staging',platformEnvironmentType:'PRODUCTION'},mutations:[]};
 }
 if(createCustomCapability?.allowed===false&&createCustomCapability?.details?.requiredPlan==='PRO'&&createCustomCapability?.details?.currentPlan==='HOBBY')return result('BLOCKED_CUSTOM_ENVIRONMENT_REQUIRES_PRO');
 if(createCustomCapability?.allowed===true)return result('CUSTOM_CREATION_REQUIRES_REVIEW');
 return result('STAGING_CAPABILITY_UNVERIFIED');
}
