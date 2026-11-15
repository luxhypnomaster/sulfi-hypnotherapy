"""Native Android SQLite queue conversion only; no OS transfer/Google/API upgrade claim."""
import hashlib,json,os,pathlib,time
from probe_native import OUT,ROOT,adb,tree,click,launch,system_ui_preflight,shot
cases=[]
try:
 ready=json.loads(pathlib.Path('.task17-sdk-ready.json').read_text());assert ready['version']=='37.2.12' and ready['validatedHeadlessVersion']
 assert adb('shell','getprop','ro.kernel.qemu').strip()=='1'
 adb('shell','wm','size','720x1280');adb('shell','wm','density','280')
 adb('install','-r',str(pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-ui-probe/probe.apk'));system_ui_preflight()
 for edition,suffix in [('master',''),('client','.clienttest')]:
  pkg='ru.sulfi.sulfi_hypnotherapy'+suffix+'.transferprobe'
  assert 'Success' in adb('install','-r','-t',str(ROOT/(edition+'.apk')))
  launch(pkg)
  try:previous=json.loads(adb('shell','run-as',pkg,'cat','files/native-legacy-queue18.json',check=False)).get('checkedAtMs',0)
  except json.JSONDecodeError:previous=0
  click('RUN LEGACY QUEUE CHECK')
  until=time.monotonic()+60;v=None
  while time.monotonic()<until:
   raw=adb('shell','run-as',pkg,'cat','files/native-legacy-queue18.json',check=False)
   try:v=json.loads(raw)
   except json.JSONDecodeError:time.sleep(1);continue
   if v.get('checkedAtMs',0)<=previous:v=None;time.sleep(1);continue
   break
  assert v is not None,'NATIVE_QUEUE_CONVERSION_DID_NOT_RETURN_A_RECEIPT'
  assert v['status']=='PASS' and v['classification']=='CONTROLLED_NATIVE_ANDROID_SQLITE_OLD27_SHAPE'
  assert v['sqliteUserVersion']==9 and v['integrity']=='ok'
  assert all(v[k] is True for k in ['runningAndQueuedConvertToPolicyWait','noLegacyAutoDispatch','userPausedForeignAndUnboundExactBytes','foreignResumeDenied','sameTaskBytesAttemptsRequestETagAndUploadSession'])
  assert v['dispatch']=='CONTROLLED_NO_NETWORK_NOT_OS_WORKER_PROOF' and v['realGoogle']=='NOT_RUN'
  (OUT/(edition+'-native-queue-conversion.json')).write_text(json.dumps(v,indent=2)+'\n');shot(edition+'-native-queue-conversion')
  cases.append({'edition':edition,'status':'PASS_NATIVE_SQLITE_CONTROLLED_CONVERSION','normalApkUpgrade':'SEPARATE_43708103115','Google':'NOT_RUN'})
except Exception as e:
 cases.append({'status':'BLOCKED','reason':str(e)[:1000],'type':type(e).__name__});shot('legacy-queue-failure')
finally:
 v={'appSource':os.environ.get('TASK18_PROBE_APP_SOURCE'),'driverSource':os.environ['GITHUB_SHA'],'classification':'CONTROLLED_NATIVE_SQLITE_NOT_GOOGLE_OR_PHONE','cases':cases}
 (OUT/'NATIVE_LEGACY_QUEUE_18.json').write_text(json.dumps(v,indent=2)+'\n');print('NATIVE_LEGACY_QUEUE_18='+json.dumps(v))
assert len(cases)==2 and all(c['status']=='PASS_NATIVE_SQLITE_CONTROLLED_CONVERSION' for c in cases),'NATIVE_LEGACY_QUEUE_GATE_BLOCKED'
