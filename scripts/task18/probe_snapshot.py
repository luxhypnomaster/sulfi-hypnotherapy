"""Read-only native SQLite/WAL snapshot of DISPOSABLE fixtures, never an owner app."""
import hashlib,io,json,pathlib,sqlite3,subprocess,tarfile,tempfile

def snapshot(pkg):
 assert pkg in ['ru.sulfi.sulfi_hypnotherapy.transferprobe','ru.sulfi.sulfi_hypnotherapy.clienttest.transferprobe']
 assert subprocess.check_output(['adb','shell','getprop','ro.kernel.qemu'],text=True).strip()=='1','FIXTURE_EMULATOR_REQUIRED'
 raw=subprocess.run(['adb','exec-out','run-as',pkg,'tar','cf','-','files'],capture_output=True,timeout=40)
 if raw.returncode:raise RuntimeError('FIXTURE_SNAPSHOT_TAR_NOT_QUIESCENT')
 files={}
 with tempfile.TemporaryDirectory() as td:
  root=pathlib.Path(td)
  with tarfile.open(fileobj=io.BytesIO(raw.stdout)) as z:
   for m in z:
    if not m.isfile():continue
    if m.name in ['files/library.sqlite','files/library.sqlite-wal','files/library.sqlite-shm','files/library.sqlite-journal']:
     (root/pathlib.Path(m.name).name).write_bytes(z.extractfile(m).read())
    elif m.name.startswith('files/audio/'):
     b=z.extractfile(m).read();files[m.name]={'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
  assert (root/'library.sqlite').exists(),'EXISTING_SQLITE_REQUIRED'
  db=sqlite3.connect('file:'+str(root/'library.sqlite')+'?mode=ro',uri=True)
  integrity=db.execute('pragma integrity_check').fetchone()[0]
  assert integrity=='ok','READONLY_COPY_INTEGRITY_NOT_PROVEN'
  workkeys=['phase','state','stage','code','pauseReason','taskId','revision','bytes','totalBytes','attempts','runnerEpoch','executor','autoResume','networkRetries','jobRetries','retryAtMs']
  queues={};uploads={};downloads={}
  for name,value in db.execute("select name,value from app_settings where name like 'alchemist_card:%' or name like 'alchemist_download:%' or name like 'alchemist_upload:%' or name like 'alchemist_download_checkpoint:%'"):
   v=json.loads(value)
   if name.startswith('alchemist_upload:'):
    uploads[name]={k:v.get(k) for k in ['ownerBinding','sessionId','requestId','offset','receipt']}
   elif name.startswith('alchemist_download_checkpoint:'):
    downloads[name]={k:v.get(k) for k in ['ownerBinding','assetRevisionId','sha256','byteLength','offset','verified','receipt']}
    downloads[name]['recordedChunks']=len(v.get('chunks',[]))
   else:
    w=v.get('_work',{});p=v.get('pending',{})
    queues[name]={'ownerBinding':v.get('ownerBinding'),'work':{k:w.get(k) for k in workkeys},
      'pending':{'operation':p.get('operation'),'requestId':p.get('parameters',{}).get('requestId'),'ifMatch':p.get('parameters',{}).get('ifMatch')},
      'lastReceipt':v.get('lastReceipt')}
  assets=[{'id':r[0],'filePath':r[1],'sha256':r[2],'bytes':r[3]} for r in db.execute('select id,filePath,contentHash,fileSizeBytes from audio_assets')]
  version=db.execute('pragma user_version').fetchone()[0];db.close()
  return {'classification':'DISPOSABLE_CONTROLLED_NATIVE_READONLY_COPY','schema':version,'integrity':integrity,'queues':queues,'uploads':uploads,'downloadCheckpoints':downloads,'assets':assets,'sourceFiles':files}
