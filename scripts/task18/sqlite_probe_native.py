"""Causal native lock-order probe; no existing library DB or real Google."""
import json,os,pathlib,time
from probe_native import OUT,ROOT,adb,click,launch,system_ui_preflight,shot
cases=[]
try:
 assert adb('shell','getprop','ro.kernel.qemu').strip()=='1'
 adb('shell','wm','size','720x1280');adb('shell','wm','density','280')
 adb('install','-r',str(pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-ui-probe/probe.apk'));system_ui_preflight()
 for edition,suffix,pool in [('master','',1),('client','.clienttest',4)]:
  pkg='ru.sulfi.sulfi_hypnotherapy'+suffix+'.transferprobe'
  assert 'Success' in adb('install','-r','-t',str(ROOT/(edition+'.apk')))
  launch(pkg);click('RUN SQLITE LOCK CHECK');until=time.monotonic()+40;v=None
  while time.monotonic()<until:
   raw=adb('shell','run-as',pkg,'cat','files/sqlite-concurrency18.json',check=False)
   try:v=json.loads(raw)
   except json.JSONDecodeError:time.sleep(1);continue
   break
  assert v is not None,'NO_NATIVE_LOCK_EXPERIMENT_RECEIPT'
  assert v['productionDatabaseOpened'] is False and v['pool']==pool
  (OUT/(edition+'-sqlite-concurrency18.json')).write_text(json.dumps(v,indent=2)+'\n');shot(edition+'-sqlite-lock-check')
  expected='BLOCKED_NATIVE_POOL_LOCK_ORDER' if pool==1 else 'BOTH_COMMITS_COMPLETE'
  assert v['status']==expected,'LOCK_ORDER_HYPOTHESIS_NOT_CONFIRMED:'+repr(v)
  cases.append({'edition':edition,'status':'PASS_CAUSAL_EXPERIMENT','pool':pool,'observed':v['status']})
  # Only disposable emulator package. Never Force Stop an owner's application.
  adb('shell','am','force-stop',pkg)
except Exception as e:
 cases.append({'status':'BLOCKED','reason':str(e)[:1200],'type':type(e).__name__});shot('sqlite-lock-failure')
finally:
 v={'appSource':os.environ.get('TASK18_PROBE_APP_SOURCE'),'driverSource':os.environ['GITHUB_SHA'],'classification':'CONTROLLED_NATIVE_SQFLITE_LOCK_ORDER_NOT_PHONE','cases':cases}
 (OUT/'NATIVE_SQLITE_CONCURRENCY_18.json').write_text(json.dumps(v,indent=2)+'\n');print('NATIVE_SQLITE_CONCURRENCY_18='+json.dumps(v))
assert len(cases)==2 and all(c['status']=='PASS_CAUSAL_EXPERIMENT' for c in cases),'NATIVE_LOCK_EXPERIMENT_INCONCLUSIVE'
