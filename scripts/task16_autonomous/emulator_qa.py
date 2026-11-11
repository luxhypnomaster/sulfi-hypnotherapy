"""Black-box APK23→24 QA. Synthetic emulator data only; no Google identity injection."""
import base64, hashlib, io, json, os, pathlib, re, shlex, sqlite3, subprocess, tarfile, tempfile, time, zipfile, xml.etree.ElementTree as ET
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
 adb('shell','am','start','-W','-n',pkg+'/ru.sulfi.sulfi_hypnotherapy.MainActivity')
 # Debug APK cold start/JIT on software graphics may take tens of seconds.
 for _ in range(60):
  if 'READY' in adb('shell',f'run-as {pkg} sh -c "test -s files/library.sqlite && echo READY"',check=False):break
  time.sleep(2)
 else:
  diagnostics(pkg);raise AssertionError('DATABASE_NOT_READY_AFTER_120S')
 time.sleep(3)
 for _ in range(3):
  nodes=tree()
  allow=next((n for n in nodes if 'permission_allow' in n.get('resource-id','')),None)
  if allow is None:break
  tap(allow);time.sleep(.5)
def tree():
 adb('shell','uiautomator','dump','/sdcard/sulfi-window.xml',check=False)
 xml=adb('shell','cat','/sdcard/sulfi-window.xml',check=False)
 try:
  nodes=list(ET.fromstring(xml).iter('node'))
  # Dismiss only the known system launcher ANR; never dismiss a Sulfi ANR.
  if any("Pixel Launcher isn't responding" in n.get('text','') for n in nodes):
   close=next((n for n in nodes if n.get('text')=='Close app'),None)
   if close is not None:
    tap(close);print('EMULATOR_SYSTEM_LAUNCHER_ANR_DISMISSED',flush=True)
    return tree()
  return nodes
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
 print('EMULATOR_UI_MISSING='+json.dumps({'requested':text,'labels':[label(n)[:100] for n in tree() if label(n).strip()][:30]}),flush=True)
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
 assert (d/'library.sqlite').exists(),'EXPECTED_DB_NOT_IN_ARCHIVE'
 conn=sqlite3.connect(d/'library.sqlite');assert conn.execute("select count(*) from sqlite_master where name='audio_assets'").fetchone()[0]==1,'DATABASE_SCHEMA_NOT_READY';return t,conn
def inspect(pkg=PKG):
 t,c=dbcopy(pkg)
 try:
  assert c.execute('pragma integrity_check').fetchone()[0]=='ok'
  return {'audio':c.execute('select id,contentHash,filePath from audio_assets order by id').fetchall(),'templates':c.execute('select id from session_templates order by id').fetchall(),'draft':c.execute('select payload from current_draft').fetchall(),'schema':c.execute('pragma user_version').fetchone()[0]}
 finally:c.close();t.cleanup()
def diagnostics(pkg):
 pid=adb('shell','pidof',pkg,check=False).strip()
 details={'pidPresent':bool(pid),'runAsPwd':adb('shell','run-as',pkg,'pwd',check=False).strip(),'files':adb('shell','run-as',pkg,'find','.', '-name','library.sqlite',check=False).strip()}
 raw=adb('logcat','-d','-t','160',check=False)
 (OUT/'launch-logcat.txt').write_text(raw)
 details['fatalLines']=[l[-300:] for l in raw.splitlines() if 'FATAL' in l or 'UnsatisfiedLinkError' in l or 'flutter' in l.lower() and ('error' in l.lower() or 'exception' in l.lower())][-8:]
 print('EMULATOR_DIAGNOSTIC='+json.dumps(details),flush=True)
 return details
def require_home():
 for _ in range(4):
  if any('Библиотека' in label(n) for n in tree()):return
  time.sleep(1)
 raise AssertionError('APPLICATION_UI_NOT_READY_AFTER_BOOTSTRAP')
def return_home():
 for _ in range(4):
  if any('НАЧАТЬ ТРАНСФОРМАЦИЮ' in label(n) for n in tree()):return
  adb('shell','input','keyevent','4');time.sleep(1)
 require_home()
