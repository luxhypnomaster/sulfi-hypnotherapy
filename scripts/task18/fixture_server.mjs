// TEST ONLY: actual loopback TCP + production JS DOMAIN, NOT Google/GAS runtime.
// Local cross-language integration harness. No Google mocks are called live.
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createServer} from 'node:http';
const ctx=vm.createContext({});
for(const name of ['AtomicStore','Catalog','Access','Transfer','MediaRuntime','Manifest','Diary','Operations'])
 vm.runInContext(readFileSync(new URL('../../server/alchemist/src/'+name+'.js',import.meta.url),'utf8'),ctx);
const sha=x=>createHash('sha256').update(x).digest('hex');
function canonical(v){if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}';return JSON.stringify(v);}
let head=null,n=0,uploaded=0,downloaded=0,verifiedBytes=0; const calls={}; const latency=Number(process.env.PROBE18_LATENCY_MS||0); const sleep=ms=>new Promise(r=>setTimeout(r,ms));const files=new Map(),blobs=new Map();
const io={head:()=>head,read:k=>structuredClone(files.get(k)),writeVerified:v=>{const k='snapshot-'+(++n);files.set(k,structuredClone(v));return k;},setHead:k=>head=k,digest:sha};
const store=ctx.AlchemistAtomicStore.create(io),services={lock:f=>f(),uuid:()=> 'asset-'+(++n),now:()=>0,encode:b=>Buffer.from(b).toString('base64'),decode:s=>Buffer.from(s,'base64'),digest:sha,canonical};
const access=ctx.AlchemistAccess.create(store,()=>0);
const drive={begin:()=>({fileId:'private-'+(++n)}),write:(s,o,b)=>{uploaded+=b.length;const old=blobs.get(s.privateLocation.fileId)||[];if(!Array.isArray(old)||old.reduce((n,v)=>n+v.length,0)!==o)throw Error('OFFSET');old.push(Buffer.from(b));blobs.set(s.privateLocation.fileId,old);return o+b.length;},verify:s=>{let b=blobs.get(s.privateLocation.fileId);if(Array.isArray(b)){b=Buffer.concat(b);blobs.set(s.privateLocation.fileId,b);}const v=s.verification||{offset:0};const next=Math.min(b.length,v.offset+262144);verifiedBytes+=next-v.offset;v.offset=next;s.verification=v;if(next<b.length)return {pending:true,verifiedBytes:next};return {sha256:sha(b),byteLength:b.length,privateFileId:s.privateLocation.fileId};},read:(a,o,n)=>{const b=blobs.get(a.privateLocation.fileId).subarray(o,o+n);downloaded+=b.length;return b;}};
const media=ctx.AlchemistMediaRuntime.create(store,drive,services),manifest=ctx.AlchemistManifest.create(store,services,access);
const catalog=ctx.AlchemistCatalog.create({store,lock:f=>f(),now:()=>new Date(0).toISOString(),digest:x=>sha(JSON.stringify(x)),canReadAsset:access.canRead,validatePublication:access.validatePublication,encodeCursor:JSON.stringify,decodeCursor:JSON.parse});
const diary=ctx.AlchemistDiary.create(catalog,store,{uuid:services.uuid,now:()=>new Date(0).toISOString()});
const operations=ctx.AlchemistOperations.create(store,catalog,services,{getProperty:k=>k==='ALCHEMIST_OWNER_SUB'?'owner':null,setProperty:()=>{throw Error('READONLY_HARNESS')}});
const server=createServer(async(req,res)=>{try{
 if(req.method==='GET'&&req.url==='/stats'){res.end(JSON.stringify({uploaded,downloaded,verifiedBytes,calls,blobs:blobs.size,classification:'CONTROLLED_NATIVE_NO_GOOGLE_NO_GAS'}));return;}
 if(req.headers['x-controlled-transfer18']!=='fixture-only')throw Object.assign(Error('CONTROLLED_HEADER_REQUIRED'),{status:403});
 let raw='';for await(const part of req)raw+=part;const q=JSON.parse(raw),actor=q.credential?.startsWith('CONTROLLED_OWNER_18_')?{sub:'owner',roles:['owner'],exp:Math.floor(Date.now()/1000)+3600}:q.credential?.startsWith('CONTROLLED_CLIENT_18_')?{sub:'controlled-client',roles:['client'],exp:Math.floor(Date.now()/1000)+3600}:null;
 calls[q.operation]=(calls[q.operation]||0)+1; if(['media.uploadChunk','media.downloadChunk'].includes(q.operation)&&latency)await sleep(latency);
 let result;
 if(q.operation==='test.stats')result={uploaded,downloaded,blobs:blobs.size};
 else if(q.operation==='content.registerManifest')result=manifest.execute(q.operation,actor,q.parameters);
 else if(q.operation.startsWith('media.'))result=media[{'media.beginUpload':'begin','media.uploadChunk':'upload','media.commitUpload':'commit','media.getDescriptor':'descriptor','media.downloadChunk':'download','media.finalizeDownload':'finalize'}[q.operation]](actor,q.parameters);
 else if(q.operation==='feed.list'||q.operation.startsWith('entry.'))result=diary.execute(q.operation,actor,q.parameters);
 else if(q.operation.startsWith('auth.')||q.operation.startsWith('sync.'))result=operations.execute(q.operation,actor,q.parameters);
 else result=catalog.execute(q.operation,actor,q.parameters);
 res.end(JSON.stringify({ok:true,status:200,result}));
 }catch(e){res.end(JSON.stringify({ok:false,status:e.status||503,error:{code:e.code||e.message}}));}});
server.listen(Number(process.env.PROBE18_PORT||4018),'127.0.0.1',()=>console.log(server.address().port));
