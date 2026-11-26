// Pure inventory reconciliation. No cloud calls, billing changes or provisioning.
export function reconcile({expectedWorkspaceId,inventory,saved={}}) {
 if(!expectedWorkspaceId||inventory.workspaceId!==expectedWorkspaceId)return {status:'STOP',reason:'WORKSPACE_AMBIGUOUS'};
 const plans=[['project','protocol22-staging'],['compute','protocol22-api'],['sql','protocol22-staging']];
 const reuse={},missing=[];let sqlBindingRequired=false;
 for(const [kind,name] of plans){
  const matches=inventory.resources.filter(r=>r.kind===kind&&(r.name===name||(kind==='sql'&&r.name==='protocol22_staging')||(saved[kind]&&r.id===saved[kind])));
  if(matches.length>1)return {status:'STOP',reason:'DUPLICATE_RESOURCE',kind};
  const found=matches[0];
  if(saved[kind]&&found?.id!==saved[kind])return {status:'STOP',reason:'SAVED_ID_MISMATCH',kind};
  if(found){
   if(kind!=='project'&&found.projectId!==reuse.project){
    // Managed SQL is a standalone owner Product; existence is not a Service binding.
    const confirmedSQLOwner=kind==='sql'&&saved.sqlOwnerProjectId&&found.ownerProjectId===saved.sqlOwnerProjectId&&found.projectId===saved.sqlOwnerProjectId&&found.workspaceId===expectedWorkspaceId;
    if(!confirmedSQLOwner)return {status:'STOP',reason:'WRONG_PROJECT',kind};
    sqlBindingRequired=!saved.environment||!reuse.compute||!found.bindings?.some(b=>b.projectId===reuse.project&&b.serviceId===reuse.compute&&b.environmentId===saved.environment);
   }
   reuse[kind]=found.id;
  }
  else missing.push(kind);
 }
 if(missing.includes('sql')&&inventory.sqlInUse>=inventory.sqlLimit)return {status:'STOP',reason:'SQL_QUOTA_OCCUPIED'};
 return {status:missing.length?'MISSING_REQUIRES_LIVE_GATES':sqlBindingRequired?'SQL_BINDING_REQUIRES_REVIEW':'REUSE',reuse,missing,
  function:'environment-release member; discover revision by inventory',kv:'environment binding + isolated synthetic namespace; not a separate public API resource',provisions:false};
}
