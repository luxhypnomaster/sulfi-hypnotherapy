'use strict';
// Loopback-only synthetic STAGING harness. Never part of a GAS/Android bundle.
if(process.env.SULFI_TEST21_SANDBOX!=='1')throw Error('TEST_SANDBOX_FLAG_REQUIRED');
const http=require('node:http'),crypto=require('node:crypto');
const {SqliteSnapshotStore}=require('../../experimental/sqlite_snapshot_store.cjs');
const {createMetadataRuntime}=require('../../experimental/metadata_runtime.cjs');
const sha=s=>crypto.createHash('sha256').update(s).digest('hex');
const endpoint=process.argv[3];
const actor=(sub,role)=>({sub,binding:sha(endpoint+'|account:'+sha('alchemist:'+endpoint+':'+sub)),roles:[role],scopes:role==='owner'?['master:public','client:public']:['client:public'],expiresAt:Date.now()+3600000});
const owner=actor('synthetic-owner','owner'),client=actor('synthetic-client','client');
const resolveCredential=t=>t==='fixture-owner'?owner:t==='fixture-client'?client:null;
const store=new SqliteSnapshotStore(process.argv[2]),runtime=createMetadataRuntime({store,resolveCredential});
const counts={};let mode='ready',lost=false;
const server=http.createServer(async(req,res)=>{
 let text='';for await(const b of req){text+=b;if(text.length>300000){res.writeHead(413);res.end();return;}}
 let result;
 try{
  const q=JSON.parse(text),op=q.operation,p=q.parameters||{},a=resolveCredential(q.credential);
  counts[op]=(counts[op]||0)+1;
  if(op.startsWith('control.') && a!==owner)result={ok:false,status:403,error:{code:'CONTROL_DENIED'}};
  else if(op==='control.mode'){mode=p.mode;lost=false;result={ok:true,status:200,result:{mode}};}
  else if(op==='control.state')result={ok:true,status:200,result:{counts,mode,catalogHead:store.head('client:public'),configHead:store.head('vitrine:public')}};
  else if(op==='control.seed'){
   store.putRecord({catalogItemId:'card-one',contentId:'module-one',revisionId:'version-'+p.version,type:'module',state:'published',current:true,public:true,title:p.title||'Синтетический модуль',shortAnnotation:'Тестовая аннотация',sha256:'a'.repeat(64),byteLength:0,dependencies:[]});
   for(const scope of owner.scopes)await runtime.catalog.publish(owner,{scope,requestId:'seed-'+p.version+'-'+scope.replace(':','_'),ifRevision:store.head(scope)?.catalogRevision||0});
   result={ok:true,status:200,result:{seeded:true}};
  }else if(op==='auth.whoami')result=a?{ok:true,status:200,result:{subject:a.sub,role:a===owner?'MASTER':'CLIENT',expiresAt:Math.floor(a.expiresAt/1000)}}:{ok:false,status:401,error:{code:'AUTH_REQUIRED'}};
  else if(op==='feed.list')result={ok:true,status:200,result:{entries:[],removedIds:[],revision:'fixture1',nextPage:null}};
  else if(op==='catalog.list')result={ok:true,status:200,result:{items:[],revision:0,nextPage:null}};
  else if(mode==='unsupported' && op==='metadata.capabilities')result={ok:false,status:404,error:{code:'UNKNOWN_OPERATION'}};
  else if(mode==='offline')result={ok:false,status:503,error:{code:'SERVER_UNAVAILABLE'}};
  else if(mode==='denied')result={ok:false,status:403,error:{code:'SCOPE_DENIED'}};
  else {
   result=await runtime.request(q);
   if(mode==='corrupt' && op==='catalog.snapshot' && result.ok)result.result.items[0].title='CORRUPT';
   if(mode==='wrongPrincipal' && op==='metadata.capabilities' && result.ok)result.result.principalBinding='other-binding';
   if(mode==='lostConfigOnce' && op==='vitrine.configCommit' && result.ok && !lost){lost=true;result={ok:false,status:503,error:{code:'SERVER_UNAVAILABLE'}};}
  }
 }catch(_){result={ok:false,status:503,error:{code:'FIXTURE_UNAVAILABLE'}};}
 res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify(result));
});
server.listen(0,'127.0.0.1',()=>console.log(JSON.stringify({port:server.address().port})));
function close(){server.close(()=>{store.close();process.exit(0);});}
process.on('SIGTERM',close);process.on('SIGINT',close);
