"""Real Android OS/headless + loopback TCP fixture. NOT Google/GAS/owner QA."""
import base64,hashlib,json,os,pathlib,re,subprocess,time,urllib.request,xml.etree.ElementTree as ET
OUT=pathlib.Path(os.environ['RUNNER_TEMP'])/'task18-probe-evidence';OUT.mkdir(exist_ok=True)
ROOT=pathlib.Path(os.environ['RUNNER_TEMP'])/'task18-probe-apks'
CASES=[]
def adb(*args,check=True):
 r=subprocess.run(['adb',*args],capture_output=True,text=True,timeout=40)
 if check:assert r.returncode==0,r.stderr[-300:]
 return r.stdout
def tree():
 raw=adb('shell','am','instrument','-w','-e','op','dump','org.alchemist.p0probe/.Probe')
 (OUT/'latest-instrumentation.txt').write_text(raw[-5000:])
 m=re.search(r'INSTRUMENTATION_RESULT: payload=([^\s]+)',raw)
 return list(ET.fromstring(base64.b64decode(m[1])).iter('node')) if m else []
def click(text,wait=20):
 until=time.monotonic()+wait
 while time.monotonic()<until:
  nodes=tree()
  for n in nodes:
   if text in [n.get('text'),n.get('content-desc')] and n.get('enabled')!='false':
    b=[int(x) for x in re.findall(r'\d+',n.get('bounds',''))];adb('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2));return
  time.sleep(1)
 raise AssertionError('FIXTURE_UI_BUTTON_NOT_FOUND:'+text)
def stats():
 with urllib.request.urlopen('http://127.0.0.1:4018/stats',timeout=5) as r:return json.load(r)
def shot(name):
 result=subprocess.run(['adb','exec-out','screencap','-p'],capture_output=True,timeout=15)
 if result.returncode==0:(OUT/(name+'.png')).write_bytes(result.stdout)
def snapshot(pkg,name):
 # Only disposable synthetic fixture. Never collects SharedPreferences/credentials.
 raw=adb('shell','run-as',pkg,'ls','files')
 (OUT/(name+'-files.txt')).write_text(raw)
 (OUT/(name+'-jobs.txt')).write_text(adb('shell','dumpsys','jobscheduler',pkg))
def wait_bytes(field,minimum,timeout):
 until=time.monotonic()+timeout
 while time.monotonic()<until:
  v=stats()
  if v[field]>=minimum:return v
  time.sleep(2)
 raise AssertionError('NO_REMOTE_PROGRESS:'+field+':'+json.dumps(stats()))
def confirm_ui_destroyed(pkg,expected_pid):
 until=time.monotonic()+20
 while time.monotonic()<until:
  raw=adb('shell','run-as',pkg,'cat','files/probe18-ui-destroy.json',check=False)
  try:
   v=json.loads(raw)
   assert v['activityDestroyed'] and v['engineDestroyed'] and v['cachedUiEngineAbsent'],'UI_DESTRUCTION_NOT_CONFIRMED'
   assert str(v['pid'])==expected_pid==adb('shell','pidof',pkg).strip(),'PROCESS_CRASH_IS_NOT_PURE_UI_DESTRUCTION'
   (OUT/(pkg.split('.')[-2]+'-ui-destroy-receipt.json')).write_text(json.dumps(v,indent=2))
   return v
  except json.JSONDecodeError:time.sleep(.5)
 raise AssertionError('MISSING_OBSERVED_ACTIVITY_ENGINE_DESTROY_RECEIPT')
def expect_inventory(pkg,offline=False,timeout=45):
 until=time.monotonic()+timeout
 while time.monotonic()<until:
  click('READ OFFLINE INVENTORY' if offline else 'READ INVENTORY');time.sleep(1)
  labels=[n.get('text','') for n in tree()]
  if any('NATIVE INVENTORY 3 AUDIO / 3 HASH / 1 MODULE / 1 PROGRAM' in x for x in labels):
   if offline or any(x.startswith('complete ') for x in labels):return
  time.sleep(1)
 raise AssertionError('INSTALL_HASH_MANIFEST_OR_RECEIPT_NOT_CONFIRMED:'+repr(labels[:15]))
def native_audio_active(pkg):
 uid=re.search(r'uid:(\d+)',adb('shell','cmd','package','list','packages','-U',pkg));assert uid,'NO_AUDIO_APP_UID'
 for _ in range(15):
  raw=adb('shell','dumpsys','audio')
  lines=[x for x in raw.splitlines() if re.search(r'(?:u/pid|uid/pid|uid)[:=]\s*'+uid[1]+r'(?:/|\b)',x)]
  if any(re.search(r'state[:=]\s*(?:started|3)\b',x,re.I) for x in lines):
   (OUT/'client-native-local-audio.txt').write_text('\n'.join(lines));return True
  time.sleep(.5)
 return False
def launch(pkg):
 (OUT/'latest-launch.txt').write_text(adb('shell','am','start','-W','-n',pkg+'/ru.sulfi.sulfi_hypnotherapy.MainActivity'))
 until=time.monotonic()+60
 while time.monotonic()<until:
  if any('CONTROLLED18' in (n.get('text','')+' '+n.get('content-desc','')) for n in tree()):return
  time.sleep(1)
 raise AssertionError('FIXTURE_FIRST_FRAME_NOT_READY_WITHIN_60S')
try:
 ready=json.loads(pathlib.Path('.task17-sdk-ready.json').read_text());assert ready['version']=='37.2.12' and ready['validatedHeadlessVersion']
 # Match proven Task17 native baseline: lower actual framebuffer plus GLES,
 # not a changed app renderer or relaxed test. Previous proof showed launcher ANR.
 adb('shell','wm','size','720x1280');adb('shell','wm','density','280')
 (OUT/'display-preflight.txt').write_text(adb('shell','wm','size')+adb('shell','wm','density'))
 adb('install','-r',str(pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-ui-probe/probe.apk'))
 packages={e:'ru.sulfi.sulfi_hypnotherapy'+('.clienttest' if e=='client' else '')+'.transferprobe' for e in ['master','client']}
 for e,pkg in packages.items():
  adb('install','-r','-t',str(ROOT/(e+'.apk')));adb('shell','pm','grant',pkg,'android.permission.POST_NOTIFICATIONS',check=False)
  CASES.append({'case':e+'_install_disposable_probe','status':'PASS','package':pkg,'Google':'NOT_RUN','candidateAPK':False})
 pkg=packages['master'];launch(pkg);initial_pid=adb('shell','pidof',pkg).strip();click('UPLOAD AND DESTROY UI');confirm_ui_destroyed(pkg,initial_pid)
 before=wait_bytes('uploaded',262144,60)
 # Application has explicitly destroyed its UI engine. OS must own progress.
 activities=adb('shell','dumpsys','activity','activities');assert pkg+'/ru.sulfi.sulfi_hypnotherapy.MainActivity' not in '\n'.join(x for x in activities.splitlines() if 'mResumedActivity' in x)
 adb('shell','input','keyevent','KEYCODE_SLEEP');time.sleep(3);shot('master-ui-destroyed-screen-off')
 after=wait_bytes('uploaded',before['uploaded']+524288,30)
 assert after['uploaded']>before['uploaded'];snapshot(pkg,'master-background')
 CASES.append({'case':'master_real_tcp_bytes_after_UI_engine_destroy_and_screen_off','status':'PASS','before':before['uploaded'],'after':after['uploaded'],'Google':'NOT_RUN','transport':'REAL_LOOPBACK_TCP_PRODUCTION_JS_DOMAIN'})
 final=wait_bytes('verifiedBytes',15*1024*1024,210)
 # Wait for actual catalog commit, not just acknowledged media bytes.
 until=time.monotonic()+40
 while time.monotonic()<until and stats().get('publishedPrograms',0)<1:time.sleep(1)
 assert stats().get('publishedPrograms',0)==1,'NO_UNIQUE_CONFIRMED_CATALOG_COMMIT'
 CASES.append({'case':'master_confirmed_unique_program_publication','status':'PASS','proof':stats()['publishedPrograms'],'Google':'NOT_RUN'})
 adb('shell','input','keyevent','KEYCODE_WAKEUP');adb('shell','wm','dismiss-keyguard');launch(pkg)
 click('READ INVENTORY');time.sleep(3);shot('master-after-background')
 pkg=packages['client'];launch(pkg);initial_pid=adb('shell','pidof',pkg).strip();click('DOWNLOAD AND DESTROY UI');confirm_ui_destroyed(pkg,initial_pid);before=wait_bytes('downloaded',262144,60)
 adb('shell','input','keyevent','KEYCODE_SLEEP');time.sleep(3);after=wait_bytes('downloaded',before['downloaded']+524288,30)
 CASES.append({'case':'client_real_tcp_bytes_after_UI_engine_destroy_and_screen_off','status':'PASS','before':before['downloaded'],'after':after['downloaded'],'Google':'NOT_RUN'})
 final=wait_bytes('downloaded',15*1024*1024,210)
 time.sleep(2);adb('shell','input','keyevent','KEYCODE_WAKEUP');adb('shell','wm','dismiss-keyguard');launch(pkg);expect_inventory(pkg)
 shot('client-verified-install');snapshot(pkg,'client-after-install')
 CASES.append({'case':'client_background_atomic_program_install_3_real_wav_files_hashes_module_template','status':'PASS','Google':'NOT_RUN','heardByHuman':'NOT_RUN'})
 # Only after a receipted completed install: cold restart with both networks off.
 before_offline=stats()['downloaded']
 adb('shell','cmd','connectivity','airplane-mode','enable',check=False);adb('shell','svc','wifi','disable');adb('shell','svc','data','disable')
 adb('shell','am','force-stop',pkg);launch(pkg);expect_inventory(pkg,offline=True)
 click('PLAY LOCAL FILE');assert native_audio_active(pkg),'NO_UID_BOUND_OFFLINE_AUDIO_TRACK'
 assert stats()['downloaded']==before_offline,'UNEXPECTED_DOWNLOAD_DURING_OFFLINE_PROOF'
 shot('client-offline-cold-local-audio')
 CASES.append({'case':'client_cold_offline_3_hash_program_and_native_UID_bound_audio','status':'PASS','Google':'NOT_RUN','physicalHumanHearing':'NOT_RUN','network':'WIFI_DATA_OFF_AIRPLANE'})

except Exception as e:
 CASES.append({'case':'native_probe_failure','status':'FAIL','type':type(e).__name__,'reason':str(e)[-1200:]});shot('failure')
 try:
  (OUT/'crash.txt').write_text(adb('logcat','-d','-b','crash','-t','50',check=False))
  (OUT/'fixture-runtime.txt').write_text(adb('logcat','-d','-s','flutter','AndroidRuntime','ActivityManager','Flutter','FlutterJNI',check=False)[-28000:])
  (OUT/'fixture-activities.txt').write_text(adb('shell','dumpsys','activity','activities',check=False)[-16000:])
  (OUT/'last-anr.txt').write_text(adb('shell','dumpsys','activity','lastanr',check=False)[-40000:])
  pids=adb('shell','pidof',pkg,check=False).strip().split()
  if not pids:raise RuntimeError('PROCESS_ABSENT_CRASH_LOG_ALREADY_SAVED')
  pid=pids[0]
  app_log=adb('logcat','-d','--pid='+pid,check=False)[-64000:]
  app_log=re.sub(r'CONTROLLED_(?:OWNER|CLIENT)_18_[A-Za-z0-9_]+','CONTROLLED_REDACTED',app_log)
  (OUT/'app-runtime-only.txt').write_text(app_log)
  (OUT/'app-main-wchan.txt').write_text(adb('shell','run-as',pkg,'cat','/proc/'+pid+'/task/'+pid+'/wchan',check=False))
  (OUT/'app-java-threads.txt').write_text(adb('shell','debuggerd','-j',pid,check=False)[-40000:])
 except Exception:pass
finally:
 crash=adb('logcat','-d','-b','crash',check=False)
 if 'Process: ru.sulfi.sulfi_hypnotherapy' in crash:
  (OUT/'crash.txt').write_text(crash)
  CASES.append({'case':'unexpected_probe_app_crash','status':'FAIL','reason':'Real process crash is not a clean UI-lifecycle PASS; see crash.txt'})
 result={'source':os.environ.get('TASK18_PROBE_APP_SOURCE',os.environ['GITHUB_SHA']),'driverSource':os.environ['GITHUB_SHA'],'scope':'CONTROLLED_NATIVE_REAL_LOOPBACK_TCP_ONLY','Google':'NOT_RUN','GAS':'NOT_TOUCHED','ownerPhones':'NOT_RUN','actualCandidateUpgrade':'NOT_RUN','cases':CASES}
 (OUT/'NATIVE_PROBE_18.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 data=(OUT/'NATIVE_PROBE_18.json').read_bytes();print('TASK18_NATIVE_PROBE_JSON_BASE64='+base64.b64encode(data).decode());print('TASK18_NATIVE_PROBE_SHA256='+hashlib.sha256(data).hexdigest())
assert not any(c['status']=='FAIL' for c in CASES),'CONTROLLED_NATIVE_PROBE_FAILED_NO_APK_DELIVERY'
