"""Disposable Android UI-created APK24 upgrade investigation; NEVER seeds a DB."""
import base64, hashlib, io, json, os, pathlib, re, sqlite3, subprocess, tarfile, tempfile, time, xml.etree.ElementTree as ET
OUT=pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-evidence';OUT.mkdir(exist_ok=True)
APK=pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-apks'
PKG='ru.sulfi.sulfi_hypnotherapy'
CASES=[];ACTIONS=[];inventories={}
IME=False;ELMAN_TITLE='Индукция Элмана вариант 2'
def adb(*args,binary=False,check=True):
 r=subprocess.run(['adb',*args],capture_output=True,timeout=55,check=False)
 if check and r.returncode:raise RuntimeError('ADB_FAILED:'+str(args[:4])+':'+r.stderr.decode(errors='replace')[-800:]+r.stdout.decode(errors='replace')[-800:])
 return r.stdout if binary else r.stdout.decode(errors='replace')
def probe(op='dump',value=None,index=0):
 args=['shell','am','instrument','-w','-e','op',op]
 if value is not None:args+=['-e','value',base64.b64encode(value.encode()).decode(),'-e','index',str(index)]
 raw=adb(*args,'org.alchemist.p0probe/.Probe')
 if 'INSTRUMENTATION_RESULT: failure=' in raw:raise AssertionError(raw[-500:])
 return raw
def tree():
 raw=probe();match=re.search(r'INSTRUMENTATION_RESULT: payload=([^\s]+)',raw)
 if not match:return []
 xml=base64.b64decode(match[1]).decode()
 (OUT/'latest-window.xml').write_text(xml)
 return list(ET.fromstring(xml).iter('node'))
