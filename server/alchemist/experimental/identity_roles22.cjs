'use strict';
const {digest22,fail,id}=require('./project_store22.cjs');
const initialRoles={OWNER:{rank:100},ADMIN:{rank:70},EDITOR:{rank:40},AUTHOR:{rank:30},CLIENT:{rank:10}};
class IdentityRoles22 {
 constructor(s){this.s=s;}
 // Caller is an actual provider verifier, not an email or client role hint.
 resolve(verified){if(!verified||verified.verified!==true||!verified.issuer||!verified.sub||verified.expiresAt<=Date.now())fail(401,'AUTH_REQUIRED');
  const key=digest22([verified.issuer,verified.sub]);return this.s.tx(()=>{
   let mapping=this.s.get('identities',key);if(!mapping){mapping={uid:'usr_'+key,issuer:verified.issuer,subject:verified.sub};this.s.set('identities',key,mapping);}
   this.s.set('identity-by-uid',mapping.uid,mapping);
   const role=this.s.get('roles',mapping.uid)||{role:'CLIENT',canManageSubordinateRoles:false,verifiedPro:false};return {...mapping,...role,binding:verified.binding,expiresAt:verified.expiresAt};
  });
 }
 bootstrapOwner(uid){return this.s.tx(()=>{if(this.s.get('governance','owner'))fail(409,'OWNER_ALREADY_SET');this.s.set('governance','owner',{uid});this.s.set('governance','roleDefinitions',initialRoles);this.s.set('roles',uid,{role:'OWNER',canManageSubordinateRoles:false,verifiedPro:false});});}
 current(uid){return {uid,subject:this.s.get('identity-by-uid',uid)?.subject,...(this.s.get('roles',uid)||{role:'CLIENT',canManageSubordinateRoles:false,verifiedPro:false})};}
 admin(actor){const a=this.current(actor.uid);if(!['OWNER','ADMIN'].includes(a.role))fail(403,'ADMIN_REQUIRED');return a;}
 owner(actor){const a=this.current(actor.uid);if(a.role!=='OWNER')fail(403,'OWNER_REQUIRED');return a;}
 change(actor,q){return this.s.receipt(actor.uid,q.requestId,q,()=>{
  const a=this.current(actor.uid),target=this.current(id(q.uid)),defs=this.s.get('governance','roleDefinitions')||initialRoles;
  if(!Object.hasOwn(defs,q.role))fail(422,'UNKNOWN_ROLE');
  if(q.role==='OWNER'&&q.uid!==this.s.get('governance','owner')?.uid)fail(403,'OWNER_IMMUTABLE');
  if(q.role==='OWNER'&&q.uid!==this.s.get('governance','owner')?.uid)fail(403,'OWNER_IMMUTABLE');
  if(a.role!=='OWNER'){
   if(a.role!=='ADMIN'||a.canManageSubordinateRoles!==true||target.role==='OWNER'||target.canManageSubordinateRoles===true||q.role==='OWNER'||q.canManageSubordinateRoles===true||q.verifiedPro!==undefined||defs[q.role].rank>=defs.ADMIN.rank&&q.role!=='ADMIN')fail(403,'ROLE_ASSIGNMENT_DENIED');
  }
  if(target.role==='OWNER'&&(q.role!=='OWNER'||q.uid!==this.s.get('governance','owner')?.uid))fail(403,'OWNER_IMMUTABLE');
  const next={role:q.role,canManageSubordinateRoles:a.role==='OWNER'?q.canManageSubordinateRoles===true:false,verifiedPro:a.role==='OWNER'&&q.verifiedPro!==undefined?q.verifiedPro===true:target.verifiedPro===true};
  if(next.canManageSubordinateRoles&&next.role!=='ADMIN')fail(422,'INVALID_LEAD_GRANT');
  this.s.set('roles',q.uid,next);this.s.audit(a.uid,'role.assign',q.uid);return {uid:q.uid,...next,outcome:'COMMITTED'};
 });}
 definitions(actor,q){this.owner(actor);return this.s.receipt(actor.uid,q.requestId,q,()=>{
  const next=q.roles;if(!next||Object.keys(next).length>32||next.OWNER?.rank!==100||next.ADMIN?.rank!==70)fail(422,'INVALID_ROLE_DEFINITIONS');
  if(this.s.list('roles').some(r=>!Object.hasOwn(next,r.value.role)))fail(422,'ASSIGNED_ROLE_DEFINITION_REQUIRED');
  for(const [k,v]of Object.entries(next))if(!/^[A-Z_]{2,40}$/.test(k)||!Number.isInteger(v.rank)||v.rank<0||v.rank>100||!['OWNER','ADMIN'].includes(k)&&v.rank>=70)fail(422,'INVALID_ROLE_DEFINITIONS');
  const hash=this.s.immutable(next);this.s.set('governance','roleDefinitions',next);this.s.audit(actor.uid,'role.definitions',hash);return {hash,outcome:'COMMITTED'};
 });}
}
module.exports={IdentityRoles22};
