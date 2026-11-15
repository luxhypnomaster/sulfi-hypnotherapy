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
for count in [1,4]:
 raw=adb('shell','run-as',pkg,'env','CLASSPATH=/data/user/0/'+pkg+'/files/native-pool18.jar:'+apk,'app_process','/system/bin','org.alchemist.p0probe.NativePoolProbe',pkg,str(count),'2000').decode(errors='replace')
 match=re.search(r'^NATIVE_POOL18=(\{.*\})$',raw,re.M);assert match,'NO_NATIVE_POOL_RECEIPT:'+raw[-1000:]
 v=json.loads(match[1]);(out/('native-pool-'+str(count)+'.json')).write_text(json.dumps(v,indent=2)+'\n')
 assert v['productionDatabaseOpened'] is False and v['pool']==count and v['busyTimeoutMs']==2000
 if count==1:
  assert v['errors']==['SQLiteDatabaseLockedException'] and 'B_COMMITTED' not in v['events'],'NEGATIVE_LOCK_ORDER_NOT_OBSERVED'
 else:
  assert not v['errors'] and v['status']=='BOTH_COMMITS_COMPLETE' and v['rows']==2 and v['integrity']=='ok','POSITIVE_LOCK_ORDER_CONTROL_FAILED'
 cases.append({'pool':count,'status':'PASS_CAUSAL_NATIVE_EXPERIMENT','observed':v['status']})
v={'driverSource':os.environ['GITHUB_SHA'],'appSource':'ef50fc5dceb849257b5d99b74506c3609739e343','classification':'NATIVE_POOL_NOT_APP_UPGRADE_GOOGLE_OR_PHONE','cases':cases}
(out/'NATIVE_POOL_18.json').write_text(json.dumps(v,indent=2)+'\n');print('NATIVE_POOL_18='+json.dumps(v))
