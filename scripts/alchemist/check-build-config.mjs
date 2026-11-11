import {readFileSync} from 'node:fs';
// Configuration consists only of public identifiers; never read CLASPRC here.
const endpoint=process.env.ALCHEMIST_API||'',client=process.env.GOOGLE_WEB_CLIENT_ID||'';
if(!endpoint){console.log('LOCAL_BUILD_ENDPOINT_NOT_CONFIGURED');process.exit(0);}
try{
 const url=new URL(endpoint);
 if(url.protocol!=='https:'||url.host!=='script.google.com'||!/^\/macros\/s\/[\w-]+\/exec$/.test(url.pathname)||url.search||url.hash||url.username||url.password)throw Error();
 const pinned=JSON.parse(readFileSync('server/alchemist/android-oauth-public.json'));
 if(client!==pinned.webClientId)throw Error();
 const response=await fetch(endpoint+'?op=health',{signal:AbortSignal.timeout(20000)}),data=await response.json();
 if(!data.ok||data.status!==200||data.result.name!=='Сервер Проекта Алхимик'||data.result.fullSourceReady!==true||data.result.authorizationPolicyVersion!==2||data.result.webClientId!==client)throw Error();
 console.log('VERIFIED_SERVER_CONFIGURATION');
}catch{console.error('SERVER_CONFIGURATION_UNVERIFIED');process.exit(1);}
