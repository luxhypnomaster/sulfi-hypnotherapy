import {createServer} from 'node:http';
import {pathToFileURL} from 'node:url';
import {sign,verify,secret,fail} from './core/security.mjs';
export function handler({repository,identityKey,sessionKey,enabled=false,clock=()=>Math.floor(Date.now()/1000)}={}) {
 return async function(req,res) {
  const reply=(status,body)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(body));};
  try {
   if(req.url==='/healthz'){if(req.method!=='GET')return reply(405,{error:'METHOD_NOT_ALLOWED'});return reply(200,{status:'ok',environment:'staging'});}
   if(!['/_staging/session/restore','/_staging/catalog/publish'].includes(req.url))return reply(404,{error:'NOT_FOUND'});
   if(req.method!=='POST')return reply(405,{error:'METHOD_NOT_ALLOWED'});
   if(!enabled||!repository)fail('STAGING_SYNTHETIC_DISABLED');
   const bearer=req.headers.authorization?.match(/^Bearer ([A-Za-z0-9_.-]+)$/)?.[1];
   // Validate before reading request body, invoking SQL, or trusting forwarded headers.
   const isRestore=req.url.endsWith('/restore');
   const claims=verify(bearer,isRestore?identityKey:sessionKey,{issuer:isRestore?'urn:alchemist:synthetic-idp':'urn:alchemist:staging26',audience:isRestore?'staging26-bootstrap':'protocol22-staging',kind:isRestore?'identity':'session',clock});
   let body='';for await(const b of req){body+=b.toString();if(Buffer.byteLength(body)>32768)fail('BODY_TOO_LARGE',413);}
   let q;try {q=JSON.parse(body);}catch {fail('INVALID_JSON',422);}
   if(isRestore){const s=await repository.restore(claims,q.installationId,q.requestId,{allowNew:true});return reply(200,{token:sign({iss:'urn:alchemist:staging26',aud:'protocol22-staging',kind:'session',sub:s.uid,sid:s.sid,iid:s.iid,rv:s.roleVersion,scopes:s.scopes,iat:clock(),exp:s.expiresAt},sessionKey)});}
   return reply(200,await repository.publish(claims,q));
  }catch(e){const status=e.status||503;return reply(status,{error:e.code||'STAGING_UNAVAILABLE'});}
 };
}
export async function start(env=process.env) {
 let repository,identityKey,sessionKey;
 const enabled=env.P22_STAGING_SYNTHETIC==='enabled';
 if(enabled){
  if(env.P22_ENVIRONMENT!=='staging'||!env.P22_STAGE26_DATABASE_URL)fail('STAGING_CONFIG_REQUIRED');
  identityKey=secret(env.P22_SYNTHETIC_IDENTITY_KEY);sessionKey=secret(env.P22_SYNTHETIC_SESSION_KEY);
  if(identityKey.equals(sessionKey))fail('DISTINCT_KEYS_REQUIRED');
  const {Pool}=await import('pg');const {PostgresRepository}=await import('./adapters/postgres.mjs');
  repository=new PostgresRepository(new Pool({connectionString:env.P22_STAGE26_DATABASE_URL,max:2,connectionTimeoutMillis:5000,idleTimeoutMillis:1000}));
  // Migrations are explicit, never run on startup or against a generic DATABASE_URL.
 }
 const server=createServer(handler({repository,identityKey,sessionKey,enabled}));
 const port=Number(env.PORT||3000);if(!Number.isSafeInteger(port)||port<1||port>65535)fail('INVALID_PORT');
 server.listen(port,'0.0.0.0');return server;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)start().catch(()=>{console.error('STAGING_START_FAILED');process.exitCode=1;});
