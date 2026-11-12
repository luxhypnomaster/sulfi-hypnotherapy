"""Disposable Android UI-created APK24 upgrade investigation; NEVER seeds a DB."""
import base64, hashlib, io, json, os, pathlib, re, sqlite3, subprocess, tarfile, tempfile, time, xml.etree.ElementTree as ET
OUT=pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-evidence';OUT.mkdir(exist_ok=True)
APK=pathlib.Path(os.environ['RUNNER_TEMP'])/'task16v-apks'
PKG='ru.sulfi.sulfi_hypnotherapy'
CASES=[];ACTIONS=[];inventories={}
def adb(*args,binary=False,check=True):
 r=subprocess.run(['adb',*args],capture_output=True,timeout=55,check=check)
 return r.stdout if binary else r.stdout.decode(errors='replace')
def tree():
 adb('shell','uiautomator','dump','/sdcard/task16v-window.xml',check=False)
 raw=adb('shell','cat','/sdcard/task16v-window.xml',check=False)
 try:return list(ET.fromstring(raw).iter('node'))
 except ET.ParseError:return []
def label(n):return (n.get('text','')+' '+n.get('content-desc','')).strip()
def shot(name):
 (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p',binary=True))
 (OUT/(name+'.xml')).write_text(adb('shell','cat','/sdcard/task16v-window.xml',check=False))
def tap(n):
 p=[int(i) for i in re.findall(r'\d+',n['bounds'])]
 adb('shell','input','tap',str((p[0]+p[2])//2),str((p[1]+p[3])//2));time.sleep(.5)
def click(text,exact=False,attempts=3):
 for _ in range(attempts):
  ns=tree()
  for n in ns:
   if (text in [n.get('text'),n.get('content-desc')]) if exact else text in label(n):
    ACTIONS.append({'action':'tap','label':text});tap(n);return
  time.sleep(.5)
 raise AssertionError('UI_NOT_FOUND:'+text+';labels='+repr([label(n) for n in ns if label(n)][:32]))
def text(value,index=0):
 ns=[n for n in tree() if n.get('class')=='android.widget.EditText'];assert len(ns)>index,'NO_EDIT_FIELD'
 tap(ns[index]);adb('shell','input','keycombination','KEYCODE_CTRL_LEFT','KEYCODE_A');adb('shell','input','text',value.replace(' ','%s'));adb('shell','input','keyevent','4');time.sleep(.5)
 ACTIONS.append({'action':'UI_text','value':value,'index':index})
def launch():
 adb('shell','am','start','-W','-n',PKG+'/ru.sulfi.sulfi_hypnotherapy.MainActivity')
 for _ in range(25):
  ns=tree()
  if any('НАЧАТЬ ТРАНСФОРМАЦИЮ' in label(n) for n in ns):return
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
    if m.name in ['files/library.sqlite','files/library.sqlite-wal','files/library.sqlite-shm']:(d/pathlib.Path(m.name).name).write_bytes(b)
  assert (d/'library.sqlite').exists(),'DB_FILE_MISSING'
  c=sqlite3.connect('file:'+str(d/'library.sqlite')+'?mode=ro',uri=True)
  headers={'integrity':c.execute('pragma integrity_check').fetchone()[0],'version':c.execute('pragma user_version').fetchone()[0]}
  for (table,) in c.execute("select name from sqlite_master where type='table' order by name"):
   if table.startswith('sqlite_') or table=='android_metadata':continue
   c.row_factory=sqlite3.Row;rows[table]=[dict(r) for r in c.execute('select * from '+table)]
  c.close()
 v={'database':headers,'rows':rows,'files':files,'snapshot_sha256':hashlib.sha256(raw).hexdigest()}
 inventories[name]=v;report();return v
def install():
 assert adb('shell','getprop','ro.kernel.qemu').strip()=='1','DISPOSABLE_EMULATOR_REQUIRED'
 adb('shell','wm','size','720x1280');adb('shell','wm','density','280')
 adb('shell','cmd','connectivity','airplane-mode','enable',check=False)
 assert 'Success' in adb('install','-r',str(APK/'master24.apk'));launch();shot('24-clean')
 return {'versionCode':24,'uninstall':False,'databaseInjected':False}
def import_audio(filename,title):
 home();click('Библиотека');click('+ Добавить аудио');time.sleep(1)
 # Real Android DocumentsUI, files exist in disposable Downloads only.
 ns=tree()
 if not any(filename in label(n) for n in ns):
  drawer=next((n for n in ns if 'Show roots' in label(n) or 'Показать корни' in label(n)),None)
  if drawer is not None:tap(drawer);click('Downloads');time.sleep(.5)
 click(filename);time.sleep(3);text(title);click('Сохранить',exact=True);time.sleep(1)
 assert any(title in label(n) for n in tree()),'IMPORTED_NOT_VISIBLE';shot('24-import-'+filename)
 return {'createdBy':'UI_system_picker','title':title}
def record_audio():
 home();click('Библиотека');click('Записать свой трек');text('UI recorded original');click('Начать запись')
 for _ in range(3):
  ns=tree();allow=next((n for n in ns if 'permission_allow_foreground_only_button' in n.get('resource-id','') or 'permission_allow_button' in n.get('resource-id','')),None)
  if allow is None:break
  tap(allow);time.sleep(1)
 time.sleep(4);click('Завершить',exact=True);time.sleep(2);click('Сохранить трек');time.sleep(2)
 assert any('UI recorded original' in label(n) for n in tree()),'RECORDED_NOT_VISIBLE'
 return {'createdBy':'native_microphone_UI','hardware':'emulator_virtual_microphone'}
def module(title,tracks,pause=False):
 home();click('Шаблоны');click('Модули',exact=True);click('Создать модуль');text(title)
 click('Добавить трек');time.sleep(1)
 for t in tracks:click(t)
 adb('shell','input','keyevent','4');time.sleep(1)
 if pause:
  click('Добавить паузу');time.sleep(1)
  # Genuine vertical seconds wheel gesture; no model injection.
  adb('shell','input','swipe','542','670','542','555','700');click('Применить');time.sleep(1)
 click('Сохранить модуль');time.sleep(1)
 assert any(title in label(n) for n in tree()),'MODULE_NOT_VISIBLE'
 return {'title':title,'UI_dependencies':tracks,'pauseAdded':pause}
def diary_boundary():
 home();click('Дневник');ns=tree();shot('24-diary-author-boundary')
 if not any('Новая запись' in label(n) for n in ns):
  raise AssertionError('REAL_MASTER_GOOGLE_LOGIN_REQUIRED_BY_IMMUTABLE_APK24; no UI draft creation possible offline; no fake identity or SQL substitute')
 raise AssertionError('AUTHOR_WORKSPACE_AVAILABLE_NEEDS_SEPARATE_UI_DIARY_DRIVER')
def before():
 home();v=inventory('before24')
 assert len(v['rows']['audio_assets'])>=3,'NOT_ENOUGH_UI_AUDIO'
 assert len(v['rows']['module_definitions'])>=1,'NO_UI_MODULE'
 shot('24-before-upgrade');return {'tracks':len(v['rows']['audio_assets']),'modules':len(v['rows']['module_definitions']),'integrity':v['database']['integrity']}
def compare(name):
 v=inventory(name);old=inventories.get('before24');assert old,'NO_BASELINE'
 missing={}
 for table in ['audio_assets','module_definitions','session_templates','diary_author']:
  absent=[r for r in old['rows'][table] if r not in v['rows'][table]]
  if absent:missing[table]=absent
 for p,b in old['files'].items():
  if p.startswith(('files/audio/','files/diary_media/')) and v['files'].get(p)!=b:missing[p]=b
 assert not missing,'PRESERVATION_FAILURE:'+json.dumps(missing)
 assert v['database']['integrity']=='ok','INTEGRITY_FAILED'
 return {'exactRowsAndMediaPreserved':True,'audio':len(v['rows']['audio_assets']),'modules':len(v['rows']['module_definitions']),'diary':len(v['rows']['diary_author'])}
def upgrade():
 assert 'Success' in adb('install','-r',str(APK/'master25.apk'));launch();shot('25-after-upgrade');return compare('after25')
def ui_after():
 home();click('Библиотека');ns=tree();shot('25-library')
 # Inspect both default and personal sections; preserve output of default filter.
 default=[label(n) for n in ns if label(n)]
 click('Мои',exact=True);ns=tree();titles=[r['title'] for r in inventories['before24']['rows']['audio_assets']]
 absent=[t for t in titles if not any(t in label(n) for n in ns)];assert not absent,'TRACKS_MISSING_FROM_UI:'+repr(absent)
 shot('25-personal-library');home();click('Шаблоны');click('Модули',exact=True);ns=tree();shot('25-modules')
 mt=[json.loads(r['payload'])['title'] for r in inventories['before24']['rows']['module_definitions']]
 assert all(any(t in label(n) for n in ns) for t in mt),'MODULES_MISSING_FROM_UI'
 return {'allUIAudioAndModulesVisible':True,'defaultLibraryLabels':default[:35]}
try:
 case('install_24',install)
 adb('shell','mkdir','-p','/sdcard/Download')
 for i in range(1,4):adb('push','test/fixtures/android_aac_isom.m4a','/sdcard/Download/task16v-'+str(i)+'.m4a')
 adb('shell','am','broadcast','-a','android.intent.action.MEDIA_SCANNER_SCAN_FILE','-d','file:///sdcard/Download/',check=False)
 for i in range(1,4):case('ui_import_'+str(i),lambda i=i:import_audio('task16v-'+str(i)+'.m4a','UI same title' if i<3 else 'UI third track'))
 case('ui_native_recording',record_audio)
 case('ui_module_elman',lambda:module('Elman variant 2',['UI same title','UI third track']))
 case('ui_module_pause',lambda:module('UI timed module',['UI third track'],True))
 case('ui_diary_auth_boundary',diary_boundary)
 case('before24_inventory',before)
 case('native_update24_to25',upgrade)
 case('ui_after25',ui_after)
 case('cold_restart25',lambda:(restart(),compare('cold25'))[-1])
except Exception as e:
 CASES.append({'case':'driver','status':'BLOCKED','reason':str(e)[:1500]});report()
finally:
 report()
 print('NATIVE16V_EVIDENCE='+base64.b64encode((OUT/'NATIVE_UI_UPGRADE_16V.json').read_bytes()).decode(),flush=True)
 for p in sorted(OUT.glob('*.png')):
  if p.name in ['25-library.png','25-modules.png'] or p.name.startswith('failure-'):
   print('NATIVE16V_SCREEN='+p.name+':'+base64.b64encode(p.read_bytes()).decode(),flush=True)
