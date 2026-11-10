import vm from 'node:vm';import {test} from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {createHash} from 'node:crypto';
test('actual GAS adapter uses private resumable PUT and bounded authenticated ranges, serializable verification',()=>{
 let data=Buffer.alloc(0),privateAcl=true;const calls=[];
 const c=vm.createContext({ScriptApp:{getOAuthToken:()=> 'INTERNAL_FIXTURE_TOKEN'},Utilities:{getUuid:()=> 'fixture',newBlob:b=>({getBytes:()=>b})},AlchemistGasFiles:{privateFolder:()=>{if(!privateAcl)throw Error('ACL_DENIED');}},Drive:{Files:{get:()=>({id:'opaque',size:String(data.length),mimeType:'video/mp4',parents:['private-folder']})}},UrlFetchApp:{fetch:(url,o)=>{
 calls.push({url,o});let status=200,headers={},body={};let bytes=[];
 if(url.includes('uploadType=resumable'))headers.Location='https://www.googleapis.com/upload/drive/v3/files?upload_id=opaque';
 else if(o.method==='put'){data=Buffer.from(o.payload.map(b=>b&255));body={id:'opaque'};}
 else {assert.equal(o.headers.Range,'bytes=0-131071');status=206;bytes=Array.from(data);}
 return {getResponseCode:()=>status,getAllHeaders:()=>headers,getContentText:()=>JSON.stringify(body),getBlob:()=>({getBytes:()=>bytes})};}}});
 for(const file of ['Catalog','Sha256','GasTransfer'])vm.runInContext(readFileSync(new URL('../src/'+file+'.js',import.meta.url),'utf8'),c);
 const adapter=c.AlchemistGasTransfer.create('private-folder','owner@example.invalid');
 const s={byteLength:131072,mime:'video/mp4'};s.privateLocation=adapter.begin(s);const bytes=Array.from(Buffer.alloc(131072,123));assert.equal(adapter.write(s,0,bytes),131072);
 const verified=adapter.verify(s);assert.equal(verified.sha256,createHash('sha256').update(Buffer.from(bytes)).digest('hex'));assert.equal(verified.byteLength,131072);
 assert.equal(calls.filter(x=>x.o.method==='get').length,1);assert.ok(calls.every(x=>x.o.headers.Authorization==='Bearer INTERNAL_FIXTURE_TOKEN'));assert.equal(calls[1].o.headers['Content-Range'],'bytes 0-131071/131072');
 privateAcl=false;assert.throws(()=>adapter.read(s,0,1),/ACL_DENIED/);
});