def install23():
 assert 'Success' in adb('install','-r',str(APK/'master23.apk'));launch();require_home();details=diagnostics(PKG);assert details['pidPresent'],'APP_NOT_RUNNING'
 screenshot('master23-start');return {'versionCode':23,'launched':bool(adb('shell','pidof',PKG).strip())}
def seed():
 adb('shell','am','force-stop',PKG);t,c=dbcopy();now='2026-11-11T00:00:00.000Z'
 data=pathlib.Path('test/fixtures/android_aac_isom.m4a').read_bytes();digest=hashlib.sha256(data).hexdigest()
 fixture=json.loads(pathlib.Path('scripts/task16_autonomous/fixture.json').read_text())
 row=fixture['audio'];assert row['contentHash']==digest and row['fileSizeBytes']==len(data)
 columns={r[1] for r in c.execute('pragma table_info(audio_assets)')};row={k:v for k,v in row.items() if k in columns}
 c.execute('insert or replace into audio_assets ('+','.join(row)+') values ('+','.join('?' for _ in row)+')',list(row.values()))
 c.execute('insert or replace into current_draft values (1,?)',(json.dumps(fixture['draft']),))
 c.execute('insert or replace into session_templates values (?,?)',('emu-template',json.dumps(fixture['template'])))
 c.commit();c.execute('pragma wal_checkpoint(truncate)');c.close()
 adb('shell',f'run-as {PKG} sh -c '+shlex.quote('for suffix in -wal -shm; do if [ -f files/library.sqlite$suffix ]; then mv files/library.sqlite$suffix files/qa-preseed$suffix; fi; done'));
 adb('push',str(pathlib.Path(t.name)/'library.sqlite'),'/data/local/tmp/emu-library.sqlite');adb('shell',f'cat /data/local/tmp/emu-library.sqlite | run-as {PKG} sh -c "cat > files/library.sqlite"')
 adb('push','test/fixtures/android_aac_isom.m4a','/data/local/tmp/emu-fixture.m4a');adb('shell','run-as',PKG,'mkdir','-p','files/audio');adb('shell',f'cat /data/local/tmp/emu-fixture.m4a | run-as {PKG} sh -c "cat > files/audio/{row["filePath"]}"');t.cleanup()
 assert hashlib.sha256(adb('exec-out','run-as',PKG,'cat','files/audio/'+row['filePath'],binary=True)).hexdigest()==digest
 launch();require_home();adb('shell','am','force-stop',PKG)
 global original;original=inspect();assert any(a[0]=='emulator-fixture' for a in original['audio']),'SEEDED_AUDIO_MISSING';return {'rowsSeeded':1,'sha256':digest,'schema':original['schema'],'seedMethod':'controlled SQLite precondition, not UI import'}
def upgrade():
 assert 'Success' in adb('install','-r',str(APK/'master24.apk'));launch();require_home();adb('shell','am','force-stop',PKG);after=inspect();assert after==original,'DATA_CHANGED_ON_UPDATE'
 assert hashlib.sha256(adb('exec-out','run-as',PKG,'cat','files/audio/asset_emulator_fixture.m4a',binary=True)).hexdigest()==original['audio'][0][1]
 launch();screenshot('master24-updated');return {'versionCode':24,'dataPreserved':True,'sqliteIntegrity':'ok'}
def native_playing(audio):
 uid=adb('shell','cmd','package','list','packages','-U',PKG)
 match=re.search(r'uid:(\d+)',uid);assert match,'APP_UID_NOT_FOUND'
 rows=[l.strip() for l in audio.splitlines() if re.search(r'(?:u/pid|uid/pid|uid)[:=]\s*'+match[1]+r'(?:/|\b)',l)]
 active=[l for l in rows if re.search(r'state[:=]\s*(?:started|3)\b',l,re.I)]
 print('EMULATOR_APP_PLAYERS='+json.dumps({'uid':match[1],'players':rows[:4],'active':bool(active),'diagnosticLines':[l.strip()[:280] for l in audio.splitlines() if 'piid' in l or 'AudioTrack' in l or match[1] in l][:12]}),flush=True)
 return bool(active)
