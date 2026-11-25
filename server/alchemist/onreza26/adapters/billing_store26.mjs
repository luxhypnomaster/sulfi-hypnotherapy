import {readFile} from 'node:fs/promises';
export class PostgresBillingStore {
 constructor(pool){this.pool=pool;this.durability='postgresql';}
 async migrate(){await this.pool.query(await readFile(new URL('../sql/002_billing_cache.sql',import.meta.url),'utf8'));}
 row(r){return r?{lastAttemptAt:r.last_attempt_at===null?null:Number(r.last_attempt_at),lastSuccessAt:r.last_success_at===null?null:Number(r.last_success_at),lastGood:r.last_good,leaseId:r.lease_id,leaseUntil:Number(r.lease_until),providerNotBefore:Number(r.provider_not_before),lastErrorCode:r.last_error_code,accessDenied:r.access_denied}:null;}
 async read(key){return this.row((await this.pool.query('SELECT * FROM p22_stage26.billing_cache WHERE binding_key=$1',[key])).rows[0]);}
 async claim(key,{leaseId,now,manual,entry,windowMs,leaseMs,minRefreshMs}) {
  await this.pool.query('INSERT INTO p22_stage26.billing_cache(binding_key) VALUES($1) ON CONFLICT DO NOTHING',[key]);
  if(!manual&&!entry)return {acquired:false,state:await this.read(key)};
  const r=(await this.pool.query(`UPDATE p22_stage26.billing_cache SET
    lease_id=$2,lease_until=$3,last_attempt_at=$4,provider_not_before=$5
    WHERE binding_key=$1 AND lease_until<=$4 AND provider_not_before<=$4
      AND (last_attempt_at IS NULL OR last_attempt_at<=$4)
      AND ($6 OR last_attempt_at IS NULL OR last_attempt_at<=$7)
    RETURNING *`,[key,leaseId,now+leaseMs,now,now+minRefreshMs,manual,now-windowMs])).rows[0];
  return {acquired:!!r,state:r?this.row(r):await this.read(key)};
 }
 async complete(key,leaseId,period,value,now){const r=await this.pool.query("UPDATE p22_stage26.billing_cache SET last_good=COALESCE(last_good,'{}'::jsonb) || jsonb_build_object($3::text,jsonb_build_object('snapshot',$4::jsonb,'successAt',$5::bigint)),last_success_at=$5,lease_id=NULL,lease_until=0,last_error_code=NULL,access_denied=false WHERE binding_key=$1 AND lease_id=$2 RETURNING binding_key",[key,leaseId,period,value,now]);return r.rows.length===1;}
 async fail(key,leaseId,{now,errorCode,accessDenied,retryAfterMs=0}){await this.pool.query('UPDATE p22_stage26.billing_cache SET lease_id=NULL,lease_until=0,last_error_code=$3,access_denied=$4,provider_not_before=GREATEST(provider_not_before,$5) WHERE binding_key=$1 AND lease_id=$2',[key,leaseId,errorCode,accessDenied,now+retryAfterMs]);}
}
export class MemoryBillingStore {
 // Explicit controlled fake, never a silent production fallback.
 constructor(){this.rows=new Map();this.durability='CONTROLLED_MEMORY_FAKE';}
 async read(k){return structuredClone(this.rows.get(k)||null);}
 async claim(k,o){let r=this.rows.get(k);if(!r){r={lastAttemptAt:null,lastSuccessAt:null,lastGood:null,leaseId:null,leaseUntil:0,providerNotBefore:0,lastErrorCode:null,accessDenied:false};this.rows.set(k,r);}
  const allowed=(o.manual||o.entry)&&r.leaseUntil<=o.now&&r.providerNotBefore<=o.now&&(r.lastAttemptAt===null||r.lastAttemptAt<=o.now)&&(o.manual||r.lastAttemptAt===null||r.lastAttemptAt<=o.now-o.windowMs);
  if(allowed)Object.assign(r,{lastAttemptAt:o.now,leaseId:o.leaseId,leaseUntil:o.now+o.leaseMs,providerNotBefore:o.now+o.minRefreshMs});return {acquired:allowed,state:structuredClone(r)};
 }
 async complete(k,id,period,value,now){const r=this.rows.get(k);if(r?.leaseId!==id)return false;Object.assign(r,{lastGood:{...(r.lastGood||{}),[period]:{snapshot:structuredClone(value),successAt:now}},lastSuccessAt:now,leaseId:null,leaseUntil:0,lastErrorCode:null,accessDenied:false});return true;}
 async fail(k,id,o){const r=this.rows.get(k);if(r?.leaseId!==id)return;Object.assign(r,{leaseId:null,leaseUntil:0,lastErrorCode:o.errorCode,accessDenied:o.accessDenied,providerNotBefore:Math.max(r.providerNotBefore,o.now+o.retryAfterMs)});}
}
