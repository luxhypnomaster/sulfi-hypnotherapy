"""Deterministic RPC budget, not an unstable timing/speed guarantee or GAS proof."""
import argparse,json,pathlib,re
p=argparse.ArgumentParser();p.add_argument('reports',nargs='+');args=p.parse_args()
for name in args.reports:
 v=json.loads(pathlib.Path(name).read_text())
 assert v['classification']=='CONTROLLED_REAL_LOOPBACK_TCP_PRODUCTION_JS_DOMAIN'
 assert v['GAS']==v['Google']==v['WiFi']=='NOT_RUN'
 assert [r['MiB'] for r in v['results']]==[1,15,50]
 for r in v['results']:
  assert r['status']=='PASS_CONTROLLED_TCP' and r['bytes']==r['MiB']*1024*1024
  assert re.fullmatch('[a-f0-9]{64}',r['sha256'])
  chunks=r['bytes']//262144
  assert r['uploadRpcCount']=={'media.beginUpload':1,'media.uploadChunk':chunks,'media.commitUpload':chunks},'UPLOAD_RPC_BUDGET_REGRESSION'
  assert r['downloadRpcCount']=={'media.getDescriptor':1,'media.downloadChunk':chunks,'media.finalizeDownload':1},'DOWNLOAD_RPC_BUDGET_REGRESSION'
 print(json.dumps({'report':pathlib.Path(name).name,'status':'PASS_DETERMINISTIC_RPC_BUDGET','sizesMiB':[1,15,50],'latencyGuarantee':False,'liveDriveAclCost':'NOT_MEASURED'}))
