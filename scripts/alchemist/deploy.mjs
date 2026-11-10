// No Google calls until both OAuth and complete source readiness are proven.
// Never dump environment, raw clasp login output, callback or credentials.
import {existsSync,readFileSync} from 'node:fs';
if (!process.env.CLASPRC_JSON) { console.error('AUTH_PENDING: GITHUB_SECRET_MISSING'); process.exit(78); }
const path=new URL('../../server/alchemist/deployment-readiness.json',import.meta.url);
if(!existsSync(path)||JSON.parse(readFileSync(path,'utf8')).fullSourceVerified!==true){
 console.error('DEPLOY_BLOCKED: FULL_SOURCE_NOT_VERIFIED; no credentials written and no project created');process.exit(78);
}
// A true flag alone is not enough: until full source push/readback/bootstrap /
// smoke implementation is reviewed, this hard guard prevents partial deployment.
console.error('DEPLOY_BLOCKED: DELIVERY_ADAPTER_NOT_COMPLETE');process.exit(78);