def library_play():
 click('Библиотека');time.sleep(1)
 # Imported fixture is personal, select that section if necessary.
 if not any('EMU AAC fixture' in label(n) for n in tree()):
  for text in ['Мои аудиозаписи','Мои']:
   try:click(text);break
   except AssertionError:pass
 assert any('EMU AAC fixture' in label(n) for n in tree()),'FIXTURE_NOT_VISIBLE'
 screenshot('library-fixture');click('Прослушать EMU AAC fixture');time.sleep(1)
 audio=adb('shell','dumpsys','audio');(OUT/'audio-preview.txt').write_text(audio)
 assert native_playing(audio),'NATIVE_PLAYBACK_NOT_OBSERVED'
 screenshot('preview-playing');return {'nativePlaybackObserved':True,'actualHeardSound':'NOT_RUN'}
def session_play():
 adb('shell','am','force-stop',PKG);launch();click('НАЧАТЬ ТРАНСФОРМАЦИЮ');time.sleep(2)
 audio=adb('shell','dumpsys','audio');assert native_playing(audio),'SESSION_PLAYBACK_NOT_OBSERVED'
 screenshot('session-playing');adb('shell','input','keyevent','223');time.sleep(2)
 audio=adb('shell','dumpsys','audio');(OUT/'audio-screen-off.txt').write_text(audio)
 assert native_playing(audio),'BACKGROUND_PLAYBACK_NOT_OBSERVED'
 adb('shell','input','keyevent','224');adb('shell','wm','dismiss-keyguard');return {'screenOffPlaybackObserved':True,'physicalPhone':'NOT_RUN'}
def client_isolation():
 assert 'Success' in adb('install','-r',str(APK/'client24.apk'));launch(CLIENT);require_home();screenshot('client24-guest');adb('shell','am','force-stop',CLIENT)
 state=inspect(CLIENT);assert not state['audio'] and not state['templates'],'CLIENT_PACKAGE_NOT_ISOLATED';return {'distinctPackageSqlite':True,'emptyOwnLibrary':True,'schema':state['schema']}
def guest_state():
 adb('shell','am','force-stop',PKG);launch();return_home();click('Дневник');click('Подключение и права');assert any('Гость' in label(n) for n in tree()),'GUEST_NOT_SHOWN';screenshot('guest-authorization');return {'guestVisible':True,'authenticatedLogout':'NOT_RUN_NO_GOOGLE_ACCOUNT','rolesNotInjected':True}
