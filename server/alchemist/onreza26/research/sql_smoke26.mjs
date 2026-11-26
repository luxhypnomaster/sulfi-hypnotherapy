// Synthetic managed-SQL smoke. Connection secret is process env only; never log it.
import {Pool} from 'pg';
import {randomUUID,createHash} from 'node:crypto';
import {PostgresRepository} from '../adapters/postgres.mjs';
import {checkSession} from '../core/security.mjs';
const checks=[],started=Date.now();let pool,phase='configuration';
try {
 if(process.env.P22_ENVIRONMENT!=='staging'||!process.env.P22_STAGE26_DATABASE_URL)throw Error('STAGING_REQUIRED');
 const uri=new URL(process.env.P22_STAGE26_DATABASE_URL);for(const k of ['sslmode','sslcert','sslkey','sslrootcert'])uri.searchParams.delete(k);
 pool=new Pool({connectionString:uri.href,max:1,connectionTimeoutMillis:20000,idleTimeoutMillis:1000,ssl:{rejectUnauthorized:true,servername:uri.hostname}});
 phase='connect';const version=(await pool.query('SHOW server_version_num')).rows[0].server_version_num;
 checks.push({name:'managed-postgresql-connection',status:'PASS',majorVersion:Math.floor(Number(version)/10000)});
 const repo=new PostgresRepository(pool);phase='migration';await repo.migrate();checks.push({name:'additive-staging-schema',status:'PASS'});
 const now=Math.floor(Date.now()/1000),proof={iss:'urn:alchemist:synthetic-idp',aud:'staging26-bootstrap',kind:'identity',sub:'synthetic-task26-live-smoke',iat:now,exp:now+300};
 phase='identity';const session=await repo.restore(proof,'synthetic26-live-install',randomUUID(),{allowNew:true});
 const repeated=await repo.restore(proof,'synthetic26-live-install',randomUUID(),{allowNew:true});
 if(repeated.uid!==session.uid)throw Error('UID_CHANGED');checks.push({name:'stable-issuer-sub-identity-and-installation',status:'PASS'});
 await pool.query("UPDATE p22_stage26.authority SET role='OWNER' WHERE uid=$1",[session.uid]);
 const claims={sub:session.uid,sid:session.sid,iid:session.iid,rv:session.roleVersion,scopes:session.scopes};
 const row=(await pool.query('SELECT payload FROM p22_stage26.heads WHERE scope=$1',['client:public'])).rows[0];
 const revision=row?.payload.catalogRevision||0;
 const snap={schemaVersion:1,scope:'client:public',catalogRevision:revision+1,createdAt:new Date().toISOString(),items:[{contentId:'synthetic-onreza-live-track',revisionId:'r1',sha256:createHash('sha256').update('synthetic-onreza-track').digest('hex'),dependencies:[],title:'Synthetic ONREZA smoke track'}]};
 const q={requestId:randomUUID(),snapshot:snap,expectedRevision:revision};phase='publication';const h=await repo.publish(claims,q),again=await repo.publish(claims,q);
 if(h.snapshotHash!==again.snapshotHash)throw Error('RECEIPT_CHANGED');checks.push({name:'verified-head-and-idempotent-receipt',status:'PASS'});
 const n=Number((await pool.query('SELECT count(*) n FROM p22_stage26.outbox')).rows[0].n);if(n<1)throw Error('OUTBOX_MISSING');checks.push({name:'durable-outbox-after-commit',status:'PASS'});
 phase='rollback';repo.inject=point=>{if(point==='afterHeadBeforeOutbox')throw Error('CONTROLLED_CRASH');};
 const changed=structuredClone(snap);changed.catalogRevision=h.catalogRevision+1;changed.items[0].title='Synthetic rollback probe';
 let rejected=false;try{await repo.publish(claims,{requestId:randomUUID(),snapshot:changed,expectedRevision:h.catalogRevision});}catch(e){if(e.message!=='CONTROLLED_CRASH')throw e;rejected=true;}
 const after=(await pool.query('SELECT payload FROM p22_stage26.heads WHERE scope=$1',['client:public'])).rows[0].payload;
 if(!rejected||after.snapshotHash!==h.snapshotHash||Number((await pool.query('SELECT count(*) n FROM p22_stage26.outbox')).rows[0].n)!==n)throw Error('NON_ATOMIC_ROLLBACK');
 checks.push({name:'real-sql-head-outbox-rollback',status:'PASS'});repo.inject=()=>{};
 phase='revoke';await repo.revoke(session.sid);let denied=false;try{checkSession(await repo.session(session.sid),claims,now);}catch(e){denied=e.code==='SESSION_REVOKED';}if(!denied)throw Error('REVOKE_BYPASS');checks.push({name:'authoritative-revocation',status:'PASS'});
 phase='reconnect';await pool.end();pool=new Pool({connectionString:uri.href,max:1,connectionTimeoutMillis:20000,idleTimeoutMillis:1000,ssl:{rejectUnauthorized:true,servername:uri.hostname}});
 const persisted=(await pool.query('SELECT payload FROM p22_stage26.heads WHERE scope=$1',['client:public'])).rows[0].payload;
 if(persisted.snapshotHash!==h.snapshotHash)throw Error('PERSISTENCE_FAILED');checks.push({name:'head-survives-connection-reopen',status:'PASS'});
 console.log(JSON.stringify({status:'PASS',level:'LIVE_MANAGED_SQL_SYNTHETIC',checks,elapsedMs:Date.now()-started,physicalAndroid:false,GoogleAuth:false}));
} catch(e){console.log(JSON.stringify({status:'BLOCKED',phase,errorCode:typeof e.code==='string'&&/^[A-Z0-9_]{1,60}$/.test(e.code)?e.code:'SQL_SMOKE_FAILED',checks,elapsedMs:Date.now()-started,secretsLogged:false}));process.exitCode=2;}
finally{if(pool)await pool.end().catch(()=>{});}
