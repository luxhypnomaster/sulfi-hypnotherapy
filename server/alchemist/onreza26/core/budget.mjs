// Offline approval gate. A calculation is NOT live billing and never provisions.
export function budgetGate(state,now=Math.floor(Date.now()/1000)) {
 const reasons=[];
 if(state.ownerApprovedLimitKopecks!==1000)reasons.push('OWNER_LIMIT_NOT_CONFIRMED');
 if(state.plan!=='Hobby'||state.paidObligationsKopecks!==0)reasons.push('NO_PAID_COMMITMENTS_NOT_PROVEN');
 if(state.workspaceIdentityVerified!==true)reasons.push('WORKSPACE_UNVERIFIED');
 if(!Number.isSafeInteger(state.observedAt)||now-state.observedAt<0||now-state.observedAt>300)reasons.push('STALE_OR_MISSING_PRICING');
 if(state.existingResourcesIncluded!==true||state.residualCostBoundVerified!==true||state.stopComputeVerified!==true||state.stopSqlVerified!==true)reasons.push('RESIDUAL_BOUND_NOT_PROVEN');
 const parts=state.upperBoundsKopecks;
 const required=['build','compute','sqlCompute','sqlStorage','functions','kv','traffic','retainedAfterTest'];
 if(!parts||required.some(k=>!Number.isSafeInteger(parts[k])||parts[k]<0))reasons.push('INCOMPLETE_UPPER_BOUND');
 const maximum=reasons.includes('INCOMPLETE_UPPER_BOUND')?null:required.reduce((s,k)=>s+parts[k],0);
 if(maximum!==null&&(maximum>1000||!Number.isSafeInteger(state.availableCreditKopecks)||maximum>state.availableCreditKopecks))reasons.push('INSUFFICIENT_CREDIT_OR_CAP');
 return {status:reasons.length?'STOP':'CALCULATION_READY_FOR_REVIEW',maximumKopecks:maximum,reasons,provisions:false};
}
