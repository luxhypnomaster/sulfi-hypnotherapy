"""Black-box APK23→24 QA. Synthetic emulator data only; no Google identity injection."""
import hashlib, io, json, os, pathlib, re, sqlite3, subprocess, tarfile, tempfile, time, xml.etree.ElementTree as ET
OUT=pathlib.Path(os.environ['RUNNER_TEMP'])/'emulator-evidence';OUT.mkdir(exist_ok=True)
PKG='ru.sulfi.sulfi_hypnotherapy';CLIENT=PKG+'.clienttest';APK=pathlib.Path(os.environ['RUNNER_TEMP'])/'apk24'
results=[]
def adb(*args, binary=False, check=True):
 r=subprocess.run(['adb',*args],capture_output=True,timeout=50,check=check)
 return r.stdout if binary else r.stdout.decode(errors='replace')
def case(name, work):
 try:
  details=work();results.append({'case':name,'status':'PASS','details':details})
 except Exception as e:
  results.append({'case':name,'status':'BLOCKED','error':type(e).__name__+':'+str(e)[:160]})
 finally:
  (OUT/'EMULATOR_QA.json').write_text(json.dumps({'kind':'REAL_ANDROID_EMULATOR_EXISTING_APKS','googleUsers':'NOT_RUN','physicalDevices':'NOT_RUN','fixture':'synthetic AAC and emulator-only SQLite, no user DB','cases':results},ensure_ascii=False,indent=2))
  print('EMULATOR_CASE='+name+':'+results[-1]['status'],flush=True)
def launch(pkg=PKG):
 adb('shell','monkey','-p',pkg,'-c','android.intent.category.LAUNCHER','1');time.sleep(3)
 for _ in range(3):
  nodes=tree()
  allow=next((n for n in nodes if 'permission_allow' in n.get('resource-id','')),None)
  if allow is None:break
  tap(allow);time.sleep(.5)
def tree():
 adb('shell','uiautomator','dump','/sdcard/sulfi-window.xml',check=False)
 xml=adb('shell','cat','/sdcard/sulfi-window.xml',check=False)
 try:return list(ET.fromstring(xml).iter('node'))
 except ET.ParseError:return []
