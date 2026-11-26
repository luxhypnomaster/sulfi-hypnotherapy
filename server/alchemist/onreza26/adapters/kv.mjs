import {fail} from '../core/security.mjs';
export class MemoryKV {
 constructor({namespace,clock,monotonicWrite=true,delay=async()=>{}}) {
  if(!/^synthetic26:[A-Za-z0-9_-]+:$/.test(namespace))fail('NAMESPACE_REQUIRED');
  Object.assign(this,{namespace,clock,delay});this.values=new Map();this.fences=new Map();this.capabilities={monotonicWrite,consistency:'linearizable-fake'};
 }
 key(k){if(typeof k!=='string'||k.length>512||k.includes('..'))fail('INVALID_KEY');return this.namespace+k;}
 async get(k){await this.delay('get');const r=this.values.get(this.key(k));return r&&r.expires>this.clock()?structuredClone(r.value):null;}
 async put(k,value,ttl){if(!Number.isSafeInteger(ttl)||ttl<1||ttl>30)fail('TTL_REQUIRED');await this.delay('put');this.values.set(this.key(k),{value:structuredClone(value),expires:this.clock()+ttl});}
 async putVersioned(k,version,value,ttl) {
  if(!this.capabilities.monotonicWrite)fail('ORDERING_NOT_PROVEN');
  await this.delay('versioned');const key=this.key(k),prior=this.fences.get(key);
  if(prior&&prior.version>version)return false;
  if(prior&&prior.version===version&&JSON.parse(prior.value.body).payload!==null&&JSON.stringify(JSON.parse(prior.value.body).payload)!==JSON.stringify(JSON.parse(value.body).payload))fail('VERSION_CONFLICT');
  this.fences.set(key,{version,value:structuredClone(value)});
  this.values.set(key,{value:structuredClone(value),expires:this.clock()+ttl});return true;
 }
 async delete(k){await this.delay('delete');this.values.delete(this.key(k));}
}
// Uses ONLY documented ctx.kv APIs. Deliberately does not claim CAS/ordering.
export class OnrezaKV {
 constructor(binding,namespace) {if(!/^synthetic26:[A-Za-z0-9_-]+:$/.test(namespace))fail('NAMESPACE_REQUIRED');this.binding=binding;this.namespace=namespace;this.capabilities={monotonicWrite:false,consistency:'UNVERIFIED'};}
 async get(k){const raw=await this.binding.get(this.namespace+k);return raw?JSON.parse(new TextDecoder().decode(raw)):null;}
 async put(k,v,ttl){if(!Number.isSafeInteger(ttl)||ttl<1||ttl>30)fail('TTL_REQUIRED');await this.binding.set(this.namespace+k,JSON.stringify(v),{ttl});}
 async delete(k){await this.binding.delete(this.namespace+k);}
 async putVersioned(){fail('ORDERING_NOT_PROVEN');}
}
