'use strict';
// Actual loopback TCP/SQLite, synthetic credentials only. Not production GAS.
if(process.env.SULFI_TEST21_SANDBOX!=='1')throw Error('TEST_SANDBOX_FLAG_REQUIRED');
const http=require('node:http'),crypto=require('node:crypto');
const {SqliteSnapshotStore}=require('../../experimental/sqlite_snapshot_store.cjs');
const {createMetadataRuntime}=require('../../experimental/metadata_runtime.cjs');
const {createProjectRuntime22}=require('../../experimental/project_runtime22.cjs');
const sha=s=>crypto.createHash('sha256').update(s).digest('hex'),endpoint=process.argv[3];
const actor=(sub,role)=>({sub,binding:sha(endpoint+'|account:'+sha('alchemist:'+endpoint+':'+sub)),roles:[role],scopes:role==='owner'?['master:public','client:public']:['client:public'],expiresAt:Date.now()+3600000});
const owner=actor('synthetic-owner','owner'),client=actor('synthetic-client','client'),resolveCredential=t=>t==='fixture-owner'?owner:t==='fixture-client'?client:null;
const store=new SqliteSnapshotStore(process.argv[2]),metadata=createMetadataRuntime({store,resolveCredential});
const verified=t=>{const a=resolveCredential(t);return a?{verified:true,issuer:endpoint,sub:a.sub,binding:a.binding,expiresAt:a.expiresAt}:null};
const project=createProjectRuntime22({baseStore:store,resolveCredential:verified,legacy:metadata}),projectOwner=project.iam.resolve(verified('fixture-owner'));project.iam.bootstrapOwner(projectOwner.uid);
const counts={};let mode='ready',lost=false;
const server=http.createServer(async(req,res)=>{let text='';for await(const b of req){text+=b;if(text.length>300000){res.writeHead(413);res.end();return;}}let result;
 try{const q=JSON.parse(text),op=q.operation,p=q.parameters||{},a=resolveCredential(q.credential);counts[op]=(counts[op]||0)+1;
  if(op.startsWith('control.')&&a!==owner)result={ok:false,status:403,error:{code:'CONTROL_DENIED'}};
  else if(op==='control.mode'){mode=p.mode;lost=false;result={ok:true,status:200,result:{mode}};}
  else if(op==='control.state')result={ok:true,status:200,result:{counts,mode}};
  else if(op==='control.seed'){store.putRecord({catalogItemId:'card-one',contentId:'module-one',revisionId:'version-'+p.version,type:p.type||'module',state:'published',current:true,public:true,title:'Синтетический материал',owner:projectOwner.uid,ratingEpochId:'epoch1',sha256:'a'.repeat(64),byteLength:0,dependencies:[]});for(const scope of owner.scopes)await metadata.catalog.publish(owner,{scope,requestId:'seed-'+p.version+'-'+scope.replace(':','_'),ifRevision:store.head(scope)?.catalogRevision||0});result={ok:true,status:200,result:{seeded:true}};}
  else if(op==='auth.whoami')result=a?{ok:true,status:200,result:{subject:a.sub,role:a===owner?'MASTER':'CLIENT',expiresAt:Math.floor(a.expiresAt/1000)}}:{ok:false,status:401,error:{code:'AUTH_REQUIRED'}};
  else if(op==='feed.list')result={ok:true,status:200,result:{entries:[],removedIds:[],revision:'fixture1',nextPage:null}};
  else if(op==='catalog.list')result={ok:true,status:200,result:{items:[],revision:0,nextPage:null}};
  else if(mode==='offline')result={ok:false,status:503,error:{code:'SERVER_UNAVAILABLE'}};
  else if(mode==='denied')result={ok:false,status:403,error:{code:'SCOPE_DENIED'}};
  else {result=await project.request(q);if(mode==='corrupt'&&op==='ratings.snapshot'&&result.ok)result.result.items[0].consumerDirect.n=999;if(mode==='wrongPrincipal'&&op==='project.capabilities'&&result.ok)result.result.principalBinding='other';if(mode==='lostFeedbackOnce'&&op==='feedback.ingest'&&result.ok&&!lost){lost=true;result={ok:false,status:503,error:{code:'SERVER_UNAVAILABLE'}};}}
 }catch(_){result={ok:false,status:503,error:{code:'FIXTURE_UNAVAILABLE'}};}
 res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify(result));
});
server.listen(0,'127.0.0.1',()=>console.log(JSON.stringify({port:server.address().port})));
function close(){server.close(()=>{store.close();process.exit(0);});}process.on('SIGTERM',close);process.on('SIGINT',close);
