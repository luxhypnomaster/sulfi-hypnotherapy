// Financial review gate updated by official addendum26-A. No automatic provisioning.
// Missing Usage API and the10RUB economy target are informational, not hard gates.
export function budgetGate(state,now=Math.floor(Date.now()/1000)) {
 const reasons=[],warnings=[];
 if(!['Hobby','HOBBY'].includes(state.plan)||state.paidObligationsKopecks!==0||state.financialTermsConfirmed!==true)reasons.push('HOBBY_NO_PAID_TERMS_NOT_CONFIRMED');
 if(state.workspaceIdentityVerified!==true)reasons.push('WORKSPACE_UNVERIFIED');
 if(!Number.isSafeInteger(state.observedAt)||now-state.observedAt<0||now-state.observedAt>300)reasons.push('STALE_OR_MISSING_FINANCIAL_READBACK');
 if(state.resourceCreationAuthorized!==true)reasons.push('RESOURCE_CREATION_NOT_AUTHORIZED');
 if(state.minimalResourcesVerified!==true)reasons.push('MINIMAL_RESOURCES_NOT_VERIFIED');
 const w=state.workload;
 if(!w||!Number.isSafeInteger(w.maxRequests)||w.maxRequests<1||!Number.isSafeInteger(w.maxDurationSeconds)||w.maxDurationSeconds<1||w.bounded!==true)reasons.push('BOUNDED_WORKLOAD_NOT_CONFIRMED');
 if(state.safeAfterTestVerified!==true)reasons.push('SAFE_AFTER_TEST_NOT_CONFIRMED');
 if(state.usageApiAvailable!==true)warnings.push('USAGE_API_UNAVAILABLE_DOES_NOT_BLOCK_TRIAL');
 const estimate=Number.isSafeInteger(state.estimatedCostKopecks)&&state.estimatedCostKopecks>=0?state.estimatedCostKopecks:null;
 if(estimate===null)warnings.push('ESTIMATE_UNAVAILABLE');else if(estimate>1000)warnings.push('ABOVE_10RUB_ECONOMY_TARGET_REVIEW');
 return {status:reasons.length?'STOP':'READY_FOR_CONTROLLED_TRIAL_REVIEW',reasons,warnings,estimatedCostKopecks:estimate,advisoryTargetKopecks:1000,guaranteedCap:false,provisions:false};
}