def label(n):return (n.get('text','')+' '+n.get('content-desc','')).strip()
def shot(name):
 try:
  (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p',binary=True))
  (OUT/(name+'.xml')).write_text((OUT/'latest-window.xml').read_text() if (OUT/'latest-window.xml').exists() else '')
 except Exception as error:
  (OUT/(name+'-capture-error.txt')).write_text(type(error).__name__)
def tap(n):
 p=[int(i) for i in re.findall(r'\d+',n.get('bounds',''))]
 adb('shell','input','tap',str((p[0]+p[2])//2),str((p[1]+p[3])//2));time.sleep(.5)
def click(text,exact=False,attempts=3):
 for _ in range(attempts):
  ns=tree()
  for n in sorted(ns,key=lambda n: 0 if n.get('text')==text else 1):
   if (text in [n.get('text'),n.get('content-desc')] or ' '.join(text.split()) in [' '.join((n.get(k) or '').split()) for k in ['text','content-desc']]) if exact else ' '.join(text.split()) in ' '.join(label(n).split()):
    ACTIONS.append({'action':'tap','label':text});tap(n);return
  time.sleep(.5)
 raise AssertionError('UI_NOT_FOUND:'+text+';labels='+repr([label(n) for n in ns if label(n)][:32]))
def text(value,index=0):
 ns=[]
 for _ in range(12):
  ns=[n for n in tree() if n.get('class')=='android.widget.EditText']
  if len(ns)>index:break
  time.sleep(1)
 assert len(ns)>index,'NO_EDIT_FIELD'
 tap(ns[index]);time.sleep(.6)
 if IME:
  result=''
  for _ in range(8):
   result=adb('shell','am','broadcast','-n','org.alchemist.p0ime/.TypeTextReceiver','-a','org.alchemist.p0probe.TYPE_TEXT','--es','value',base64.b64encode(value.encode()).decode())
   if 'UI_TEXT_COMMITTED' in result:break
   time.sleep(.5)
   # The IME has a separate package, so probe termination cannot kill it.
   # Keep the focused UI field; wait for its real Android InputConnection.
  assert 'UI_TEXT_COMMITTED' in result,'NATIVE_IME_INPUT_FAILED:'+result[-200:]
  method='native_IME_commitText'
 else:
  assert value.isascii(),'UNICODE_INPUT_NOT_AVAILABLE'
  adb('shell','input','keycombination','KEYCODE_CTRL_LEFT','KEYCODE_A')
  adb('shell','input','text',value.replace(' ','%s'));method='native_keyboard_key_events'
 time.sleep(.4);adb('shell','input','keyevent','4');time.sleep(.4)
 assert any(value in label(n) for n in tree()),'UI_INPUT_READBACK_MISMATCH'
 ACTIONS.append({'action':method+'_with_UI_readback','value':value,'index':index})
def launch():
 adb('shell','am','start','-W','-n',PKG+'/ru.sulfi.sulfi_hypnotherapy.MainActivity')
 for _ in range(25):
  ns=tree()
  if any('НАЧАТЬ ТРАНСФОРМАЦИЮ' in label(n) for n in ns) or any('ИСТОРИЯ · №' in label(n) for n in ns):return
  allow=next((n for n in ns if 'permission_allow' in n.get('resource-id','')),None)
  if allow is not None:tap(allow)
  time.sleep(2)
 raise AssertionError('HOME_NOT_READY:'+repr([label(n) for n in ns if label(n)][:20]))
def home():
 for _ in range(8):
  if any('НАЧАТЬ ТРАНСФОРМАЦИЮ' in label(n) for n in tree()):return
  adb('shell','input','keyevent','4');time.sleep(.5)
 raise AssertionError('CANNOT_RETURN_HOME')
def restart():adb('shell','am','force-stop',PKG);launch()
def report():
 v={'fixture':'created through unmodified APK24 Android UI; no SQL/DB injection','googleIdentities':'NOT_RUN_NO_REAL_ACCOUNT','ownerPhone':'NOT_TOUCHED','cases':CASES,'actions':ACTIONS,'inventories':inventories}
 (OUT/'NATIVE_UI_UPGRADE_16V.json').write_text(json.dumps(v,ensure_ascii=False,indent=2))
def case(name,fn):
 print('NATIVE16V_START='+name,flush=True)
 try:details=fn();CASES.append({'case':name,'status':'PASS','details':details})
 except Exception as e:
  CASES.append({'case':name,'status':'BLOCKED','reason':str(e)[:3000]});shot('failure-'+name)
 finally:report();print('NATIVE16V_CASE='+json.dumps(CASES[-1],ensure_ascii=False),flush=True)
def package_info():
 raw=adb('shell','dumpsys','package',PKG)
 m=re.search(r'versionCode=(\d+)',raw)
 return {'versionCode':int(m[1]) if m else None,'dataDirs':re.findall(r'dataDir=(\S+)',raw)[:2]}
def inventory(name):
 # Read copies only. Preserve SQLite+WAL+SHM together; never touch original DB.
 raw=adb('exec-out','run-as',PKG,'tar','-cf','-','files','shared_prefs',binary=True,check=False)
 (OUT/(name+'-private-snapshot.tar')).write_bytes(raw)
 files={};rows={};headers={}
 with tempfile.TemporaryDirectory() as td:
  d=pathlib.Path(td)
  with tarfile.open(fileobj=io.BytesIO(raw)) as z:
   for m in z:
    if not m.isfile():continue
    b=z.extractfile(m).read();files[m.name]={'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
    if m.name in ['files/library.sqlite','files/library.sqlite-journal','files/library.sqlite-wal','files/library.sqlite-shm']:(d/pathlib.Path(m.name).name).write_bytes(b)
  assert (d/'library.sqlite').exists(),'DB_FILE_MISSING'
  c=sqlite3.connect('file:'+str(d/'library.sqlite')+'?mode=ro',uri=True)
  headers={'integrity':c.execute('pragma integrity_check').fetchone()[0],'version':c.execute('pragma user_version').fetchone()[0]}
  for (table,) in c.execute("select name from sqlite_master where type='table' order by name"):
   if table.startswith('sqlite_') or table=='android_metadata':continue
   c.row_factory=sqlite3.Row;rows[table]=[dict(r) for r in c.execute('select * from '+table)]
  c.close()
 capsule=adb('exec-out','cat','/sdcard/Download/task16v-ui-before24.zip',binary=True,check=False)
 if capsule.startswith(b'PK'):files['external/Download/task16v-ui-before24.zip']={'bytes':len(capsule),'sha256':hashlib.sha256(capsule).hexdigest()}
 v={'package':package_info(),'database':headers,'rows':rows,'files':files,'snapshot_sha256':hashlib.sha256(raw).hexdigest()}
 inventories[name]=v;report();return v
def install():
 global IME,ELMAN_TITLE
 assert adb('shell','getprop','ro.kernel.qemu').strip()=='1','DISPOSABLE_EMULATOR_REQUIRED'
 assert 'Success' in adb('install','-r',str(pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-ui-probe/probe.apk'))
 assert 'Success' in adb('install','-r',str(pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-ui-probe/ime.apk'))
 assert 'Success' in adb('install','-r',str(APK/'master24.apk'))
 adb('shell','wm','size','720x1280');adb('shell','wm','density','280')
 adb('shell','cmd','connectivity','airplane-mode','enable',check=False)
 adb('shell','svc','wifi','disable',check=False);adb('shell','svc','data','disable',check=False)
 for _ in range(10):
  listing=adb('shell','ime','list','-s',check=False)
  if 'org.alchemist.p0ime/' in listing:break
  time.sleep(1)
 try:
  ime_id=next(x.strip() for x in listing.splitlines() if x.strip().startswith('org.alchemist.p0ime/'))
  adb('shell','ime','enable',ime_id);adb('shell','ime','set',ime_id);IME=True
 except Exception as error:
  IME=False;ELMAN_TITLE='Elman variant 2'
  print('NATIVE16V_IME_OPTIONAL_BLOCKED='+str(error)[:700],flush=True)
 launch();shot('24-clean')
 return {'versionCode':24,'uninstall':False,'databaseInjected':False,'unicodeIME':IME,'actualElmanFixtureTitle':ELMAN_TITLE}
def import_audio(filename,title):
 home();click('Библиотека');click('+ Добавить аудио');time.sleep(1)
 # Wait for DocumentsUI before resolving its drawer; no invisible stale taps.
 for _ in range(10):
  ns=tree()
  if any('Show roots' in label(n) for n in ns):break
  time.sleep(1)
 if not any(filename in label(n) for n in ns):
  click('Show roots',exact=True);click('Downloads',exact=True);time.sleep(1)
 click(filename,exact=True);time.sleep(3);text(title);click('Сохранить',exact=True);time.sleep(1)
 assert any(title in label(n) for n in tree()),'IMPORTED_NOT_VISIBLE';shot('24-import-'+filename)
 inventory('after-ui-import-'+filename)
 return {'createdBy':'UI_system_picker','title':title}
def record_audio():
 home();click('Библиотека');click('Записать свой трек');text('UI recorded original')
 finish=None
 for _ in range(5):
  ns=tree();finish=next((n for n in ns if label(n)=='Завершить'),None)
  if finish is not None:break
  adb('shell','input','swipe','360','1010','360','490','650');time.sleep(.4)
 assert finish is not None,'FINISH_CONTROL_NOT_FOUND'
 click('Начать запись');time.sleep(.5)
 ns=tree();allow=next((n for n in ns if 'permission_allow_foreground_only_button' in n.get('resource-id','') or 'permission_allow_button' in n.get('resource-id','')),None)
 if allow is not None:tap(allow)
 time.sleep(4);tap(finish);time.sleep(2);click('Сохранить трек');time.sleep(2)
 assert any('UI recorded original' in label(n) for n in tree()),'RECORDED_NOT_VISIBLE'
 return {'createdBy':'native_microphone_UI','hardware':'emulator_virtual_microphone'}
def module(title,tracks,pause=False):
 home();click('Шаблоны');click('Модули');click('Создать модуль');text(title)
 click('Добавить трек');time.sleep(1)
 seen={}
 for t in tracks:
  ns=tree();matches=[n for n in ns if label(n).split('\n')[0]==t and n.get('clickable')=='true']
  idx=seen.get(t,0);assert len(matches)>idx,'TRACK_ROW_NOT_FOUND:'+t
  tap(matches[idx]);seen[t]=idx+1
 adb('shell','input','keyevent','4');time.sleep(1)
 if pause:
  click('Добавить паузу');time.sleep(1)
  # Genuine vertical seconds wheel gesture; no model injection.
  adb('shell','input','swipe','542','670','542','555','700');click('Применить');time.sleep(1)
 click('Сохранить модуль');time.sleep(1)
 assert any(title in label(n) for n in tree()),'MODULE_NOT_VISIBLE'
 return {'title':title,'UI_dependencies':tracks,'pauseAdded':pause}
def native_audio_active():
 uid=adb('shell','cmd','package','list','packages','-U',PKG)
 match=re.search(r'uid:(\d+)',uid);assert match,'NO_APP_UID'
 for _ in range(15):
  raw=adb('shell','dumpsys','audio')
  rows=[line.strip() for line in raw.splitlines() if re.search(r'(?:u/pid|uid/pid|uid)[:=]\s*'+match[1]+r'(?:/|\b)',line)]
  if any(re.search(r'state[:=]\s*(?:started|3)\b',line,re.I) for line in rows):return True
  time.sleep(.5)
 return False
def create_template():
 home();click('Открыть конструктор');click('Добавить фазу');click('Индукция');click('Добавить',exact=True);click('Модуль',exact=True)
 click(ELMAN_TITLE);click('Сохранить',exact=True);text('UI Elman program');click('Сохранить',exact=True);time.sleep(1);click('Применить',exact=True);time.sleep(1)
 home();return {'createdBy':'native_UI_structure_and_template','containsModule':True}
def create_history():
 home();click('НАЧАТЬ ТРАНСФОРМАЦИЮ');playing=native_audio_active();shot('24-native-session')
 # Actual crash/reopen on disposable emulator, never the owner phone.
 restart();v=inventory('after-ui-history24');assert v['rows']['session_runs'],'NO_UI_CREATED_HISTORY'
 return {'createdBy':'UI_session_then_disposable_force_stop','nativeAudioObserved':playing,'physicalHeardSound':'NOT_RUN','runs':len(v['rows']['session_runs']),'statuses':[r['status'] for r in v['rows']['session_runs']]}
def export_capsule():
 home();click('Библиотека');click('О приложении и данных');click('Резервная копия и обновления');click('Создать резервную копию');time.sleep(2)
 text('task16v-ui-before24.zip');click('SAVE',exact=True);time.sleep(3)
 raw=adb('exec-out','cat','/sdcard/Download/task16v-ui-before24.zip',binary=True)
 import zipfile
 with zipfile.ZipFile(io.BytesIO(raw)) as z:assert z.testzip() is None,'EXPORTED_ZIP_CRC_FAILED'
 return {'createdBy':'native_UI_SAF_export','sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)}
def diary_boundary():
 home();click('Дневник');ns=tree();shot('24-diary-author-boundary')
 if not any('Новая запись' in label(n) for n in ns):
  raise AssertionError('REAL_MASTER_GOOGLE_LOGIN_REQUIRED_BY_IMMUTABLE_APK24; no UI draft creation possible offline; no fake identity or SQL substitute')
 raise AssertionError('AUTHOR_WORKSPACE_AVAILABLE_NEEDS_SEPARATE_UI_DIARY_DRIVER')
def before():
 home();v=inventory('before24');assert v['package']['versionCode']==24,'BASELINE_NOT_APK24'
 assert len(v['rows']['audio_assets'])>=3,'NOT_ENOUGH_UI_AUDIO'
 assert len(v['rows']['module_definitions'])>=1,'NO_UI_MODULE'
 shot('24-before-upgrade');return {'tracks':len(v['rows']['audio_assets']),'modules':len(v['rows']['module_definitions']),'integrity':v['database']['integrity']}
def compare(name):
 v=inventory(name);assert v['package']['versionCode']==25,'COMPARE_NOT_ACTUALLY_APK25'
 old=inventories.get('before24');assert old,'NO_BASELINE'
 assert any(c['case']=='before24_inventory' and c['status']=='PASS' for c in CASES),'INVALID_BASELINE_UI_CREATION_FAILED'
 assert len(old['rows']['audio_assets'])>=3 and len(old['rows']['module_definitions'])>=1,'EMPTY_BASELINE_CANNOT_PASS_UPGRADE'
 missing={}
 for table in ['audio_assets','module_definitions','session_templates','current_draft','session_runs','diary_author']:
  absent=[r for r in old['rows'][table] if r not in v['rows'][table]]
  if absent:missing[table]=absent
 for p,b in old['files'].items():
  if p.startswith(('files/audio/','files/diary_media/','files/history_media/','external/')) and v['files'].get(p)!=b:missing[p]=b
 assert not missing,'PRESERVATION_FAILURE:'+json.dumps(missing)
 assert v['database']['integrity']=='ok','INTEGRITY_FAILED'
 return {'exactRowsAndMediaPreserved':True,'audio':len(v['rows']['audio_assets']),'modules':len(v['rows']['module_definitions']),'diary':len(v['rows']['diary_author'])}
def upgrade():
 assert any(c['case']=='before24_inventory' and c['status']=='PASS' for c in CASES),'STOP_SHIP_INVALID_UI_BASELINE_NO_UPGRADE_PROOF'
 assert 'Success' in adb('install','-r',str(APK/'master25.apk'));launch();shot('25-after-upgrade');return compare('after25')
def ui_after():
 home();click('Библиотека');ns=tree();shot('25-library')
 # Inspect both default and personal sections; preserve output of default filter.
 default=[label(n) for n in ns if label(n)]
 click('Мои',exact=True);ns=tree();titles=[r['title'] for r in inventories['before24']['rows']['audio_assets']]
 absent=[t for t in titles if not any(t in label(n) for n in ns)];assert not absent,'TRACKS_MISSING_FROM_UI:'+repr(absent)
 shot('25-personal-library');click('Прослушать UI third track',exact=True);playing=native_audio_active();assert playing,'NATIVE_LIBRARY_AUDIO_NOT_OBSERVED'
 home();click('Шаблоны');click('Модули');ns=tree();shot('25-modules')
 mt=[json.loads(r['payload'])['title'] for r in inventories['before24']['rows']['module_definitions']]
 assert all(any(t in label(n) for n in ns) for t in mt),'MODULES_MISSING_FROM_UI'
 return {'allUIAudioAndModulesVisible':True,'nativeLibraryAudioObserved':playing,'physicalHeardSound':'NOT_RUN','defaultLibraryLabels':default[:35]}
try:
 case('install_24',install)
 assert CASES[-1]['status']=='PASS','INSTALL_PRECONDITION_FAILED_NO_DATA_PROOF'
 case('native_dependency_corruption',lambda:json.loads(re.search(r'INSTRUMENTATION_RESULT: dependency_probe=([^\r\n]+)',probe('corruption')).group(1)))
 adb('shell','mkdir','-p','/sdcard/Download')
 # Generate a harmless PCM WAV fixture (not the Sulfi voice), then register
 # each actual file with Android MediaScanner so DocumentsUI knows its MIME.
 import wave,math,struct
 fixture=OUT/'ui-source.wav'
 with wave.open(str(fixture),'wb') as w:
  w.setparams((1,2,22050,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(1800*math.sin(i*2*math.pi*220/22050))) for i in range(22050*12)))
 for i in range(1,4):
  path='/sdcard/Download/task16v-'+str(i)+'.wav'
  adb('push',str(fixture),path)
  adb('shell','am','broadcast','-a','android.intent.action.MEDIA_SCANNER_SCAN_FILE','-d','file://'+path,check=False)
 time.sleep(2)
 if os.environ.get('P0_QA_SCOPE')=='recording':case('ui_native_recording24',record_audio)
 for i in range(1,4):case('ui_import_'+str(i),lambda i=i:import_audio('task16v-'+str(i)+'.wav','UI same title' if i<3 else 'UI third track'))
 case('ui_module_elman',lambda:module(ELMAN_TITLE,['UI same title','UI same title','UI third track']))
 case('ui_module_pause',lambda:module('UI timed module',['UI third track'],True))
 case('ui_template',create_template)
 case('ui_history',create_history)
 case('ui_capsule_export',export_capsule)
 case('ui_diary_auth_boundary',diary_boundary)
 case('before24_inventory',before)
 case('native_update24_to25',upgrade)
 case('ui_after25',ui_after)
 case('cold_restart25',lambda:(restart(),compare('cold25'))[-1])
except Exception as e:
 CASES.append({'case':'driver','status':'BLOCKED','reason':str(e)[:1500]});report()
finally:
 report()
 def emit(name,data):
  enc=base64.b64encode(data).decode();chunks=[enc[i:i+12000] for i in range(0,len(enc),12000)]
  print('NATIVE16V_DIGEST='+name+':'+hashlib.sha256(data).hexdigest(),flush=True)
  for i,chunk in enumerate(chunks):print('NATIVE16V_CHUNK='+name+':'+str(i)+':'+str(len(chunks))+':'+chunk,flush=True)
 emit('NATIVE_UI_UPGRADE_16V.json',(OUT/'NATIVE_UI_UPGRADE_16V.json').read_bytes())
 for p in sorted(OUT.glob('*.png')):
  if p.name in ['25-library.png','25-modules.png','24-before-upgrade.png'] or p.name.startswith('failure-'):
   emit(p.name,p.read_bytes())
 for p in sorted(OUT.glob('failure-*.xml')):emit(p.name,p.read_bytes())
 if any(c['status']!='PASS' for c in CASES):
  print('NATIVE16V_RELEASE_GATE=BLOCKED; do not equate completed driver with accepted upgrade',flush=True)
  raise SystemExit(2)