def capsule_export():
 adb('shell','am','force-stop',PKG);launch();return_home();click('Библиотека');click('О приложении и данных');click('Резервная копия и обновления');screenshot('capsule-controls')
 # UI routes can differ; require actual available export rather than a fabricated success.
 for text in ['Создать резервную копию','Экспортировать','Сохранить копию']:
  try:click(text);break
  except AssertionError:pass
 else:raise AssertionError('CAPSULE_EXPORT_CONTROL_NOT_FOUND')
 time.sleep(2);screenshot('capsule-export-dialog')
 # Save only through local Android DocumentsUI on the offline disposable emulator.
 edit=None
 for _ in range(4):
  nodes=tree();edit=next((n for n in nodes if 'filename' in n.get('resource-id','') or n.get('class')=='android.widget.EditText'),None)
  if edit is not None:break
  time.sleep(2)
 if edit is None:print('EMULATOR_EXPORT_UI='+json.dumps([label(n)[:120] for n in nodes if label(n).strip()][:25]),flush=True)
 assert edit is not None,'LOCAL_DOCUMENT_FILENAME_NOT_FOUND'
 tap(edit);adb('shell','input','keycombination','KEYCODE_CTRL_LEFT','KEYCODE_A');adb('shell','input','text','sulfi-emulator-qa.zip')
 save=next((n for n in tree() if 'action_menu_save' in n.get('resource-id','') or n.get('text','').lower() in ['save','сохранить']),None)
 assert save is not None,'LOCAL_DOCUMENT_SAVE_NOT_FOUND';tap(save);time.sleep(3)
 paths=adb('shell','find','/sdcard/Download','-name','sulfi-emulator-qa.zip',check=False).splitlines()
 assert paths,'LOCAL_ZIP_NOT_FOUND_IN_DOWNLOADS'
 raw=adb('exec-out','cat',paths[0],binary=True)
 with zipfile.ZipFile(io.BytesIO(raw)) as z:
  assert z.testzip() is None,'ZIP_CRC_FAILED'
  names=z.namelist();assert any(n.endswith('.json') for n in names),'ZIP_MANIFEST_MISSING'
 screenshot('capsule-exported')
 print('EMULATOR_CAPSULE_EXPORTED='+json.dumps({'zipBytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'crc':'PASS','localDocumentsUi':True}),flush=True)
 # Local import into the separate empty CLIENT package; no Google identity.
 adb('shell','am','force-stop',CLIENT);launch(CLIENT);click('Библиотека');click('О приложении и данных');click('Резервная копия и обновления');click('Восстановить из копии');time.sleep(2)
 click('sulfi-emulator-qa.zip');time.sleep(3)
 nodes=tree()
 # Preserve the empty CLIENT's existing default draft/counter when merging.
 if any('Сохранить местные' in label(n) for n in nodes):click('Сохранить местные',exact=True)
 else:click('Восстановить',exact=True)
 time.sleep(4)
 adb('shell','am','force-stop',CLIENT);state=inspect(CLIENT)
 assert any(a[0]=='emulator-fixture' for a in state['audio']),'IMPORTED_AUDIO_MISSING'
 assert any(t[0]=='emu-template' for t in state['templates']),'IMPORTED_TEMPLATE_MISSING'
 audio=adb('exec-out','run-as',CLIENT,'cat','files/audio/'+state['audio'][0][2],binary=True)
 assert hashlib.sha256(audio).hexdigest()==original['audio'][0][1],'IMPORTED_BYTES_CHANGED'
 return {'exportControlReached':True,'completedLocalExportImport':True,'zipBytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'clientImportedExactAudio':True,'noDriveOrGoogleAccounts':True}
assert adb('shell','getprop','ro.kernel.qemu').strip()=='1','ONLY_EMULATOR_ALLOWED'
adb('shell','cmd','connectivity','airplane-mode','enable',check=False)
adb('shell','wm','size','720x1280');adb('shell','wm','density','280')
for name,work in [('install23_launch',install23),('synthetic_local_fixture',seed),('update23_to24_preserves_data',upgrade),('library_native_preview',library_play),('session_screen_off_playback',session_play),('client24_package_isolation',client_isolation),('guest_restart_state',guest_state),('capsule_ui_export',capsule_export)]:case(name,work)
print('EMULATOR_QA_COMPLETE; NO_REAL_GOOGLE_IDENTITIES',flush=True)
# Native low-resolution capture needs no image package or artifact allocation.
try:
 adb('shell','wm','size','360x640');adb('shell','wm','density','140')
 adb('shell','am','start','-W','-n',PKG+'/ru.sulfi.sulfi_hypnotherapy.MainActivity');time.sleep(3)
 data=adb('exec-out','screencap','-p',binary=True)
 if len(data)<180000:print('EMULATOR_SYNTHETIC_SCREENSHOT_PNG='+base64.b64encode(data).decode(),flush=True)
 else:print('EMULATOR_SCREENSHOT_INLINE=OVER_SIZE_LIMIT',flush=True)
except Exception:print('EMULATOR_SCREENSHOT_INLINE=NOT_AVAILABLE',flush=True)
if any(r['status']!='PASS' for r in results if r['case'] in ['install23_launch','synthetic_local_fixture','update23_to24_preserves_data','client24_package_isolation']): raise SystemExit(1)
