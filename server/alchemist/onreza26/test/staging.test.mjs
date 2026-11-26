import test from 'node:test';
import assert from 'node:assert/strict';
import {fixture} from './support.mjs';
import {MemoryKV,OnrezaKV} from '../adapters/kv.mjs';
import {sign,verify,seal,unseal} from '../core/security.mjs';
import {createReader} from '../core/reader.mjs';
import {ProjectionPublisher} from '../core/publisher.mjs';
import {light} from '../light.nrz-fn.mjs';
import {createServer} from 'node:http';
import {handler,start} from '../compute.mjs';
import {mkdtemp,rm,readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const err=code=>e=>e.code===code;
async function using(fn,options){const f=await fixture(options);try{await fn(f);}finally{await f.close();}}
const rowCount=async(f,t)=>Number((await f.pool.query('SELECT count(*) AS n FROM p22_stage26.'+t)).rows[0].n);

test('PostgreSQL engine: repeat migration keeps identities and default roles',()=>using(async f=>{
 await f.repo.migrate();assert.equal(await rowCount(f,'identities'),1);assert.equal((await f.repo.session(f.session.sid)).role,'CLIENT');
}));
test('same verified identity and installation recover stable uid; retry is idempotent',()=>using(async f=>{
 const again=await f.repo.restore(f.proof(),'installation_a','login_a',{allowNew:true});assert.equal(again.sid,f.session.sid);
 const next=await f.repo.restore(f.proof(),'installation_a','login_b',{allowNew:true});assert.equal(next.uid,f.session.uid);
 assert.equal(await rowCount(f,'identities'),1);assert.equal(await rowCount(f,'sessions'),2);
}));
test('unconfirmed client ID, disallowed registration and installation theft denied',()=>using(async f=>{
 await assert.rejects(f.repo.restore({kind:'client'},'installation_a','x'),err('AUTH_REQUIRED'));
 await assert.rejects(f.repo.restore(f.proof('new'),'new_install','x'),err('REGISTRATION_DISABLED'));
 await assert.rejects(f.repo.restore(f.proof('bob'),'installation_a','x',{allowNew:true}),err('INSTALLATION_OWNER_MISMATCH'));
 assert.equal(await rowCount(f,'identities'),1);
}));
test('valid JWT roundtrip; expired, forged, wrong issuer/aud/scope/future rejected',()=>using(async f=>{
 const opts={issuer:'urn:alchemist:staging26',audience:'protocol22-staging',kind:'session',clock:f.clock};
 assert.equal(verify(f.token(),f.key,opts).sub,f.session.uid);
 for(const patch of [{exp:f.clock()},{iss:'other'},{aud:'other'},{iat:f.clock()+1},{scopes:['private:alice']},{rv:0}])assert.throws(()=>verify(sign({...f.claims(f.session),...patch},f.key),f.key,opts),err('AUTH_REQUIRED'));
 assert.throws(()=>verify(f.token().slice(0,-3)+'zzz',f.key,opts),err('AUTH_REQUIRED'));
}));
test('invalid JWT never touches KV or SQL, including fake forwarded identity',()=>using(async f=>{
 let calls=0;const reader=createReader({kv:{get:()=>{calls++;}},authority:{session:()=>{calls++;}},sessionKey:f.key,projectionKey:f.projectionKey,clock:f.clock});
 await assert.rejects(reader.authenticate('bad'),err('AUTH_REQUIRED'));assert.equal(calls,0);
}));
test('warm basic session check from sealed KV does not call SQL',()=>using(async f=>{
 await f.publisher.drain();const n=f.queries.length;
 assert.equal((await f.reader.authenticate(f.token())).uid,f.session.uid);assert.equal(f.queries.length,n);
}));
test('KV miss restores existing session from authoritative SQL, never creates identity',()=>using(async f=>{
 const reader=createReader({kv:f.kv,authority:f.repo,sessionKey:f.key,projectionKey:f.projectionKey,clock:f.clock});
 assert.equal((await reader.authenticate(f.token())).uid,f.session.uid);assert.equal(await rowCount(f,'identities'),1);
}));
test('KV outage and tampering fail closed; no automatic SQL retry storm',()=>using(async f=>{
 const reader=createReader({kv:{get:async()=>{throw Error('network secret should not leak');}},authority:{session:()=>assert.fail('unexpected fallback')},sessionKey:f.key,projectionKey:f.projectionKey,clock:f.clock});
 await assert.rejects(reader.authenticate(f.token()),err('PROJECTION_UNAVAILABLE'));
 await f.kv.put('session:'+f.session.sid,{body:'{}',mac:'bad'},30);
 await assert.rejects(f.reader.authenticate(f.token()),err('PROJECTION_UNAVAILABLE'));
}));
test('TTL bound expires session projection; old KV never grants sensitive role',()=>using(async f=>{
 await f.publisher.drain();assert.ok(await f.reader.authenticate(f.token()));
 await f.repo.revoke(f.session.sid);
 const strong=createReader({kv:f.kv,authority:f.repo,sessionKey:f.key,projectionKey:f.projectionKey,clock:f.clock});
 await assert.rejects(strong.authenticate(f.token(),{sensitive:true}),err('SESSION_REVOKED'));
 await assert.rejects(f.reader.authenticate(f.token(),{sensitive:true}),err('AUTHORITY_UNAVAILABLE'));
 f.advance(31);await assert.rejects(f.reader.authenticate(f.token()),err('AUTHORITY_UNAVAILABLE'));
}));
test('changed current role version rejects stale session before publish',()=>using(async f=>{
 await f.owner();await f.publisher.drain();await f.pool.query('UPDATE p22_stage26.authority SET role_version=role_version+1 WHERE uid=$1',[f.session.uid]);
 await assert.rejects(f.repo.publish(f.claims(f.session),{requestId:'pub',snapshot:f.snapshot(),expectedRevision:0}),err('SESSION_REVOKED'));
}));
test('CLIENT cannot publish; direct Compute path never trusts role headers',()=>using(async f=>{
 await assert.rejects(f.repo.publish({...f.claims(f.session),role:'OWNER'},{requestId:'pub',snapshot:f.snapshot(),expectedRevision:0}),err('PUBLISH_DENIED'));
 assert.equal(await rowCount(f,'heads'),0);
}));
test('verified HEAD wire, publication retry and immutable snapshot',()=>using(async f=>{
 await f.owner();const q={requestId:'publish',snapshot:f.snapshot(),expectedRevision:0};
 const h=await f.repo.publish(f.claims(f.session),q);assert.deepEqual(Object.keys(h).sort(),['scope','catalogRevision','snapshotId','snapshotHash','schemaVersion','createdAt'].sort());
 assert.deepEqual(await f.repo.publish(f.claims(f.session),q),h);
 assert.equal(await rowCount(f,'snapshots'),1);
 await assert.rejects(f.pool.query('UPDATE p22_stage26.snapshots SET sha=$1',[ 'b'.repeat(64)]),/IMMUTABLE/);
 await f.publisher.drain();assert.deepEqual(await f.reader.head(f.token(),'client:public'),h);
 await assert.rejects(f.reader.head(f.token(),'private:alice'),err('SCOPE_DENIED'));
}));
test('identical rebuild preserves exact HEAD/revision/hash despite later build timestamp',()=>using(async f=>{
 await f.owner();const h=await f.repo.publish(f.claims(f.session),{requestId:'a',snapshot:f.snapshot(),expectedRevision:0});f.advance(1);
 assert.deepEqual(await f.repo.publish(f.claims(f.session),{requestId:'b',snapshot:f.snapshot(2),expectedRevision:1}),h);assert.equal(await rowCount(f,'snapshots'),1);
}));
test('missing dependency or unsupported ratings cannot publish a HEAD',()=>using(async f=>{
 await f.owner();const bad=f.snapshot();bad.items[0].dependencies=[{contentId:'missing',revisionId:'r',sha256:'b'.repeat(64)}];
 await assert.rejects(f.repo.publish(f.claims(f.session),{requestId:'a',snapshot:bad,expectedRevision:0}),/MISSING_EXACT_DEPENDENCY/);
 await assert.rejects(f.repo.publish(f.claims(f.session),{requestId:'b',snapshot:f.snapshot(),expectedRevision:0,ratingsRevision:1,ratingsSnapshotHash:'a'.repeat(64)}),err('RATINGS_ADAPTER_REQUIRED'));
 assert.equal(await rowCount(f,'heads'),0);
}));
test('SQL failure between head and outbox rolls back both and receipt',()=>using(async f=>{
 await f.owner();const prior=await rowCount(f,'outbox');f.repo.inject=point=>{if(point==='afterHeadBeforeOutbox')throw Error('injected crash');};
 await assert.rejects(f.repo.publish(f.claims(f.session),{requestId:'a',snapshot:f.snapshot(),expectedRevision:0}),/injected crash/);
 assert.equal(await rowCount(f,'heads'),0);assert.equal(await rowCount(f,'receipts'),0);assert.equal(await rowCount(f,'outbox'),prior);
}));
test('lost response after SQL commit leaves durable outbox and idempotent receipt',()=>using(async f=>{
 await f.owner();let once=true;f.repo.inject=point=>{if(point==='afterCommit'&&once){once=false;throw Error('lost response');}};
 const q={requestId:'lost',snapshot:f.snapshot(),expectedRevision:0};await assert.rejects(f.repo.publish(f.claims(f.session),q),/lost response/);
 assert.equal(await rowCount(f,'heads'),1);assert.equal(await rowCount(f,'receipts'),1);
 await f.repo.publish(f.claims(f.session),q);await f.publisher.drain();assert.ok(await f.reader.head(f.token(),'client:public'));
}));
test('KV write failure leaves outbox pending; retry succeeds without duplicate HEAD',()=>using(async f=>{
 await f.owner();await f.repo.publish(f.claims(f.session),{requestId:'pub',snapshot:f.snapshot(),expectedRevision:0});
 const put=f.kv.putVersioned.bind(f.kv);f.kv.putVersioned=()=>{throw Error('KV down');};await assert.rejects(f.publisher.drain(),/KV down/);
 assert.ok((await f.repo.pending(16)).length);f.kv.putVersioned=put;await f.publisher.drain();assert.equal((await f.repo.pending(16)).length,0);
 assert.equal(await rowCount(f,'heads'),1);
}));
test('outdated events fetch latest authoritative projection; no revision regression',()=>using(async f=>{
 await f.owner();await f.repo.publish(f.claims(f.session),{requestId:'one',snapshot:f.snapshot(),expectedRevision:0});
 await f.repo.publish(f.claims(f.session),{requestId:'two',snapshot:f.snapshot(2,'Changed synthetic track'),expectedRevision:1});await f.publisher.drain();
 assert.equal((await f.reader.head(f.token(),'client:public')).catalogRevision,2);
 await f.repo.rebuild();await f.publisher.drain();assert.equal((await f.reader.head(f.token(),'client:public')).catalogRevision,2);
}));
test('no CAS or proven writer: publisher STOP, outbox remains recoverable',()=>using(async f=>{
 const kv=new OnrezaKV({get:()=>null,set:()=>assert.fail('unsafe write')},'synthetic26:guard:');
 const publisher=new ProjectionPublisher({repository:f.repo,kv,key:f.projectionKey,clock:f.clock});
 await assert.rejects(publisher.drain(),err('ORDERING_NOT_PROVEN'));assert.equal((await f.repo.pending(16)).length,1);
}));
test('invalidation and namespace-only rebuild do not clear other synthetic tenants',()=>using(async f=>{
 await f.kv.put('other','survives',30);await f.publisher.drain();await f.repo.revoke(f.session.sid);await f.publisher.drain();
 await assert.rejects(f.reader.authenticate(f.token()),err('SESSION_REVOKED'));
 await f.kv.delete('session:'+f.session.sid);await f.repo.rebuild();await f.publisher.drain();
 await assert.rejects(f.reader.authenticate(f.token()),err('SESSION_REVOKED'));assert.equal(await f.kv.get('other'),'survives');
}));
test('adapter TTL, miss, failure, no-CAS and delayed writes contract',async()=>{
 let now=0,release;const delay=new Promise(r=>release=r);let delayed=true;
 const kv=new MemoryKV({namespace:'synthetic26:a:',clock:()=>now,delay:async op=>{if(op==='versioned'&&delayed){delayed=false;await delay;}}});
 assert.equal(await kv.get('x'),null);await assert.rejects(kv.put('x',{},0),err('TTL_REQUIRED'));
 const old=kv.putVersioned('x',1,seal({payload:'old'},Buffer.alloc(32)),30);
 await kv.putVersioned('x',2,seal({payload:'new'},Buffer.alloc(32)),30);release();await old;
 assert.equal(unseal(await kv.get('x'),Buffer.alloc(32)).payload,'new');now=31;assert.equal(await kv.get('x'),null);
 const other=new MemoryKV({namespace:'synthetic26:b:',clock:()=>now});assert.equal(await other.get('x'),null);
});
test('Function portable entry: auth/HEAD match core, no SQL for good or bad requests',()=>using(async f=>{
 await f.owner();await f.repo.publish(f.claims(f.session),{requestId:'pub',snapshot:f.snapshot(),expectedRevision:0});await f.publisher.drain();
 const ports={kv:f.kv,clock:f.clock,env:{P22_ENVIRONMENT:'staging',P22_SYNTHETIC_SESSION_KEY:f.key.toString('base64'),P22_SYNTHETIC_PROJECTION_KEY:f.projectionKey.toString('base64')}};
 const n=f.queries.length;
 const req=path=>new Request('https://staging.invalid'+path,{headers:{Authorization:'Bearer '+f.token()}});
 assert.equal((await light(req('/_staging/session/check'),ports)).status,200);
 const h=await light(req('/_staging/catalog/head'),ports);assert.deepEqual(await h.json(),await f.reader.head(f.token(),'client:public'));assert.equal(f.queries.length,n);
 assert.equal((await light(new Request('https://staging.invalid/_staging/session/check'),ports)).status,401);
 const kv={capabilities:{monotonicWrite:false},get:f.kv.get.bind(f.kv)};
 assert.equal((await (await light(req('/_staging/catalog/head'),{...ports,kv})).json()).error,'ORDERING_NOT_PROVEN');
}));
test('Compute HTTP minimal health, 404/405, bad auth and forged headers no SQL',async()=>{
 let calls=0;const server=createServer(handler({enabled:true,repository:{restore:()=>calls++,publish:()=>calls++},identityKey:Buffer.alloc(32),sessionKey:Buffer.alloc(32)}));
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const url='http://127.0.0.1:'+server.address().port;
 try {
  const h=await fetch(url+'/healthz');assert.equal(h.status,200);assert.deepEqual(await h.json(),{status:'ok',environment:'staging'});
  assert.equal((await fetch(url+'/healthz',{method:'POST'})).status,405);assert.equal((await fetch(url+'/nope')).status,404);
  assert.equal((await fetch(url+'/_staging/catalog/publish',{method:'POST',headers:{'x-user-role':'OWNER'},body:'{}'})).status,401);assert.equal(calls,0);
 }finally{await new Promise(r=>server.close(r));}
});
test('runtime refuses generic DATABASE_URL and production activation',async()=>{
 await assert.rejects(start({P22_STAGING_SYNTHETIC:'enabled',P22_ENVIRONMENT:'production',DATABASE_URL:'unused'}),err('STAGING_CONFIG_REQUIRED'));
});
test('PostgreSQL persistence: synthetic sessions/HEAD/outbox survive close and reopen',async()=>{
 const dir=await mkdtemp('/dev/shm/task26-sql-');const f=await fixture({directory:dir});
 await f.owner();const h=await f.repo.publish(f.claims(f.session),{requestId:'persistent',snapshot:f.snapshot(),expectedRevision:0});const sid=f.session.sid;await f.close();
 const reopened=new PGlite(dir);try {assert.equal((await reopened.query('SELECT sid FROM p22_stage26.sessions')).rows[0].sid,sid);assert.deepEqual((await reopened.query('SELECT payload FROM p22_stage26.heads')).rows[0].payload,h);assert.equal(Number((await reopened.query("SELECT count(*) n FROM p22_stage26.outbox WHERE state='PENDING'")).rows[0].n),2);}finally{await reopened.close();await rm(dir,{recursive:true});}
});
test('lost SQL acknowledgement after KV success replays safely with a persistent pending event',()=>using(async f=>{
 const ack=f.repo.ack.bind(f.repo);let once=true;
 f.repo.ack=async id=>{if(once){once=false;throw Error('ack lost');}await ack(id);};
 await assert.rejects(f.publisher.drain(),/ack lost/);assert.equal((await f.repo.pending(16)).length,1);
 assert.ok(await f.reader.authenticate(f.token()));await f.publisher.drain();assert.equal((await f.repo.pending(16)).length,0);
}));
