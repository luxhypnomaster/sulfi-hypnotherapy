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
 m=re.search(r'INSTRUMENTATION_RESULT: payload=([^\s]+)',raw);assert m,'NO_UI_XML'
 return list(ET.fromstring(base64.b64decode(m[1])).iter('node'))
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
def launch(pkg):
 adb('shell','am','start','-n',pkg+'/ru.sulfi.sulfi_hypnotherapy.MainActivity');time.sleep(3)
try:
 ready=json.loads(pathlib.Path('.task17-sdk-ready.json').read_text());assert ready['version']=='37.2.12' and ready['validatedHeadlessVersion']
 adb('install','-r',str(pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-ui-probe/probe.apk'))
 packages={e:'ru.sulfi.sulfi_hypnotherapy'+('.clienttest' if e=='client' else '')+'.transferprobe' for e in ['master','client']}
 for e,pkg in packages.items():
  adb('install','-r','-t',str(ROOT/(e+'.apk')));adb('shell','pm','grant',pkg,'android.permission.POST_NOTIFICATIONS',check=False)
  CASES.append({'case':e+'_install_disposable_probe','status':'PASS','package':pkg,'Google':'NOT_RUN','candidateAPK':False})
 pkg=packages['master'];launch(pkg);click('UPLOAD AND DESTROY UI')
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
 while time.monotonic()<until and stats()['calls'].get('catalog.publish',0)<1:time.sleep(1)
 assert stats()['calls'].get('catalog.publish',0)>=1,'NO_CATALOG_COMMIT_REQUEST'
 adb('shell','input','keyevent','KEYCODE_WAKEUP');adb('shell','wm','dismiss-keyguard');launch(pkg)
 click('READ INVENTORY');time.sleep(3);shot('master-after-background')
 pkg=packages['client'];launch(pkg);click('DOWNLOAD AND DESTROY UI');before=wait_bytes('downloaded',262144,60)
 adb('shell','input','keyevent','KEYCODE_SLEEP');time.sleep(3);after=wait_bytes('downloaded',before['downloaded']+524288,30)
 CASES.append({'case':'client_real_tcp_bytes_after_UI_engine_destroy_and_screen_off','status':'PASS','before':before['downloaded'],'after':after['downloaded'],'Google':'NOT_RUN'})
 final=wait_bytes('downloaded',15*1024*1024,210)
 time.sleep(5);adb('shell','input','keyevent','KEYCODE_WAKEUP');adb('shell','wm','dismiss-keyguard');launch(pkg);click('READ INVENTORY');time.sleep(3)
 labels=[n.get('text','') for n in tree()];assert any('NATIVE INVENTORY 3 AUDIO / 3 HASH / 1 MODULE / 1 PROGRAM' in x for x in labels),'INSTALL_HASH_MANIFEST_INVENTORY_NOT_CONFIRMED:'+repr(labels[:15])
 shot('client-verified-install');snapshot(pkg,'client-after-install')
 CASES.append({'case':'client_background_atomic_program_install_3_real_wav_files_hashes_module_template','status':'PASS','Google':'NOT_RUN','heardByHuman':'NOT_RUN'})
except Exception as e:
 CASES.append({'case':'native_probe_failure','status':'FAIL','type':type(e).__name__,'reason':str(e)[-1200:]});shot('failure')
 try:(OUT/'crash.txt').write_text(adb('logcat','-d','-b','crash','-t','50',check=False))
 except Exception:pass
finally:
 result={'source':os.environ['GITHUB_SHA'],'scope':'CONTROLLED_NATIVE_REAL_LOOPBACK_TCP_ONLY','Google':'NOT_RUN','GAS':'NOT_TOUCHED','ownerPhones':'NOT_RUN','actualCandidateUpgrade':'NOT_RUN','cases':CASES}
 (OUT/'NATIVE_PROBE_18.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 data=(OUT/'NATIVE_PROBE_18.json').read_bytes();print('TASK18_NATIVE_PROBE_JSON_BASE64='+base64.b64encode(data).decode());print('TASK18_NATIVE_PROBE_SHA256='+hashlib.sha256(data).hexdigest())
assert not any(c['status']=='FAIL' for c in CASES),'CONTROLLED_NATIVE_PROBE_FAILED_NO_APK_DELIVERY'
