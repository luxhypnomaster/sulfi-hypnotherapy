// Local cross-language integration harness. No Google mocks are called live.
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createServer} from 'node:http';
const ctx=vm.createContext({});
for(const name of ['AtomicStore','Catalog','Access','Transfer','MediaRuntime','Manifest'])
 vm.runInContext(readFileSync(new URL('../../src/'+name+'.js',import.meta.url),'utf8'),ctx);
const sha=x=>createHash('sha256').update(x).digest('hex');
function canonical(v){if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}';return JSON.stringify(v);}
let head=null,n=0,uploaded=0,downloaded=0;const files=new Map(),blobs=new Map();
const io={head:()=>head,read:k=>structuredClone(files.get(k)),writeVerified:v=>{const k='snapshot-'+(++n);files.set(k,structuredClone(v));return k;},setHead:k=>head=k,digest:sha};
const store=ctx.AlchemistAtomicStore.create(io),services={lock:f=>f(),uuid:()=> 'asset-'+(++n),now:()=>0,encode:b=>Buffer.from(b).toString('base64'),decode:s=>Buffer.from(s,'base64'),digest:sha,canonical};
const access=ctx.AlchemistAccess.create(store,()=>0);
const drive={begin:()=>({fileId:'private-'+(++n)}),write:(s,o,b)=>{uploaded+=b.length;const old=blobs.get(s.privateLocation.fileId)||Buffer.alloc(0);if(old.length!==o)throw Error('OFFSET');blobs.set(s.privateLocation.fileId,Buffer.concat([old,b]));return o+b.length;},verify:s=>{const b=blobs.get(s.privateLocation.fileId);return {sha256:sha(b),byteLength:b.length,privateFileId:s.privateLocation.fileId};},read:(a,o,n)=>{const b=blobs.get(a.privateLocation.fileId).subarray(o,o+n);downloaded+=b.length;return b;}};
const media=ctx.AlchemistMediaRuntime.create(store,drive,services),manifest=ctx.AlchemistManifest.create(store,services,access);
const catalog=ctx.AlchemistCatalog.create({store,lock:f=>f(),now:()=>new Date(0).toISOString(),digest:x=>sha(JSON.stringify(x)),canReadAsset:access.canRead,validatePublication:access.validatePublication,encodeCursor:JSON.stringify,decodeCursor:JSON.parse});
const server=createServer(async(req,res)=>{try{
 let raw='';for await(const part of req)raw+=part;const q=JSON.parse(raw),actor=q.credential==='TEST_OWNER'?{sub:'owner',roles:['owner']}:null;
 let result;
 if(q.operation==='test.stats')result={uploaded,downloaded,blobs:blobs.size};
 else if(q.operation==='content.registerManifest')result=manifest.execute(q.operation,actor,q.parameters);
 else if(q.operation.startsWith('media.'))result=media[{'media.beginUpload':'begin','media.uploadChunk':'upload','media.commitUpload':'commit','media.getDescriptor':'descriptor','media.downloadChunk':'download','media.finalizeDownload':'finalize'}[q.operation]](actor,q.parameters);
 else result=catalog.execute(q.operation,actor,q.parameters);
 res.end(JSON.stringify({ok:true,status:200,result}));
 }catch(e){res.end(JSON.stringify({ok:false,status:e.status||503,error:{code:e.code||e.message}}));}});
server.listen(0,'127.0.0.1',()=>console.log(server.address().port));
