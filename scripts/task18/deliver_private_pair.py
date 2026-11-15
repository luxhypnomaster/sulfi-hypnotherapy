"""Append verified candidates to an EXISTING private draft; never publish/create/tag/clobber."""
import argparse,hashlib,json,os,pathlib,subprocess
REPO='luxhypnomaster/sulfi-hypnotherapy';SOURCE='59c3667a28357767533b25e92661b87d081d7227';RELEASE=445425835
BASE={'master27.apk':(748058133,'2bb394232b631d0b6498b9b6ef6e7846a2be60b1be914b287d6bcf35593f35eb'),'client27.apk':(748058137,'8e3ddaa19a37fbc5ab66474800ae4d6f3ec5ae937eb08909a4c8bd08831fdd46'),'APK_PAIR_17.json':(748058143,'51636ab3170a66e4d00fa888359873ac597dc71193b42e9dbe6551bffa78cafd')}
EXPECTED={'master':'78fb218edc59b2ddf761cda38e6faaf76e6bcea9b5bea6ab6e0b5a995b8b7767','client':'e9fa12f7fd5e9a08e55eec163b2f2d1e6eaed2c260e105226429774e4d0ef821'}
CERT='0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6'
p=argparse.ArgumentParser();p.add_argument('--execute',action='store_true');args=p.parse_args()
assert os.environ['GITHUB_REPOSITORY']==REPO and os.environ['GITHUB_REF']=='refs/heads/feat/task18-native-background-transfer'
def api(path):
 r=subprocess.run(['gh','api','repos/'+REPO+'/'+path],capture_output=True,text=True);assert r.returncode==0,'GITHUB_READ_FAILED';return json.loads(r.stdout)
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def release():
 assert api('')['private'] is True,'REPOSITORY_NOT_PRIVATE_STOP'
 r=api('releases/'+str(RELEASE));assert r['draft'] is True and r['target_commitish']=='fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568','DRAFT_CHANGED_STOP'
 by={a['name']:a for a in r['assets']}
 for name,(i,digest) in BASE.items():assert by[name]['id']==i and by[name]['digest']=='sha256:'+digest,'ORIGINAL27_ASSET_CHANGED_STOP'
 return r
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task18-apks'
manifest=json.loads((root/'QUARANTINE_PAIR_18.json').read_text());assert manifest['source']==SOURCE
for e in EXPECTED:assert sha(root/(e+'28.apk'))==EXPECTED[e],'CANDIDATE_BYTES_CHANGED_STOP'
r=release();gate=pathlib.Path('reports/task18/DELIVERY_GATE_18.json')
preview={'source':SOURCE,'existingDraft':RELEASE,'operation':'APPEND_NEW_ASSETS_ONLY_NO_CREATE_PUBLISH_TAG_OR_CLOBBER','old27Assets':'PRESERVED','DriveUpload':'NOT_PERFORMED','GooglePhysicalQA':'NOT_RUN','gate':'MISSING' if not gate.exists() else 'PRESENT','execute':args.execute}
print('PRIVATE_APK_DELIVERY_PREVIEW='+json.dumps(preview))
if not args.execute:raise SystemExit(0)
assert gate.exists(),'SAFETY_GATE_MISSING_STOP'
g=json.loads(gate.read_text());assert g['source']==SOURCE and g['status']=='PASS_NATIVE_SAFE_FOR_OWNER_QA','SAFETY_NOT_PASSED_STOP'
assert set(g['evidence'])=={'master_upgrade','client_upgrade','api33','api34','api35','api36'},'INCOMPLETE_GATES_STOP'
for key,item in g['evidence'].items():
 run=api('actions/runs/'+str(item['run']));assert run['head_branch']=='feat/task18-native-background-transfer' and run['head_sha']==item['driverSource'] and run['event']=='workflow_dispatch'
 jobs=api('actions/runs/'+str(item['run'])+'/jobs?per_page=100')['jobs']
 assert any(j['name']==item['job'] and j['conclusion']=='success' for j in jobs),'REAL_PASSED_JOB_REQUIRED:'+key
 receipt=json.loads(pathlib.Path(item['receipt']).read_text())
 assert receipt.get('source',receipt.get('appSource'))==SOURCE,'RECEIPT_SOURCE_MISMATCH'
 assert all(c['status']=='PASS' for c in receipt['cases']),'FAILED_RECEIPT_CANNOT_DELIVER'
tools=sorted((pathlib.Path(os.environ['ANDROID_HOME'])/'build-tools').glob('*/apksigner'))[-1]
files=[]
for e in ['master','client']:
 name='alchemist-'+e+'28-task18-59c3667.apk';before=release();by={a['name']:a for a in before['assets']}
 if name in by:a=by[name]
 else:
  r=subprocess.run(['gh','api','--method','POST','-H','Content-Type: application/vnd.android.package-archive','https://uploads.github.com/repos/'+REPO+'/releases/'+str(RELEASE)+'/assets?name='+name,'--input',str(root/(e+'28.apk'))],capture_output=True,text=True)
  assert r.returncode==0,'PRIVATE_ASSET_UPLOAD_FAILED_NO_DELETE_OR_CLOBBER';a=json.loads(r.stdout)
 assert a['digest']=='sha256:'+EXPECTED[e],'UPLOADED_DIGEST_MISMATCH'
 downloaded=root/(e+'28-independent-private-readback.apk')
 with downloaded.open('wb') as f:
  result=subprocess.run(['gh','api','-H','Accept: application/octet-stream','repos/'+REPO+'/releases/assets/'+str(a['id'])],stdout=f,stderr=subprocess.PIPE)
 assert result.returncode==0 and sha(downloaded)==EXPECTED[e],'INDEPENDENT_DOWNLOAD_SHA_FAILED'
 verify=subprocess.run([str(tools),'verify','--print-certs',str(downloaded)],capture_output=True,text=True)
 assert verify.returncode==0 and CERT in verify.stdout,'INDEPENDENT_CERT_FAILED'
 files.append({'edition':e,'assetId':a['id'],'name':name,'url':a['browser_download_url'],'sha256':EXPECTED[e],'certificateSHA256':CERT,'bytes':downloaded.stat().st_size})
release() # original27 assets + draft/privacy must still be unchanged
value={'source':SOURCE,'version':'0.4.20+28','pair':files,'status':'PRIVATE_CANDIDATES_FOR_OWNER_QA','nativeSafety':'PASS_CONTROLLED_NOT_PHYSICAL','GooglePhysicalQA':'NOT_RUN','releasePublished':False,'existingDraftOnly':RELEASE,'original27':'UNCHANGED','DriveUpload':'NOT_PERFORMED'}
(root/'APK_PAIR_18.json').write_text(json.dumps(value,indent=2)+'\n');print('APK_PAIR_18='+json.dumps(value))
