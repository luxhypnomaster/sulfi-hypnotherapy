import {PGlite} from '@electric-sql/pglite';
import {randomBytes} from 'node:crypto';
import {PostgresRepository} from '../adapters/postgres.mjs';
import {MemoryKV} from '../adapters/kv.mjs';
import {ProjectionPublisher} from '../core/publisher.mjs';
import {createReader} from '../core/reader.mjs';
import {sign} from '../core/security.mjs';
export async function fixture({directory,inject=()=>{}}={}) {
 const db=new PGlite(directory),queries=[];
 const client={query:async(text,args)=>{queries.push(text);return args===undefined?(await db.exec(text)).at(-1):db.query(text,args);},release(){}};
 const pool={query:client.query,connect:async()=>client};
 let now=1795600000;
 const clock=()=>now,key=randomBytes(32),projectionKey=randomBytes(32),identityKey=randomBytes(32);
 const repo=new PostgresRepository(pool,{clock,inject});await repo.migrate();
 const kv=new MemoryKV({namespace:'synthetic26:test:',clock});
 const publisher=new ProjectionPublisher({repository:repo,kv,key:projectionKey,clock});
 const proof=(sub='synthetic-alice')=>({iss:'urn:alchemist:synthetic-idp',aud:'staging26-bootstrap',sub,kind:'identity',iat:now,exp:now+300});
 const session=await repo.restore(proof(),'installation_a','login_a',{allowNew:true});
 const claims=s=>({iss:'urn:alchemist:staging26',aud:'protocol22-staging',sub:s.uid,sid:s.sid,iid:s.iid,rv:s.roleVersion,scopes:s.scopes,kind:'session',iat:now,exp:s.expiresAt});
 const reader=createReader({kv,sessionKey:key,projectionKey,clock});
 const snapshot=(revision=1,title='Synthetic track')=>({schemaVersion:1,scope:'client:public',catalogRevision:revision,createdAt:new Date(now*1000).toISOString(),items:[{contentId:'synthetic-track',revisionId:'r1',sha256:'a'.repeat(64),dependencies:[],title}]});
 const owner=async()=>{await pool.query("UPDATE p22_stage26.authority SET role='OWNER' WHERE uid=$1",[session.uid]);};
 return {db,pool,repo,key,identityKey,projectionKey,kv,publisher,proof,session,claims,reader,snapshot,clock,advance:s=>{now+=s;},owner,token:()=>sign(claims(session),key),queries,close:()=>db.close()};
}
