// Pure deployment state machine. The real adapter uses clasp and Google APIs;
// tests exercise crash/replay without granting cloud access.
export const SERVER_NAME='Сервер Проекта Алхимик';
export const OLD_SCRIPT='10jrwAx77N3tvs7k2Vwojip5-BpK1jjQcQ2dLeMczsaQL2hV8CCRx4Va0';
export async function deployCore(api,source){
 if(!source.fullSourceVerified)throw Error('FULL_SOURCE_NOT_VERIFIED');
 const candidates=await api.findProjects(SERVER_NAME);
 if(candidates.length>1)throw Error('AMBIGUOUS_PROJECT_NAME');
 let id;
 if(candidates.length){const prior=candidates[0];if(prior.title!==SERVER_NAME||!prior.owned||prior.id===OLD_SCRIPT||prior.marker!=='task16-production')throw Error('UNCLAIMED_SAME_NAME_PROJECT');id=prior.id;}
 else{id=await api.createProject(SERVER_NAME);if(!id||id===OLD_SCRIPT)throw Error('INVALID_CREATED_PROJECT');await api.checkpoint({stage:'CREATE_ONCE',scriptId:id});await api.markProject(id);}
 const project=await api.inspectProject(id);if(project.title!==SERVER_NAME||!project.private||!project.owned)throw Error('UNSAFE_SCRIPT_ACL');
 await api.pushSource(id,source.files);await api.compareSource(id,source.files);
 await api.checkpoint({stage:'SOURCE_PUSHED',scriptId:id,sourceSha:source.sha});
 const versions=await api.versions(id);let version=versions.find(v=>v.description===source.description)?.versionNumber;
 if(version){await api.compareVersion(id,version,source.files);}else{version=await api.createVersion(id,source.description);await api.compareVersion(id,version,source.files);}
 const deployments=(await api.deployments(id)).filter(d=>d.description?.startsWith('alchemist-production:'));
 if(deployments.length>1)throw Error('AMBIGUOUS_DEPLOYMENTS');
 const deployed=await api.deployVersion(id,version,deployments[0]?.deploymentId,source.description);
 await api.verifyDeployment(id,deployed,version);
 await api.checkpoint({stage:'DEPLOYED',scriptId:id,version,deploymentId:deployed.id,endpoint:deployed.endpoint});
 await api.health(deployed.endpoint);
 const bootstrap=await api.bootstrap(deployed.endpoint);
 const replay=await api.bootstrap(deployed.endpoint);
 if(bootstrap.schemaVersion!==1||bootstrap.verifiedFolderCount!==41||JSON.stringify(bootstrap)!==JSON.stringify(replay))throw Error('STORAGE_READBACK_FAILED');
 await api.negativeSecurity(deployed.endpoint);
 const result={stage:'DEPLOYED_STORAGE_VERIFIED',scriptId:id,version,deploymentId:deployed.id,endpoint:deployed.endpoint,sourceSha:source.sha,
   fullE2E:false,androidVerified:false};
 await api.checkpoint(result);return result;
}
