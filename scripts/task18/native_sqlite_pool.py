"""No Flutter bootstrap: execute only actual APK native pool classes on isolated DBs."""
import json,os,pathlib,re,subprocess
root=pathlib.Path(os.environ['RUNNER_TEMP']);out=root/'task18-probe-evidence';out.mkdir(exist_ok=True)
pkg='ru.sulfi.sulfi_hypnotherapy.transferprobe'
def adb(*a):return subprocess.check_output(['adb',*a],timeout=55)
assert adb('shell','getprop','ro.kernel.qemu').strip()==b'1'
assert b'Success' in adb('install','-r','-t',str(root/'task18-probe-apks/master.apk'))
# pm path/read-as-UID only; MainActivity/Flutter/real library.sqlite are never opened.
apk=adb('shell','pm','path',pkg).decode().strip().removeprefix('package:');assert apk.startswith('/data/app/') and apk.endswith('/base.apk')
# run-as needs app files directory; create only this exact disposable package's directory.
adb('shell','run-as',pkg,'mkdir','-p','files')
jar=(root/'task18-sqlite-probe/native-pool.jar').read_bytes()
r=subprocess.run(['adb','shell','-T','run-as',pkg,'tee','files/native-pool18.jar'],input=jar,capture_output=True,timeout=30);assert r.returncode==0 and r.stdout==jar
adb('shell','run-as',pkg,'chmod','400','files/native-pool18.jar')
cases=[]
# Original zero-timeout1/4 failures are retained separately. Isolate the
# bounded busy handler interaction with the same actual shipped pool classes.
for count in [1]:
 command=['adb','shell','run-as',pkg,'env','CLASSPATH=/data/user/0/'+pkg+'/files/native-pool18.jar:'+apk,'app_process','/system/bin','org.alchemist.p0probe.NativePoolProbe',pkg,str(count),'0']
 result=subprocess.run(command,capture_output=True,timeout=55)
 raw=result.stdout.decode(errors='replace')
 if result.returncode:
  def diagnostic(*args):
   try:return adb(*args).decode(errors='replace')[-24000:]
   except Exception as error:return type(error).__name__
  failure={'classification':'DISPOSABLE_NATIVE_PROCESS_EXIT_NOT_A_CAUSAL_PASS','exit':result.returncode,'stdoutStages':raw[-5000:],'stderr':result.stderr.decode(errors='replace')[-1500:],
   'events':diagnostic('logcat','-d','-b','events','-t','180'),
   'activityAndLMK':diagnostic('logcat','-d','-s','lmkd','ActivityManager','AndroidRuntime','-t','200'),
   'memory':diagnostic('shell','dumpsys','meminfo','-s')}
  (out/'NATIVE_PROCESS_EXIT_18.json').write_text(json.dumps(failure,indent=2)+'\n')
  raise AssertionError('NATIVE_PROCESS_EXIT_'+str(result.returncode)+'_SEE_READONLY_DIAGNOSTICS')
 match=re.search(r'^NATIVE_POOL18=(\{.*\})$',raw,re.M);assert match,'NO_NATIVE_POOL_RECEIPT:'+raw[-1000:]
 v=json.loads(match[1]);(out/('native-pool-'+str(count)+'.json')).write_text(json.dumps(v,indent=2)+'\n')
 assert v['productionDatabaseOpened'] is False and v['pool']==count and v['busyTimeoutMs']==0
 assert not v['errors'] and v['status']=='BOTH_COMMITS_COMPLETE' and v['rows']==2 and v['integrity']=='ok','CANDIDATE_SERIAL_SCHEDULER_FAILED'
 cases.append({'pool':count,'status':'PASS_CAUSAL_NATIVE_EXPERIMENT','observed':v['status']})
v={'driverSource':os.environ['GITHUB_SHA'],'appSource':'ef50fc5dceb849257b5d99b74506c3609739e343','classification':'CANDIDATE_VENDOR_SCHEDULER_SOURCE_NOT_SHIPPED_APK_NOT_GOOGLE_OR_PHONE','cases':cases}
(out/'NATIVE_POOL_18.json').write_text(json.dumps(v,indent=2)+'\n');print('NATIVE_POOL_18='+json.dumps(v))
