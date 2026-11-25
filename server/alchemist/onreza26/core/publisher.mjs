import {seal,fail} from './security.mjs';
export class ProjectionPublisher {
 constructor({repository,kv,key,clock}) {Object.assign(this,{repository,kv,key,clock});}
 async drain(limit=16) {
  if(!this.kv.capabilities?.monotonicWrite)fail('ORDERING_NOT_PROVEN');
  if(!Number.isSafeInteger(limit)||limit<1||limit>32)fail('INVALID_LIMIT',422);
  let delivered=0;
  for(const event of await this.repository.pending(limit)) {
   await this.repository.attempt(event.id);
   const current=await this.repository.latestProjection(event.key);
   if(!current)fail('PROJECTION_SOURCE_MISSING');
   const validUntil=Math.min(this.clock()+30,current.payload?.expiresAt??Infinity);
   const envelope=seal({version:current.version,key:event.key,payload:current.payload,validUntil},this.key);
   // Monotonic write is an explicit adapter contract, NEVER emulated with get+set.
   await this.kv.putVersioned(event.key,current.version,envelope,30);
   await this.repository.ack(event.id); delivered++;
  }
  return {delivered};
 }
}