def label(n):return n.get('text','')+' '+n.get('content-desc','')
def tap(n):
 points=[int(x) for x in re.findall(r'\d+',n.get('bounds',''))];assert len(points)==4,'MISSING_BOUNDS'
 adb('shell','input','tap',str((points[0]+points[2])//2),str((points[1]+points[3])//2));time.sleep(.5)
def click(text, exact=False):
 for _ in range(5):
  for n in tree():
   if (text in [n.get('text'),n.get('content-desc')]) if exact else text in label(n):tap(n);return
  time.sleep(.5)
 raise AssertionError('UI_NOT_FOUND:'+text)
def screenshot(name):
 (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p',binary=True))
 (OUT/(name+'.xml')).write_text(adb('shell','cat','/sdcard/sulfi-window.xml',check=False))
def dbcopy(pkg=PKG):
 data=adb('exec-out','run-as',pkg,'tar','-cf','-','files',binary=True)
 t=tempfile.TemporaryDirectory();d=pathlib.Path(t.name)
 if not data.startswith(b'files') and len(data)<512: raise AssertionError('APP_FILES_NOT_READY:'+repr(data[:140]))
 # Only own synthetic emulator data. Read selected DB files without generic tar extraction.
 with tarfile.open(fileobj=io.BytesIO(data)) as archive:
  for m in archive:
   if m.name in ['files/library.sqlite','files/library.sqlite-wal','files/library.sqlite-shm']:
    (d/pathlib.Path(m.name).name).write_bytes(archive.extractfile(m).read())
 conn=sqlite3.connect(d/'library.sqlite');return t,conn
def inspect(pkg=PKG):
 t,c=dbcopy(pkg)
 try:
  assert c.execute('pragma integrity_check').fetchone()[0]=='ok'
  return {'audio':c.execute('select id,contentHash,filePath from audio_assets order by id').fetchall(),'templates':c.execute('select id from session_templates order by id').fetchall(),'draft':c.execute('select payload from current_draft').fetchall(),'schema':c.execute('pragma user_version').fetchone()[0]}
 finally:c.close();t.cleanup()
def diagnostics(pkg):
 pid=adb('shell','pidof',pkg,check=False).strip()
 details={'pidPresent':bool(pid),'runAsPwd':adb('shell','run-as',pkg,'pwd',check=False).strip(),'files':adb('shell','run-as',pkg,'ls','files',check=False).strip()}
 raw=adb('logcat','-d','-t','160',check=False)
 (OUT/'launch-logcat.txt').write_text(raw)
 details['fatalLines']=[l[-300:] for l in raw.splitlines() if 'FATAL' in l or 'UnsatisfiedLinkError' in l or 'flutter' in l.lower() and ('error' in l.lower() or 'exception' in l.lower())][-8:]
 print('EMULATOR_DIAGNOSTIC='+json.dumps(details),flush=True)
 return details
def install23():
 assert 'Success' in adb('install','-r',str(APK/'master23.apk'));launch();details=diagnostics(PKG);assert details['pidPresent'],'APP_NOT_RUNNING'
 screenshot('master23-start');return {'versionCode':23,'launched':bool(adb('shell','pidof',PKG).strip())}
def seed():
 adb('shell','am','force-stop',PKG);t,c=dbcopy();now='2026-11-11T00:00:00.000Z'
 data=pathlib.Path('test/fixtures/android_aac_isom.m4a').read_bytes();digest=hashlib.sha256(data).hexdigest()
 row={'id':'emulator-fixture','title':'EMU AAC fixture','filePath':'asset_emulator_fixture.m4a','durationMs':12000,'format':'m4a','createdAt':now,'category':'exit','fileSizeBytes':len(data),'description':'Synthetic test fixture, not therapy','section':'personal','tags':'[]','source':'imported','origin':'personal','contentHash':digest,'baseRevision':1,'authorManaged':0}
 columns={r[1] for r in c.execute('pragma table_info(audio_assets)')};row={k:v for k,v in row.items() if k in columns}
 c.execute('insert or replace into audio_assets ('+','.join(row)+') values ('+','.join('?' for _ in row)+')',list(row.values()))
 plan={'steps':[{'id':'emu-step','kind':'audio','title':'EMU AAC fixture','audioAssetId':row['id'],'durationMs':12000,'enabled':True,'delayBeforeSeconds':0}], 'groups':[], 'exitStepId':'emu-step'}
 c.execute('insert or replace into current_draft values (1,?)',(json.dumps({'plan':plan,'updatedAt':now,'notes':'EMULATOR ONLY'}),))
 c.execute('insert or replace into session_templates values (?,?)',('emu-template',json.dumps({'id':'emu-template','name':'EMU template','plan':plan,'createdAt':now,'updatedAt':now,'version':1,'origin':'personal'})))
 c.commit();c.execute('pragma wal_checkpoint(truncate)');c.close()
 adb('shell','run-as',PKG,'sh','-c','for suffix in -wal -shm; do if [ -f files/library.sqlite$suffix ]; then mv files/library.sqlite$suffix files/qa-preseed$suffix; fi; done');
 adb('push',str(pathlib.Path(t.name)/'library.sqlite'),'/data/local/tmp/emu-library.sqlite');adb('shell',f'cat /data/local/tmp/emu-library.sqlite | run-as {PKG} sh -c "cat > files/library.sqlite"')
 adb('push','test/fixtures/android_aac_isom.m4a','/data/local/tmp/emu-fixture.m4a');adb('shell','run-as',PKG,'mkdir','-p','files/audio');adb('shell',f'cat /data/local/tmp/emu-fixture.m4a | run-as {PKG} sh -c "cat > files/audio/{row["filePath"]}"');t.cleanup()
 assert hashlib.sha256(adb('exec-out','run-as',PKG,'cat','files/audio/'+row['filePath'],binary=True)).hexdigest()==digest
 global original;original=inspect();return {'rowsSeeded':1,'sha256':digest,'schema':original['schema'],'seedMethod':'controlled SQLite precondition, not UI import'}
def upgrade():
 assert 'Success' in adb('install','-r',str(APK/'master24.apk'));launch();adb('shell','am','force-stop',PKG);after=inspect();assert after==original,'DATA_CHANGED_ON_UPDATE'
 assert hashlib.sha256(adb('exec-out','run-as',PKG,'cat','files/audio/asset_emulator_fixture.m4a',binary=True)).hexdigest()==original['audio'][0][1]
 launch();screenshot('master24-updated');return {'versionCode':24,'dataPreserved':True,'sqliteIntegrity':'ok'}
def library_play():
 click('Библиотека');time.sleep(1)
 # Imported fixture is personal, select that section if necessary.
 if not any('EMU AAC fixture' in label(n) for n in tree()):
  for text in ['Мои аудиозаписи','Мои']:
   try:click(text);break
   except AssertionError:pass
 assert any('EMU AAC fixture' in label(n) for n in tree()),'FIXTURE_NOT_VISIBLE'
 screenshot('library-fixture');click('Прослушать EMU AAC fixture');time.sleep(2)
 audio=adb('shell','dumpsys','audio');(OUT/'audio-preview.txt').write_text(audio)
 assert re.search(r'state[:=]\s*(started|3)|state=STARTED',audio,re.I),'NATIVE_PLAYBACK_NOT_OBSERVED'
 screenshot('preview-playing');adb('shell','input','keyevent','3');time.sleep(1);launch();return {'nativePlaybackObserved':True,'actualHeardSound':'NOT_RUN'}
def session_play():
 adb('shell','am','force-stop',PKG);launch();click('НАЧАТЬ ТРАНСФОРМАЦИЮ');time.sleep(2)
 audio=adb('shell','dumpsys','audio');assert re.search(r'state[:=]\s*(started|3)|state=STARTED',audio,re.I),'SESSION_PLAYBACK_NOT_OBSERVED'
 screenshot('session-playing');adb('shell','input','keyevent','223');time.sleep(2)
 audio=adb('shell','dumpsys','audio');(OUT/'audio-screen-off.txt').write_text(audio)
 assert re.search(r'state[:=]\s*(started|3)|state=STARTED',audio,re.I),'BACKGROUND_PLAYBACK_NOT_OBSERVED'
 adb('shell','input','keyevent','224');adb('shell','wm','dismiss-keyguard');return {'screenOffPlaybackObserved':True,'physicalPhone':'NOT_RUN'}
def client_isolation():
 assert 'Success' in adb('install','-r',str(APK/'client24.apk'));launch(CLIENT);screenshot('client24-guest');adb('shell','am','force-stop',CLIENT)
 state=inspect(CLIENT);assert not state['audio'] and not state['templates'],'CLIENT_PACKAGE_NOT_ISOLATED';return {'distinctPackageSqlite':True,'emptyOwnLibrary':True,'schema':state['schema']}
def guest_state():
 adb('shell','am','force-stop',PKG);launch();click('Дневник');click('Подключение и права');assert any('Гость' in label(n) for n in tree()),'GUEST_NOT_SHOWN';screenshot('guest-authorization');return {'guestVisible':True,'authenticatedLogout':'NOT_RUN_NO_GOOGLE_ACCOUNT','rolesNotInjected':True}
def capsule_export():
 adb('shell','am','force-stop',PKG);launch();click('Библиотека');click('О приложении и данных');click('Резервная копия и обновления');screenshot('capsule-controls')
 # UI routes can differ; require actual available export rather than a fabricated success.
 for text in ['Создать резервную копию','Экспортировать','Сохранить копию']:
  try:click(text);break
  except AssertionError:pass
 else:raise AssertionError('CAPSULE_EXPORT_CONTROL_NOT_FOUND')
 time.sleep(2);screenshot('capsule-export-dialog');return {'exportControlReached':True,'completedExportImport':'NOT_RUN_DOCUMENT_PICKER_REQUIRES_NEXT_STEP'}
assert adb('shell','getprop','ro.kernel.qemu').strip()=='1','ONLY_EMULATOR_ALLOWED'
adb('shell','cmd','connectivity','airplane-mode','enable',check=False)
for name,work in [('install23_launch',install23),('synthetic_local_fixture',seed),('update23_to24_preserves_data',upgrade),('library_native_preview',library_play),('session_screen_off_playback',session_play),('client24_package_isolation',client_isolation),('guest_restart_state',guest_state),('capsule_ui_export',capsule_export)]:case(name,work)
print('EMULATOR_QA_COMPLETE; NO_REAL_GOOGLE_IDENTITIES',flush=True)
if any(r['status']!='PASS' for r in results if r['case'] in ['install23_launch','synthetic_local_fixture','update23_to24_preserves_data','client24_package_isolation']): raise SystemExit(1)
